# Homies 🏡

**Run a sharehouse without the drama.** Homies is a household-management app for
rental sharehouses — it keeps bills, bond, chores, parties, complaints, and the
move-in/move-out paperwork in one shared place, with fair splits and a record
everyone can trust.

The project ships in two forms that mirror the same data model and features:

| App | Stack | Location |
|-----|-------|----------|
| **Mobile** | Flutter (Dart) + Firebase Auth/Firestore | [`homies_mobile/`](../homies_mobile/) |
| **Web** | React + Vite | [`src/`](../src/) |

## Documentation index

- **[features.md](features.md)** — every feature, screen by screen.
- **[architecture.md](architecture.md)** — how the app is structured (state, routing, persistence).
- **[data-model.md](data-model.md)** — the entities and their fields.
- **[getting-started.md](getting-started.md)** — run it locally, demo accounts, seed data.

## The one-paragraph pitch

A sharehouse has two kinds of people: **leaseholders** (named on the lease, with
extra controls) and **tenants** (housemates). Homies gives both a single space to
split utilities fairly (prorated by move-in date), run a chore roster with photo
proof, track bond and advance rent, plan parties, raise maintenance issues and
complaints, advertise empty rooms on a marketplace, and handle leaving cleanly
with notice periods and explained bond deductions.

## Roles at a glance

- **Leaseholder** — full access, plus leaseholder-only tools: *Tenant
  performance* dashboard and *End of lease* (termination) planning.
- **Tenant** — everything except the leaseholder-only tools.

See [features.md](features.md) for the full per-screen breakdown.
