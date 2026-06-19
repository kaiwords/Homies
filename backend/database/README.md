# Database (Cloud Firestore)

The database is **Cloud Firestore**, a managed NoSQL document database that is part of the Firebase backend. It is not a self-hosted/SQL database — there is nothing to install or run locally.

## What's stored in the cloud

Firestore is the **cloud source of truth for user profiles and auth state**:

- Collection: `users/{uid}` — one document per authenticated user, with server-side timestamps.

The rest of the app's data (bills, chores, listings, messages, etc.) is currently **local-first**: it is held in each client's in-memory store and persisted on-device — see the full data model in [`../../project-docs/03-data-model.md`](../../project-docs/03-data-model.md). Those collections can be promoted to Firestore over time.

## Files

| File | Purpose |
|------|---------|
| `firestore.rules` | Security rules (who can read/write what). **Starter template — harden before production.** |
| `firestore.indexes.json` | Composite index definitions (none required yet). |

## Local persistence (per client, not in this DB)

- Web: `localStorage` key `homies-state-v3`
- Mobile: `shared_preferences` key `homies-mobile-v2`
