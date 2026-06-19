# Homies — Project Documentation

This folder is the single source of truth for **what Homies does**, **what it needs to run**, and **which technology powers each part**.

Homies is a shared-living / co-tenancy management platform. It helps leaseholders set up a property, invite and approve tenants, and lets housemates split bills, run a cleaning roster, log expenses, raise issues, plan events, and track tenant performance — plus a marketplace for finding rooms and tenants.

## Contents

| Document | What's inside |
|----------|---------------|
| [01-tech-stack.md](01-tech-stack.md) | Every technology used and **what it's used for** |
| [02-features.md](02-features.md) | Complete feature list, grouped by area |
| [03-data-model.md](03-data-model.md) | All data entities and their fields |
| [04-requirements.md](04-requirements.md) | What you need to build, run, and deploy the apps |
| [05-navigation.md](05-navigation.md) | All routes / screens and the navigation structure |

## At a glance

- **Two clients:** a **Flutter** mobile app (the main product) and a **React + Vite** web app.
- **Backend:** no custom server — **Firebase** (Auth + Cloud Firestore + Storage) is the entire backend.
- **State:** local-first. Mobile uses `ChangeNotifier`/`InheritedNotifier` + `shared_preferences`; web uses React Context + `localStorage`.
- **Region defaults:** AUD currency, `en_AU` locale.
