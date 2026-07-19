const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');
const { onRequest } = require('firebase-functions/v2/https');

// No credential is passed here (unlike the old Render service, which needed
// FIREBASE_SERVICE_ACCOUNT) because Cloud Functions' runtime environment
// already provides Application Default Credentials scoped to this project.
admin.initializeApp();

const app = express();
app.use(cors());
app.use(express.json());

// The whole security boundary for every route below: verify the caller's
// Firebase ID token, then check *their own* users/{uid} doc says role ===
// 'admin'. Reading via the Admin SDK bypasses Firestore rules, which is
// fine — this is the trusted server context those rules assume doesn't
// exist on the client. Without this check, any signed-in user could delete
// any other user's login.
async function requireAdmin(req, res, next) {
  const authHeader = req.headers.authorization || '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'Missing bearer token' });
  try {
    const decoded = await admin.auth().verifyIdToken(token);
    const callerDoc = await admin.firestore().collection('users').doc(decoded.uid).get();
    if (callerDoc.data()?.role !== 'admin') {
      return res.status(403).json({ error: 'Not an admin' });
    }
    req.callerUid = decoded.uid;
    next();
  } catch (err) {
    res.status(401).json({ error: 'Invalid token' });
  }
}

// Verifies the caller's Firebase ID token (no admin requirement) and attaches
// the decoded token to the request. Used by member-level privileged routes.
async function requireAuth(req, res, next) {
  const authHeader = req.headers.authorization || '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'Missing bearer token' });
  try {
    req.caller = await admin.auth().verifyIdToken(token);
    next();
  } catch (err) {
    res.status(401).json({ error: 'Invalid token' });
  }
}

app.get('/', (_req, res) => res.json({ ok: true }));

// Redeems a house invite code and adds the caller to that house. Membership is
// added ONLY here (via the Admin SDK), never client-side — the Firestore rules
// forbid a user from adding themselves to houses/{id}.members, which is what
// stops any signed-in user from self-joining an arbitrary house. Validates that
// the code exists, is unused, and — when the invite specifies an email — that it
// matches the caller's verified email.
app.post('/invites/:code/redeem', requireAuth, async (req, res) => {
  const { code } = req.params;
  const uid = req.caller.uid;
  const db = admin.firestore();
  try {
    const inviteRef = db.collection('invites').doc(code);
    const inviteSnap = await inviteRef.get();
    if (!inviteSnap.exists) return res.status(404).json({ error: 'Invite not found' });
    const invite = inviteSnap.data();
    const houseId = invite.houseId;
    if (!houseId) return res.status(400).json({ error: 'Invite has no house' });
    if (invite.status === 'accepted') {
      return res.status(409).json({ error: 'This invite has already been used' });
    }
    // If the invite was addressed to a specific email, only that person may use
    // it — a leaked/guessed code can't be redeemed by someone else.
    if (invite.email && req.caller.email &&
        invite.email.toLowerCase() !== req.caller.email.toLowerCase()) {
      return res.status(403).json({ error: 'This invite was issued to a different email' });
    }
    const houseRef = db.collection('houses').doc(houseId);
    if (!(await houseRef.get()).exists) {
      return res.status(404).json({ error: 'House no longer exists' });
    }
    await houseRef.update({ members: admin.firestore.FieldValue.arrayUnion(uid) });
    await db.collection('users').doc(uid).set(
      { houseId, member: true, pending: false },
      { merge: true },
    );
    await inviteRef.update({ status: 'accepted', acceptedBy: uid });
    res.json({ ok: true, houseId });
  } catch (err) {
    res.status(500).json({ error: `Failed to redeem invite: ${err.message}` });
  }
});

// Fully deletes a user: their Firebase Auth login *and* their Firestore
// profile doc. The Flutter admin console's "Delete" button calls this
// instead of deleting the Firestore doc directly, since only the Admin SDK
// (server-side) can remove another user's Auth login.
app.delete('/users/:uid', requireAdmin, async (req, res) => {
  const { uid } = req.params;
  if (uid === req.callerUid) {
    return res.status(400).json({ error: "Can't delete yourself" });
  }
  try {
    await admin.auth().deleteUser(uid);
  } catch (err) {
    if (err.code !== 'auth/user-not-found') {
      return res.status(500).json({ error: `Failed to delete auth user: ${err.message}` });
    }
  }
  await admin.firestore().collection('users').doc(uid).delete();
  res.json({ ok: true });
});

exports.adminApi = onRequest(app);
