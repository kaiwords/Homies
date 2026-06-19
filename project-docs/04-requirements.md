# Requirements

What you need to build, run, and deploy each part of Homies.

---

## Common

- **A Firebase project** with the following enabled:
  - **Authentication** → Email/Password sign-in provider.
  - **Cloud Firestore** (for user profiles under `users/{uid}`).
  - **Firebase Storage** (for receipts, ID docs, proofs, photos).
- Region/format assumptions: **AUD** currency and **`en_AU`** locale.
- **Git** for version control.

---

## Mobile app (`frontend_app/`) — primary product

**Tooling**
- **Flutter SDK** `^3.10.7` (includes Dart).
- Platform toolchains as needed: Android SDK / Android Studio for Android, Xcode for iOS (macOS only).
- **FlutterFire CLI** + Firebase CLI to (re)generate `lib/firebase_options.dart`.

**Key dependencies** (from `pubspec.yaml`)
- `firebase_core` 4.9.0, `firebase_auth` 6.5.1, `cloud_firestore` 6.4.1, `firebase_storage` 13.4.1
- `go_router` 14.6.2, `shared_preferences` 2.3.3, `intl` 0.20.1, `file_picker` 8.1.6, `uuid` 4.5.1, `cupertino_icons` 1.0.8
- Dev: `flutter_lints` 6.0.0, `flutter_test`

**Setup & run**
```bash
cd frontend_app
flutter pub get
# configure Firebase if not already present:
# flutterfire configure
flutter run                 # run on a connected device/emulator
flutter build apk           # or: flutter build ios / appbundle
```

**Config files**
- `frontend_app/pubspec.yaml` — dependencies.
- `frontend_app/lib/firebase_options.dart` — generated Firebase config (do not hand-edit).

---

## Web app (`frontend_web/`) — React + Vite

**Tooling**
- **Node.js** (LTS recommended) + **npm**.

**Key dependencies** (from `package.json`)
- `react` 19.2.6, `react-dom`, `react-router-dom` 7.15.0
- Build/dev: `vite` 8.0.12, `@vitejs/plugin-react` 6.0.1
- Lint: `eslint` 10.3.0, `@eslint/js`, `eslint-plugin-react-hooks`, `eslint-plugin-react-refresh`
- Types (dev): `@types/react` 19.2.14, `@types/react-dom` 19.2.3
- Firebase web SDK: `firebase` 12.13.0

**Setup & run**
```bash
cd frontend_web
npm install
npm run dev          # start Vite dev server
npm run build        # production build
npm run preview      # preview the production build
npm run lint         # run ESLint
```

**Config files**
- `package.json` / `package-lock.json` — dependencies & scripts.
- `vite.config.js` — build config.
- `eslint.config.js` — lint rules.
- `index.html` — entry point.
- Firebase web config — provide via the project's Firebase initialization (env/config).

---

## What is NOT required

- **No backend server** to provision or run (no Node/Express/Django/etc.).
- **No self-managed SQL database** — Firestore is fully managed.
- **No custom REST/GraphQL API** — clients use the Firebase SDKs directly.

---

## Functional requirements (product)

- Users can sign up as **leaseholder** or **tenant**, or join via an **invite code**.
- A leaseholder can set up a **property**, define **house rules**, **invite** tenants, and **approve/decline** them.
- Tenants must complete a **profile** (lifestyle + emergency contact) and **onboarding** (ID, bond proof, advance-rent proof, accept rules) before becoming active.
- Housemates can split and settle **bills**, **subscriptions**, **groceries**, and **necessities** (equal/percentage/custom/prorated).
- A **cleaning roster** and **tasks** with photo proof/excuses.
- **Messaging** (group + DM) with **polls**, **parties** with RSVPs, **issues** with photos, and **complaints** with severity scoring.
- **Marketplace listings** (rooms available / room wanted) with applications, **inspections**, and per-listing threads.
- **Tenant departure**: 2-week notice, bond deductions, and final settlement.
- Leaseholder-only **tenant performance** scoring with shareable reference snapshots.
- App state must persist **locally/offline** and sync the user profile to the cloud.
