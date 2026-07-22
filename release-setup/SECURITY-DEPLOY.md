# Security re-architecture — deploy runbook

The security hardening (Phases 1–3) is **coupled**: the new Firestore/Storage
rules and the new app build must go out **together**. Deploying one without the
other breaks things:

- **New rules + old app** → the old app reads/writes the single `community/global`
  doc and self-joins houses client-side; the new rules forbid both → marketplace
  and house-join break for anyone on the old build.
- **New app + old rules** → harmless but insecure (the permissive rules stay).

There is no clean zero-downtime ordering without a dual-write migration, so pick a
short window. This is fine pre-launch (TestFlight only). **Existing TestFlight
testers must update to the new build** once rules are live.

Project: `leasely-a11e4` · bundle id `com.leasely.mobile` · run all `firebase`
commands from `backend/` (it holds `firebase.json`).

---

## 0. Pre-flight (verify, no changes)

```bash
# Rules unit tests (Firestore emulator) — expect 12 passing.
cd backend/test && npm install && \
  firebase emulators:exec --only firestore --project demo-leasely "npm test"

# App: analyze clean + tests green.
cd frontend_app && flutter analyze && flutter test
```

Confirm you are logged in and targeting the right project:

```bash
firebase login
firebase use leasely-a11e4   # from backend/
```

## 1. Promote the proposed rules to the live files

The secure rules live in `*.proposed` files so they don't deploy by accident.
Copy them over the active files:

```bash
cd backend
cp database/firestore.rules.proposed database/firestore.rules
cp storage/storage.rules.proposed   storage/storage.rules
```

Review the diff once more:

```bash
git diff database/firestore.rules storage/storage.rules
```

## 2. Deploy rules + the Cloud Function

```bash
cd backend

# Firestore rules
firebase deploy --only firestore:rules --project leasely-a11e4

# Storage rules. If it errors about a missing deploy target, first run:
#   firebase target:apply storage rules leasely-a11e4.firebasestorage.app
# then re-run the deploy.
firebase deploy --only storage --project leasely-a11e4

# Cloud Functions (adminApi — now includes the redeemInvite route)
firebase deploy --only functions --project leasely-a11e4
```

## 3. Release the app build

Trigger the Codemagic `ios-release` workflow on `main` (the client changes are
already committed). Ship it to TestFlight and have testers update.

## 4. Device run-through (do NOT skip — not covered by unit tests)

Sign in on a real device / simulator against the live project and exercise the
rewritten paths:

- [ ] **Sign in** works (web + mobile).
- [ ] **Marketplace** loads listings (per-collection read).
- [ ] **Post a listing** → it appears for another account; a different account
      **cannot** edit/delete it.
- [ ] **Send a DM** in a listing thread → only the two participants see it; a
      third account cannot.
- [ ] **Apply to a listing** → only the applicant and the listing owner see the
      application.
- [ ] **Attach a photo** in chat → it uploads and displays (check Storage console
      shows an object under `media/{uid}/…`, and the Firestore doc holds a URL,
      not base64).
- [ ] **Join a house by invite code** → succeeds via the `redeemInvite` function;
      confirm a stranger cannot add themselves to a house.
- [ ] **Notifications** show only for their recipient.

## Rollback

If something breaks, redeploy the previous rules from git history and roll the app
build back in Codemagic:

```bash
cd backend
git checkout HEAD~1 -- database/firestore.rules storage/storage.rules
firebase deploy --only firestore:rules,storage --project leasely-a11e4
```

(The old permissive rules restore old-app behavior. Functions are additive — the
new `redeemInvite` route is harmless to leave deployed.)

## Notes

- The `community/global` document is now unused; you can delete it from Firestore
  after the new build is fully rolled out.
- Storage rules scope writes to `media/{uid}/…`; download URLs carry access tokens
  so shared media still displays for all signed-in users.
