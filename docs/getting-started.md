# Getting started

## Mobile app (Flutter)

### Prerequisites
- Flutter SDK (with Dart)
- A device or emulator (Android/iOS), or Chrome/desktop for quick runs
- Firebase is pre-configured via [`firebase_options.dart`](../homies_mobile/lib/firebase_options.dart)

### Run

```bash
cd homies_mobile
flutter pub get
flutter run
```

Useful checks:

```bash
flutter analyze     # static analysis
flutter test        # unit/widget tests (if present)
```

### Explore instantly with demo accounts

You don't need to create an account to try the app:

1. Launch the app → **Welcome** screen.
2. Tap **"Just looking? Explore with a demo account"** (or go to `/demo`).
3. Pick any seeded housemate — leaseholder or tenant — to sign in with
   **no username or password**.

The demo loads a fully-populated household (see below).

### Seed / demo data

[`state/seed.dart`](../homies_mobile/lib/state/seed.dart) provides a demo
household:

- **1 property** — *12 Marrickville Road, Marrickville NSW 2204* (4-bed, fully
  set up).
- **2 leaseholders** — Maya Chen, Daniel Okafor.
- **3 tenants** — Priya Sharma, Tom Becker, and Aisha Rahman (still onboarding).
- **Group chat posts** — a handful of demo messages.

> **Note:** persisted state in `shared_preferences` overrides the seed. To force
> the seed back, clear app storage or call `HomiesState.reset()`.

### Real accounts

Sign up at `/signup` with email + password (Firebase Auth). New users choose a
role (leaseholder or tenant) and are taken through onboarding. Leaseholders can
invite housemates by email.

---

## Web app (React)

The companion web app lives in [`src/`](../src/):

```bash
npm install
npm run dev      # start the Vite dev server
```

It mirrors the same features and data model using a React context and mock data.

---

## Where to look next

- Feature tour → [features.md](features.md)
- How it's built → [architecture.md](architecture.md)
- Entities & fields → [data-model.md](data-model.md)
