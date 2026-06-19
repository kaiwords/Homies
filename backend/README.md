# Backend

Homies has **no custom backend server**. The backend is **Firebase** (a managed Backend-as-a-Service). Both clients — [`frontend_web/`](../frontend_web) (React) and [`frontend_app/`](../frontend_app) (Flutter) — talk to Firebase directly via the official SDKs; there is no REST/GraphQL API of our own to host.

This folder centralizes the **backend-owned configuration**: project info, security rules, and indexes. The **database lives inside this backend** — see [`database/`](database) (Cloud Firestore). Binary file storage rules are in [`storage/`](storage) (Firebase Storage).

## Firebase project

| Item | Value |
|------|-------|
| Project ID | `homies-980c7` |
| Auth domain | `homies-980c7.firebaseapp.com` |
| Storage bucket | `homies-980c7.firebasestorage.app` |
| Messaging sender ID | `579052656220` |

## Services used

| Service | Purpose | Where it's used |
|---------|---------|-----------------|
| **Firebase Authentication** | Email/password sign-up & login | web + mobile |
| **Cloud Firestore** | User profiles & cloud-synced docs (`users/{uid}`) | web + mobile → see [`database/`](database) |
| **Firebase Storage** | Receipts, ID docs, proofs, photos | mobile → see [`storage/`](storage) |

## Where client config lives (not here)

Client-side Firebase **initialization** stays with each client, because it ships in the client bundle:

- Web: [`frontend_web/src/lib/firebase.js`](../frontend_web/src/lib/firebase.js)
- Mobile: [`frontend_app/lib/firebase_options.dart`](../frontend_app/lib/firebase_options.dart) and `frontend_app/firebase.json` (FlutterFire generator config)

This `backend/` folder instead holds the **server-side / project-level** config that you deploy with the Firebase CLI (security rules and indexes).

## Deploying

The [`firebase.json`](firebase.json) here wires up the rules in `database/` and `storage/`. With the [Firebase CLI](https://firebase.google.com/docs/cli) installed and authenticated:

```bash
cd backend
firebase use homies-980c7
firebase deploy --only firestore:rules,firestore:indexes,storage
```

> ⚠️ The `.rules` files in this folder are **starter templates** reflecting the app's `users/{uid}` access pattern. Review and harden them against your actual collections before deploying to production.
