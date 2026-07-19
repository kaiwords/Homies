// Firestore security-rules unit tests for the PROPOSED per-record model.
// Run via:  firebase emulators:exec --only firestore --project demo-leasely "npm test"
// (the emulator must be running; this connects to it and loads the proposed rules).
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import test, { before, after } from 'node:test';
import assert from 'node:assert/strict';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteDoc } from 'firebase/firestore';

const __dirname = dirname(fileURLToPath(import.meta.url));
const rules = readFileSync(join(__dirname, '..', 'database', 'firestore.rules.proposed'), 'utf8');

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-leasely',
    firestore: { rules, host: '127.0.0.1', port: 8080 },
  });
});

after(async () => {
  if (env) await env.cleanup();
});

// Seed a doc bypassing rules.
async function seed(path, id, data) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path, id), data);
  });
}

function db(uid) {
  return env.authenticatedContext(uid).firestore();
}

test.beforeEach(async () => {
  await env.clearFirestore();
  // Baseline users so isAdmin() get()s resolve.
  await seed('users', 'alice', { name: 'Alice', role: 'tenant' });
  await seed('users', 'bob', { name: 'Bob', role: 'leaseholder' });
  await seed('users', 'carol', { name: 'Carol', role: 'tenant' });
});

test('listingInterests: a third party cannot read an application, but applicant and owner can', async () => {
  await seed('listingInterests', 'i1', { from: 'alice', to: 'bob', lifestyle: { x: 1 } });
  await assertFails(getDoc(doc(db('carol'), 'listingInterests', 'i1')));
  await assertSucceeds(getDoc(doc(db('alice'), 'listingInterests', 'i1')));
  await assertSucceeds(getDoc(doc(db('bob'), 'listingInterests', 'i1')));
});

test('listingInterests: applicant must set from == their uid on create', async () => {
  await assertFails(setDoc(doc(db('carol'), 'listingInterests', 'i2'), { from: 'alice', to: 'bob' }));
  await assertSucceeds(setDoc(doc(db('alice'), 'listingInterests', 'i3'), { from: 'alice', to: 'bob' }));
});

test('postMessages: a non-participant cannot read a DM thread; participants can', async () => {
  await seed('postMessages', 'm1', { from: 'alice', to: 'bob', text: 'private' });
  await assertFails(getDoc(doc(db('carol'), 'postMessages', 'm1')));
  await assertSucceeds(getDoc(doc(db('alice'), 'postMessages', 'm1')));
  await assertSucceeds(getDoc(doc(db('bob'), 'postMessages', 'm1')));
});

test('listings: any signed-in user reads, but only the owner can modify', async () => {
  await seed('listings', 'l1', { by: 'alice', title: 'Room' });
  await assertSucceeds(getDoc(doc(db('carol'), 'listings', 'l1')));       // public read
  await assertFails(updateDoc(doc(db('carol'), 'listings', 'l1'), { title: 'Hacked' }));
  await assertSucceeds(updateDoc(doc(db('alice'), 'listings', 'l1'), { title: 'Updated' }));
  await assertFails(deleteDoc(doc(db('carol'), 'listings', 'l1')));
});

test('goodsListings / essentials / listingReviews: only owner writes', async () => {
  await seed('goodsListings', 'g1', { postedBy: 'alice' });
  await assertFails(updateDoc(doc(db('carol'), 'goodsListings', 'g1'), { title: 'x' }));
  await assertSucceeds(updateDoc(doc(db('alice'), 'goodsListings', 'g1'), { title: 'x' }));

  await seed('essentials', 'e1', { postedBy: 'bob' });
  await assertFails(updateDoc(doc(db('carol'), 'essentials', 'e1'), { hours: 'x' }));
  await assertSucceeds(updateDoc(doc(db('bob'), 'essentials', 'e1'), { hours: 'x' }));

  await seed('listingReviews', 'r1', { fromUserId: 'alice', rating: 5 });
  await assertFails(updateDoc(doc(db('carol'), 'listingReviews', 'r1'), { rating: 1 }));
  await assertSucceeds(updateDoc(doc(db('alice'), 'listingReviews', 'r1'), { rating: 4 }));
});

test('essentialBookings: only the client and the business owner can see a booking', async () => {
  await seed('essentialBookings', 'b1', { requestedBy: 'alice', businessOwnerId: 'bob' });
  await assertFails(getDoc(doc(db('carol'), 'essentialBookings', 'b1')));
  await assertSucceeds(getDoc(doc(db('alice'), 'essentialBookings', 'b1')));
  await assertSucceeds(getDoc(doc(db('bob'), 'essentialBookings', 'b1')));
});

test('appNotifications: only the recipient can read their notification', async () => {
  await seed('appNotifications', 'n1', { forUserId: 'bob', title: 'Rent due' });
  await assertFails(getDoc(doc(db('carol'), 'appNotifications', 'n1')));
  await assertSucceeds(getDoc(doc(db('bob'), 'appNotifications', 'n1')));
});

test('users: a user cannot self-elevate role or self-verify, but can edit profile fields', async () => {
  await assertFails(updateDoc(doc(db('alice'), 'users', 'alice'), { role: 'admin' }));
  await assertFails(updateDoc(doc(db('alice'), 'users', 'alice'), { leaseVerification: { status: 'verified' } }));
  await assertFails(updateDoc(doc(db('alice'), 'users', 'alice'), { member: true }));
  await assertSucceeds(updateDoc(doc(db('alice'), 'users', 'alice'), { name: 'Alice B.' }));
});

test('users: nobody can read another user profile (non-admin)', async () => {
  await assertFails(getDoc(doc(db('carol'), 'users', 'alice')));
  await assertSucceeds(getDoc(doc(db('alice'), 'users', 'alice')));
});

test('houses: a stranger cannot self-join without an invite, but can with one', async () => {
  await seed('houses', 'h1', { members: ['bob'], address: '1 St' });
  // Carol is not a member and has no invite → cannot read or self-add.
  await assertFails(getDoc(doc(db('carol'), 'houses', 'h1')));
  await assertFails(updateDoc(doc(db('carol'), 'houses', 'h1'), { members: ['bob', 'carol'] }));

  // A member issues a per-invitee token, then Carol may add only herself.
  await seed('houseInvites', 'h1_carol', { houseId: 'h1', invitee: 'carol' });
  await assertSucceeds(updateDoc(doc(db('carol'), 'houses', 'h1'), { members: ['bob', 'carol'] }));
});

test('houses: cannot add anyone other than yourself even with an invite', async () => {
  await seed('houses', 'h2', { members: ['bob'] });
  await seed('houseInvites', 'h2_carol', { houseId: 'h2', invitee: 'carol' });
  // Carol tries to add mallory too — must fail (only self allowed).
  await assertFails(updateDoc(doc(db('carol'), 'houses', 'h2'), { members: ['bob', 'carol', 'mallory'] }));
});
