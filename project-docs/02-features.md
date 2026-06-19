# Features

Homies is organised around a house: a **leaseholder** sets up a property and invites **tenants**; everyone then manages shared living together. Features below are grouped by area. Most exist in both the Flutter mobile app (`frontend_app/lib/screens/`) and the React web app (`frontend_web/src/pages/`).

---

## 1. Authentication & Onboarding

- **Welcome** (`/`) — landing intro with sign up / login.
- **Login** (`/login`) — email/password via Firebase Auth.
- **Demo login** (`/demo`) — quick access pre-loaded with seed data.
- **Signup** (`/signup`) — choose role (leaseholder or tenant), enter name/email/password/phone. Creates a Firebase user + a `pending` profile. Non-invited signups are marketplace-only (not yet a house member).
- **Accept invite** (`/invite/:code`) — open an invite link; email & role are pre-filled, then routes into signup.
- **Leaseholder onboarding** (`/onboarding/leaseholder`) — set up the property: address, type, bedrooms, bathrooms, max occupants, features, agent contact, lease dates, rent amount & cadence, bond weeks, advance-rent weeks, initial house rules, and invite tenants by email.
- **Tenant onboarding** (`/onboarding/tenant`) — upload ID document, bond proof, advance-rent proof; set move-in date; accept house rules; answer lifestyle questions; add emergency contact. Tenant becomes `pending` awaiting leaseholder approval. Bond auto-calculated as `rentAmount * bondWeeks / maxOccupants`.

## 2. Dashboard (`/app`)

At-a-glance home screen showing: amount you owe (+ bill count), your outstanding chores, active housemates vs. max occupants (+ pending invites), lease end date, and next rent date. Cards surface: profile-completion prompt, rent due alert, bills due within 7 days, your current tasks, upcoming parties, and open complaints.

## 3. Bills & Expenses (`/app/bills`)

- Track one-off bills split among housemates. Categories: utility, internet, water, maintenance, cleaning, pest, other.
- Split methods: equal, percentage, custom, prorated. Per-person shares tracked.
- **Tabs:** Upcoming (unsettled), History (settled), Schedules (recurring).
- Mark your share paid (records a payment), attach bill proof, create a bill from a schedule.
- **Bill schedules** — recurring bills (weekly → yearly or custom days) that auto-generate the next bill on its due date.

## 4. Subscriptions (`/app/subscriptions`)

Recurring shared services (Netflix, Spotify, gym, etc.): name, amount, cadence (monthly/yearly), who pays, who benefits, and equal/percentage split per person.

## 5. Cleaning (`/app/cleaning`)

- **Roster** — rotating per-day area assignments; leaseholder sets cadence (weekly/fortnightly/monthly) and edits day/area/assignee.
- **Tasks** — one-off/recurring cleaning tasks with assignee and due date. Mark done/undo, attach photo proof, or log an excuse if missed.

## 6. Groceries (`/app/groceries`)

Log a grocery shop (title, total, payer), choose shared (split equally with housemates) or individual, upload a receipt, and view the per-person breakdown.

## 7. Necessities (`/app/necessities`)

Record shared household consumables (toilet paper, detergent, etc.): item, payer, amount, split (equal/percentage), and participants. Buyer is auto-marked paid; others mark their portion as reimbursed.

## 8. Housemates (`/app/housemates`)

- **Awaiting approval** (leaseholder) — review pending tenants and their submissions (ID, bond proof, advance-rent proof); approve or decline.
- **Active housemates** — cards with avatar, name, role, contact, bond status, ID verification, move-in/out dates.
- **Pending invites** — emails invited but not yet signed up (with invite code & sent date).
- Invite new housemates by email with a unique code and role.

## 9. Profile & Lifestyle (`/app/profile`)

Answer lifestyle questions (smoking, alcohol, relationship, pets, diet, occupation, schedule, guests, about) and provide an emergency contact. Profile is "complete" when required fields + emergency contact are filled — required before joining a house and used for housemate matching.

## 10. Property & Lease (`/app/property`)

View property details: address, type, bedrooms/bathrooms, max occupants, features, agent contact, lease dates, rent (amount/cadence/start), bond weeks (+ estimate), advance-rent weeks. Editable by the leaseholder only.

## 11. Marketplace & Listings (`/app/listings`)

- Dual-mode marketplace: leaseholders post **rooms available** (tenant-wanted); seekers post **room wanted**.
- Listing fields: type, title, suburb, description, rent/budget per week, available-from, status.
- **Tabs:** Rooms Available, Room Wanted, My Listings, Inbox (applications received), Sent (applications submitted).
- Express interest with an optional message and chosen profile fields to share; poster accepts/declines and closes listings.
- **Inspections** — request a viewing with date/slot/note; leaseholder confirms or declines.
- **Post threads** (`/app/post/...`) — 1:1 conversation per listing; can request and share a tenant performance reference.

## 12. Messages (`/app/messages`)

Group messages (whole house) and direct messages (1:1). Send text or create **polls** (single/multiple choice) that housemates vote on; polls can be closed.

## 13. House Rules (`/app/rules`)

Leaseholder sets initial rules during onboarding (defaults include a smoking policy and quiet hours) and can add/edit/delete anytime. Tenants accept rules on joining (`acceptedRulesAt`) and then view read-only.

## 14. Parties & Events (`/app/parties`)

Host proposes a party (title, date, time, notes); housemates respond "I'm in" / "Push it" / "Pass"; status updates (planning/confirmed/cancelled) based on responses.

## 15. Issues & Maintenance (`/app/issues`)

Any housemate raises an issue (category: plumbing, appliance, electrical, structure, pest, other) with description and photo. Anyone can mark it fixed (records who/when). Separated into Open and Fixed.

## 16. Complaints (`/app/complaints`)

File a complaint against a housemate with a reason and severity. A per-person complaint score accumulates; a threshold (~100 points) flags serious action and drags down the tenant's performance standing.

## 17. Tenant Departure

- **Leaving notice** (`/app/leaving`) — tenant gives 2-week notice (earliest leave date = today + 14 days) with reason; leaseholder sets bond-return method and deductions; tenant agrees/disputes.
- **Termination & bond settlement** (`/app/termination`) — leaseholder adds final expenses (cleaning, repairs), picks a split method, and the app calculates each person's final settlement.

## 18. Tenant Performance (`/app/performance`)

Leaseholder-only standing score (0–100) per tenant, computed from chore completion (45%), bill payment rate (30%), and complaint severity (25%), minus penalties for overdue tasks/late bills. Banded as Good (80+) / Fair (60–79) / Needs attention (<60). A **performance snapshot** can be shared as a reference in listing threads.

---

## Cross-cutting capabilities

- **Role-based access** — leaseholders manage property, rules, invites, schedules, approvals, performance, and termination; tenants manage their profile/onboarding, log expenses, mark shares paid, message, respond to parties, raise issues/complaints, and give notice. Both view the dashboard, listings, messages, rules, property, and housemates.
- **Expense splitting** — equal, percentage, custom, and prorated calculations across bills, necessities, groceries, subscriptions, and termination.
- **Attachments** — uploads (receipts, ID docs, bond/advance proof, cleaning photos, issue photos) stored as attachments with filename/type/size/timestamp.
- **Calculations** — bond per tenant, next rent date from cadence, performance scoring, and settlement splits.
