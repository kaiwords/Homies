# Data Model

All entities live in the client store (`HomiesState` on mobile, `HomiesContext` on web), are serialized to JSON, and persisted locally. Only the **User profile** and auth state are also synced to **Cloud Firestore** (`users/{uid}`). Field names below come from `frontend_app/lib/state/models.dart` and `performance.dart`.

---

## Identity & people

### User
`id`, `name`, `initials`, `role` (leaseholder | tenant), `email`, `phone`, `moveInDate`, `moveOutDate`, `bondPaid`, `bondAmount`, `docVerified`, `advanceRentPaid`, `acceptedRulesAt`, `pending` (awaiting approval), `member` (house member vs. marketplace-only), `lifestyle`, `emergency`, `submissions`.

### Lifestyle
`smoking` (non-smoker | outside-only | smoker), `alcohol` (none | social | regular), `relationship` (single | relationship | married), `pets` (none | has-pets), `diet` (none | vegetarian | vegan | halal | other), `occupation`, `schedule` (early-bird | flexible | night-owl), `guests` (rarely | sometimes | often), `about`.

### EmergencyContact
`name`, `relationship`, `phone`.

### Submissions (tenant onboarding)
`idDoc`, `bondProof`, `advanceRentProof` — each an Attachment.

### Invite
Invited email + unique code + role + sent date + accepted status.

---

## Property

### Property
`id`, `address`, `type`, `bedrooms`, `bathrooms`, `features` (map), `agent`, `agentContact`, `leaseStart`, `leaseEnd`, `rentAmount`, `rentCadence` (weekly | fortnightly | monthly), `rentStartDate`, `bondWeeks`, `advanceWeeks`, `maxOccupants`, `setupComplete`, `cleaningCadence`.

### HouseRule
`id`, `text`, `addedBy`, `addedAt`.

---

## Money

### Bill
`id`, `title`, `category` (utility | internet | water | maintenance | cleaning | pest | other), `amount`, `periodStart`, `periodEnd`, `dueDate`, `issuedBy`, `split` (equal | percentage | custom | prorated), `shares`, `status` (pending | settled), `paidBy` (map), `payments`, `proof` (Attachment).

### BillSchedule
`id`, `title`, `category`, `cadence` (weekly | fortnightly | monthly | quarterly | half-yearly | yearly | custom), `customDays`, `cycleStart`, `nextDueDate`, `estimatedAmount`, `splitMethod`, `participants`, `active`, `createdBy`.

### Payment
Timestamp, amount, payer name (a record appended when a share is paid).

### Subscription
`id`, `name`, `amount`, `cadence` (monthly | yearly), `payer`, `participants`, `split` (equal | percentage), `shares`.

### Grocery
`id`, `title`, `total`, `payer`, `mode` (shared | individual), `split` (equal), `shares`, `date`, `receipt` (Attachment).

### Necessity
`id`, `item`, `mode` (shared | individual), `payer`, `amount`, `date`, `split` (equal | percentage), `participants`, `shares`, `paidBy`, `payments`.

---

## Cleaning

### CleaningRosterEntry
`day` (Mon–Sun), `area`, `assignee`.

### CleaningTask
`id`, `task`, `assignee`, `dueDate`, `done`, `completedAt`, `photo` (Attachment), `excuse`.

---

## Communication & events

### Message
`id`, `from`, `text`, `at`, `type` (text | poll), `poll` (optional). Used for both group and direct messages.

### MessagePoll
`question`, `multi`, `closed`, `options` (PollOption: `id`, `text`, `addedBy`), `votes` (optionId → voter ids).

### Party
`id`, `title`, `date`, `time`, `host`, `notes`, `responses` (userId → accept | push | decline), `status` (planning | confirmed | cancelled).

---

## Issues & complaints

### Issue
`id`, `title`, `category` (plumbing | appliance | electrical | structure | pest | other), `description`, `photo` (Attachment), `raisedBy`, `raisedAt`, `status` (open | fixed), `fixedAt`, `fixedBy`.

### Complaint
`id`, `against`, `from`, `reason`, `severity`, `date`, `status` (open | resolved).

---

## Departure

### Notice (leaving)
`id`, `userId`, `givenAt`, `leaveDate`, `reason`, `bondReturn` (after-agent | manual), `deductions` (Deduction: `reason`, `amount`), `deductionExplanation`, `tenantAgreed`.

### TerminationPlan
`expenses` (TerminationExpense: `id`, `reason`, `amount`), `splitMode` (equal | percentage | custom), `customShares` (userId → amount), `notes`.

---

## Marketplace

### Listing
`id`, `type` (tenant-wanted | room-wanted), `by`, `title`, `suburb`, `description`, `rent` (for tenant-wanted) / `budget` (for room-wanted), `availableFrom`, `status` (open | closed), `createdAt`.

### ListingInterest
`id`, `listingId`, `from`, `to`, `message`, `sharedFields`, `lifestyle`, `emergency`, `status` (pending | accepted | declined), `createdAt`.

### Inspection
`id`, `listingId`, `requestedBy`, `to`, `date`, `slot`, `note`, `status` (requested | confirmed | declined), `createdAt`.

### PostMessage
`id`, `listingId`, `from`, `to`, `text`, `at`, `kind` (text | perf-request | perf-share), `perf` (PerfSnapshot).

---

## Performance (computed)

### TenantStats / PerfSnapshot
Standing (0–100) and band (Good | Fair | Needs attention), chore done/total + rate (45% weight), bill paid/total + rate (30% weight), complaint severity (25% weight), penalties (−4 per overdue task / late bill), parties hosted, house address, optional leaseholder note.

---

## Shared

### Attachment
`fileName`, `dataUrl`, `type` (MIME), `size`, `uploadedAt`. Used for bill proof, cleaning photos, grocery receipts, ID documents, bond/advance proof, and issue photos.

### Session / persisted root
`userId`, `pendingSignup`, plus the full collections: Property, Users, Invites, HouseRules, Bills, BillSchedules, Subscriptions, Groceries, Necessities, CleaningRoster, CleaningTasks, Parties, Messages, Complaints, Issues, Notices, TerminationPlan, Listings, ListingInterests, Inspections, PostMessages.
