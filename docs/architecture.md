# Architecture (Flutter mobile app)

## Overview

The mobile app is a single-package Flutter app that holds **all household state
in one in-memory store**, persists it to the device, and uses Firebase only for
user authentication and profile sync.

```
main.dart
  └─ HomiesScope (InheritedNotifier)        ← exposes shared state to the tree
       └─ HomiesState (ChangeNotifier)      ← the single source of truth
            ├─ load()      reads persisted JSON from shared_preferences
            ├─ mutate(fn)  applies a change, notifies, re-persists
            └─ Firebase Auth listener        ← hydrates/clears the session
  └─ GoRouter (router.dart)                 ← all routes
       └─ AppShell                          ← app bar + drawer + bottom nav
            └─ screens/*.dart               ← one widget per feature
```

## State management

- **[`HomiesState`](../homies_mobile/lib/state/app_state.dart)** is a
  `ChangeNotifier` holding every collection (users, property, bills, schedules,
  subscriptions, groceries, necessities, cleaning roster/tasks, parties,
  messages, complaints, issues, notices, termination, listings, interests) plus
  the current `session`.
- **[`HomiesScope`](../homies_mobile/lib/state/app_state.dart)** is an
  `InheritedNotifier` — screens read state with `HomiesScope.of(context)` and
  rebuild on change.
- **All writes go through `mutate(() { ... })`**, which runs the change, calls
  `notifyListeners()`, and re-persists. This keeps UI, persistence, and
  notification in lockstep.

## Persistence

State is serialized to JSON and stored in `shared_preferences` under the key
`homies-mobile-v2`. On startup `load()` rehydrates it; if nothing is stored, the
app falls back to **seed data**. Every model has `toJson` / `fromJson`.

> Because persisted state wins over the seed, demo/seed data only appears on a
> fresh install or after `reset()`.

## Authentication

- **Firebase Auth** (email/password) for real accounts. On sign-up a profile doc
  is written to Firestore (`users/{uid}`); on sign-in the profile is hydrated
  back into local state.
- An **auth-state listener** keeps the session in sync — it clears the session
  when Firebase reports no signed-in user.
- **Demo accounts** bypass Firebase entirely: `signInAs(user)` ensures the
  seeded user exists locally and sets the session directly (no credentials).

## Routing

[`buildRouter()`](../homies_mobile/lib/router.dart) defines a `GoRouter`. Public
routes (`/`, `/login`, `/signup`, `/demo`, `/invite/:code`, onboarding) sit at the
top level; the authenticated app lives under a `ShellRoute` at `/app/...` wrapped
by `AppShell`. `AppShell` redirects to `/login` when there's no current user.

## Design system

- **[`theme.dart`](../homies_mobile/lib/theme.dart)** — `HomiesColors` tokens
  (warm off-white background, coral accent) and a Material 3 `ThemeData`.
- **[`widgets/ui_kit.dart`](../homies_mobile/lib/widgets/ui_kit.dart)** —
  reusable primitives: `HomiesCard`, `HomiesChip`, `Segment`, `PageHead`,
  `StatTile`/`StatRow`, `EmptyState`, `InfoBanner`, `AttachmentTile`, date
  pickers.
- **[`widgets/avatar.dart`](../homies_mobile/lib/widgets/avatar.dart)** —
  initial-based avatars with a deterministic color per user.

## Folder map

```
homies_mobile/lib/
├─ main.dart                 app entry, Firebase init, scope + router
├─ router.dart               all routes
├─ theme.dart                colors + ThemeData
├─ firebase_options.dart     generated Firebase config
├─ state/
│   ├─ models.dart           all entity classes (+ JSON)
│   ├─ app_state.dart        HomiesState / HomiesScope
│   └─ seed.dart             demo/seed data
├─ screens/                  one file per feature screen
├─ widgets/                  AppShell, ui_kit, avatar, inputs
└─ util/                     formatting helpers
```

## Web counterpart

The React app in [`src/`](../src/) mirrors the same model and feature set, using
a React context ([`src/context/HomiesContext.jsx`](../src/context/HomiesContext.jsx))
and mock data ([`src/data/mockData.js`](../src/data/mockData.js)) in place of the
Dart state store.
