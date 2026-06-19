# Navigation & Routes

Routes come from `frontend_app/lib/router.dart` (mobile, via `go_router`). The React web app (`frontend_web/src/`, React Router DOM) mirrors the same structure.

## Auth & onboarding (outside the app shell)

| Route | Screen | Purpose |
|-------|--------|---------|
| `/` | Welcome | Landing intro, sign up / login |
| `/login` | Login | Email/password sign-in |
| `/demo` | Demo login | Quick access with seed data |
| `/signup` | Signup | Create account; choose role |
| `/invite/:code` | Accept invite | Join a house via invite code (pre-fills email/role) |
| `/onboarding/leaseholder` | Leaseholder onboarding | Property setup + invite tenants |
| `/onboarding/tenant` | Tenant onboarding | ID/bond/advance proof, rules, lifestyle, emergency |

## Main app (inside `AppShell` with bottom navigation)

| Route | Screen | Purpose |
|-------|--------|---------|
| `/app` | Dashboard | At-a-glance metrics & alerts |
| `/app/profile` | Profile | Lifestyle answers + emergency contact |
| `/app/property` | Property | Lease & property details |
| `/app/housemates` | Housemates | Members, approvals, invites |
| `/app/performance` | Tenant performance | Standing scores (leaseholder) |
| `/app/listings` | Listings | Rooms-available / room-wanted marketplace |
| `/app/bills` | Bills | One-off bills + schedules |
| `/app/subscriptions` | Subscriptions | Recurring services |
| `/app/groceries` | Groceries | Grocery shop logging |
| `/app/necessities` | Necessities | Shared consumables |
| `/app/cleaning` | Cleaning | Roster + tasks |
| `/app/rules` | House rules | View/manage rules |
| `/app/parties` | Parties | Plan events + RSVPs |
| `/app/messages` | Messages | Group + direct messages, polls |
| `/app/issues` | Issues | Maintenance issues |
| `/app/complaints` | Complaints | Complaint tracking & scores |
| `/app/leaving` | Leaving | Tenant departure notice |
| `/app/termination` | Termination | Bond return & final settlement |

> Listing conversations open a **post thread** screen (`post_thread.dart`) per listing/participant, used for messaging and performance-reference requests.

## Structure

```
Welcome / Login / Demo / Signup / Invite
        │
        ├── Onboarding (leaseholder | tenant)
        │
        └── AppShell (bottom nav)
             ├── Dashboard
             ├── Money: Bills · Subscriptions · Groceries · Necessities
             ├── Living: Cleaning · Rules · Parties · Issues · Complaints
             ├── People: Housemates · Profile · Messages · Performance
             ├── Property
             ├── Marketplace: Listings → Post threads · Inspections
             └── Departure: Leaving → Termination
```
