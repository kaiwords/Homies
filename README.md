# Homies

Shared-living / co-tenancy management platform. Leaseholders set up a property and invite tenants; housemates then split bills, run a cleaning roster, log expenses, message, plan events, raise issues, and track tenant performance — plus a marketplace for finding rooms and tenants.

## Repository layout

| Folder | What it is | Stack |
|--------|-----------|-------|
| [`frontend_web/`](frontend_web) | Web client | React 19 + Vite + React Router |
| [`frontend_app/`](frontend_app) | Mobile app (primary product) | Flutter / Dart + go_router |
| [`backend/`](backend) | Firebase backend config (managed BaaS) | Firebase Auth + Cloud Firestore + Storage |
| [`backend/database/`](backend/database) | Cloud Firestore rules & indexes | Firestore (NoSQL) |
| [`backend/storage/`](backend/storage) | Firebase Storage rules | Firebase Storage |
| [`project-docs/`](project-docs) | Full project documentation | — |
| [`docs/`](docs) | Earlier generated docs + `.docx` | — |

There is **no custom backend server**: both clients talk to Firebase directly. See [`backend/README.md`](backend/README.md).

## Quick start

**Web** ([`frontend_web/`](frontend_web)):
```bash
cd frontend_web
npm install
npm run dev
```

**Mobile** ([`frontend_app/`](frontend_app)):
```bash
cd frontend_app
flutter pub get
flutter run
```

**Backend** ([`backend/`](backend)) — deploy Firestore/Storage rules with the Firebase CLI:
```bash
cd backend
firebase use homies-980c7
firebase deploy --only firestore:rules,firestore:indexes,storage
```

## Documentation

Start with [`project-docs/README.md`](project-docs/README.md) — tech stack, features, data model, requirements, and navigation.
