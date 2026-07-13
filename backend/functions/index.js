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

app.get('/', (_req, res) => res.json({ ok: true }));

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
