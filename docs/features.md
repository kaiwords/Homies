# Features

A screen-by-screen tour. Routes refer to the Flutter mobile app
([`homies_mobile/lib/router.dart`](../homies_mobile/lib/router.dart)); the React
web app mirrors the same set.

## Navigation

The signed-in app ([`AppShell`](../homies_mobile/lib/widgets/app_shell.dart))
wraps every screen with:

- **App bar** — property address, bedroom count + number living there, and a
  profile menu (with sign-out).
- **Bottom nav** — quick access to Home, Bills, Cleaning, Chat.
- **Drawer** — the full section list, grouped into **Primary**, **Money**,
  **Living together**, and **Wrap up**. Leaseholder-only items are hidden from
  tenants. Live badges show open complaints and outstanding chores.

---

## Onboarding & accounts

### Welcome / landing — `/`
Marketing landing page: gradient hero, feature grid, **Marketplace** highlight,
and entry points to create an account, sign in, or **explore a demo account**.
([`welcome.dart`](../homies_mobile/lib/screens/welcome.dart))

### Demo accounts — `/demo`
One-tap, **credential-free** sign-in as any pre-seeded housemate (leaseholders
and tenants), for instantly exploring the app. No username or password needed.
([`demo_login.dart`](../homies_mobile/lib/screens/demo_login.dart))

### Sign up / Sign in — `/signup`, `/login`
Email + password auth via Firebase. New users pick a role (leaseholder or
tenant). ([`signup.dart`](../homies_mobile/lib/screens/signup.dart),
[`login.dart`](../homies_mobile/lib/screens/login.dart))

### Invites — `/invite/:code`, accept-invite flow
Leaseholders invite housemates by email; invitees accept via a code and are
handed off into signup. ([`accept_invite.dart`](../homies_mobile/lib/screens/accept_invite.dart))

### Leaseholder / tenant onboarding — `/onboarding/leaseholder`, `/onboarding/tenant`
Guided setup. Leaseholders configure the property and lease; tenants submit ID
docs, bond proof, and advance-rent proof, and accept the house rules.
([`leaseholder_onboarding.dart`](../homies_mobile/lib/screens/leaseholder_onboarding.dart),
[`tenant_onboarding.dart`](../homies_mobile/lib/screens/tenant_onboarding.dart))

---

## Primary

### Dashboard — `/app`
At-a-glance home: who's living here, what's owed, outstanding chores, and recent
activity. ([`dashboard.dart`](../homies_mobile/lib/screens/dashboard.dart))

### Property & lease — `/app/property`
The address, type, bedrooms/bathrooms, features (parking, laundry, dishwasher,
etc.), managing agent, lease start/end, rent amount + cadence, bond weeks, and
advance weeks. ([`property.dart`](../homies_mobile/lib/screens/property.dart))

### Housemates — `/app/housemates`
Everyone in the house with role, contact details, move-in date, and verification
status (ID verified, bond paid, advance rent paid, rules accepted). Pending
housemates are shown separately. ([`housemates.dart`](../homies_mobile/lib/screens/housemates.dart))

### Tenant performance — `/app/performance` *(leaseholder-only)*
A scorecard per tenant: chore completion rate, overdue/excused tasks, bills paid
vs owed, late payments, complaint severity, parties hosted, and an overall
"standing" score. ([`tenant_performance.dart`](../homies_mobile/lib/screens/tenant_performance.dart))

---

## Money

### Bills — `/app/bills`
One-off and recurring bills with a category, amount, due date, and a **split**
(equal or custom shares). Tracks who has paid, supports proof attachments, and
can be generated from a **bill schedule** (cadence, estimated amount,
participants). ([`bills.dart`](../homies_mobile/lib/screens/bills.dart))

### Subscriptions — `/app/subscriptions`
Shared recurring services (streaming, etc.): amount, cadence, who pays, who
participates, and how it's split. ([`subscriptions.dart`](../homies_mobile/lib/screens/subscriptions.dart))

### Groceries — `/app/groceries`
Shared grocery runs: total, who paid, split method + shares, date, and an
optional receipt. ([`groceries.dart`](../homies_mobile/lib/screens/groceries.dart))

### Necessities — `/app/necessities`
Small shared household items (toilet paper, dish soap): item, who paid, amount,
and date — shared or personal. ([`necessities.dart`](../homies_mobile/lib/screens/necessities.dart))

---

## Living together

### Cleaning — `/app/cleaning`
A **roster** (day / area / assignee) plus **tasks** with due dates. Tasks can be
marked done with **photo proof**, or skipped with a logged **excuse** — keeping a
paper trail. Outstanding tasks badge in the nav.
([`cleaning.dart`](../homies_mobile/lib/screens/cleaning.dart))

### House rules — `/app/rules`
A shared list of rules, each with who added it and when. Tenants accept the
rules during onboarding. ([`house_rules.dart`](../homies_mobile/lib/screens/house_rules.dart))

### Parties — `/app/parties`
Plan events with date, time, host, and notes; housemates RSVP, and a party moves
through planning → confirmed states. ([`parties.dart`](../homies_mobile/lib/screens/parties.dart))

### Messages — `/app/messages`
A house **group chat** plus direct messages. Supports text posts and **polls**
(single or multi-choice, with live vote tallies).
([`messages.dart`](../homies_mobile/lib/screens/messages.dart))

### House issues — `/app/issues`
Maintenance log: title, category (plumbing, appliance, electrical, structure,
pest, other), description, optional photo, who raised it, and open/fixed status.
([`issues.dart`](../homies_mobile/lib/screens/issues.dart))

### Complaints — `/app/complaints`
Formal housemate complaints: who it's against, the reason, a severity rating, and
open/resolved status. Open complaints badge in the nav.
([`complaints.dart`](../homies_mobile/lib/screens/complaints.dart))

### Find a room (Marketplace) — `/app/listings`
A two-sided marketplace:
- **Leaseholders** list an available room (rent, suburb, available-from,
  description).
- **Seekers** post what they're after (budget, suburb, move-in date).

Browse open listings in either direction, then **express interest** — choosing
exactly which of your details (name / email / phone / move-in date) to share on a
match. Interests have pending / accepted / declined states.
([`listings.dart`](../homies_mobile/lib/screens/listings.dart))

---

## Wrap up (moving out)

### Leaving — `/app/leaving`
A housemate gives notice: notice date, intended leave date, reason, and how the
bond should be returned, including itemized **deductions** with an explanation
the tenant can agree to. ([`leaving.dart`](../homies_mobile/lib/screens/leaving.dart))

### End of lease — `/app/termination` *(leaseholder-only)*
Plan a full lease termination: itemized end-of-lease **expenses**, a split mode
(equal or custom shares per person), and notes.
([`termination.dart`](../homies_mobile/lib/screens/termination.dart))

---

## Cross-cutting capabilities

- **Fair splits everywhere** — equal or custom shares on bills, subscriptions,
  groceries, and termination costs.
- **Proof & paper trail** — attachments on bills, grocery receipts, cleaning
  photos, ID/payment docs during onboarding.
- **Prorating** — bond and bills account for move-in dates.
- **Role-aware UI** — leaseholder-only tools are hidden from tenants.
- **Offline-first** — state persists locally; the demo runs with no backend.
