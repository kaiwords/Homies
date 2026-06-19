# Data model

All entities are defined in
[`homies_mobile/lib/state/models.dart`](../homies_mobile/lib/state/models.dart)
as plain mutable classes with `toJson` / `fromJson`. The React app mirrors the
same shapes ([`src/data/mockData.js`](../src/data/mockData.js)).

## Core entities

### User
A person in the house.
| Field | Notes |
|-------|-------|
| `id`, `name`, `initials` | identity |
| `role` | `leaseholder` \| `tenant` |
| `email`, `phone` | contact |
| `moveInDate`, `moveOutDate` | tenancy dates |
| `bondPaid`, `bondAmount` | bond status |
| `advanceRentPaid` | advance rent status |
| `docVerified` | ID verification |
| `acceptedRulesAt` | when house rules were accepted |
| `pending` | still onboarding |
| `submissions` | ID doc + bond/advance payment proofs |

### Property
The house and lease: `address`, `type`, `bedrooms`, `bathrooms`, `features`
(map), `agent` + `agentContact`, `leaseStart`/`leaseEnd`, `rentAmount` +
`rentCadence`, `rentStartDate`, `bondWeeks`, `advanceWeeks`, `maxOccupants`,
`setupComplete`.

### Session
`userId` of the signed-in user, plus any `pendingSignup` data.

## Money

| Entity | Key fields |
|--------|-----------|
| **Bill** | `title`, `category`, `amount`, `dueDate`, `issuedBy`, `split`, `shares`, `status`, `paidBy`, optional `scheduleId` + `proof` |
| **BillSchedule** | recurring template: `cadence`, `customDays`, `cycleStart`, `nextDueDate`, `estimatedAmount`, `splitMethod`, `participants`, `active` |
| **Subscription** | `name`, `amount`, `cadence`, `payer`, `participants`, `split`, `shares` |
| **Grocery** | `title`, `total`, `payer`, `mode`, `split`, `shares`, `date`, optional `receipt` |
| **Necessity** | `item`, `mode`, `payer`, `amount`, `date` |

`split` is `equal` or `custom`; `shares` maps userId → amount/weight.

## Living together

| Entity | Key fields |
|--------|-----------|
| **HouseRule** | `text`, `addedBy`, `addedAt` |
| **CleaningRosterEntry** | `day`, `area`, `assignee` |
| **CleaningTask** | `task`, `assignee`, `dueDate`, `done`, optional `photo`, `excuse`, `completedAt` |
| **Party** | `title`, `date`, `time`, `host`, `notes`, `responses` (RSVP), `status` |
| **Message** | `from`, `text`, `at`, `type` (`text`\|`poll`), optional `poll` |
| **MessagePoll** | `question`, `multi`, `closed`, `options`, `votes` |
| **Messages** | `group` list + per-user `dms` map |
| **Complaint** | `against`, `from`, `reason`, `severity`, `date`, `status` |
| **Issue** | `title`, `category`, `description`, optional `photo`, `raisedBy`, `status`, `fixedAt`/`fixedBy` |

## Marketplace

| Entity | Key fields |
|--------|-----------|
| **Listing** | `type` (`tenant-wanted` = room available \| `room-wanted` = seeker), `by`, `title`, `suburb`, `rent` or `budget`, `availableFrom`, `description`, `status` |
| **ListingInterest** | `listingId`, `from`, `to`, `message`, `sharedFields` (chosen detail map), `status` (`pending`\|`accepted`\|`declined`) |

## Moving out

| Entity | Key fields |
|--------|-----------|
| **Notice** | `userId`, `givenAt`, `leaveDate`, `reason`, `bondReturn`, `deductions[]`, `deductionExplanation`, `tenantAgreed` |
| **Deduction** | `reason`, `amount` |
| **TerminationPlan** | `expenses[]`, `splitMode`, `customShares`, `notes` |
| **TerminationExpense** | `reason`, `amount` |

## Shared

| Entity | Key fields |
|--------|-----------|
| **Invite** | `code`, `email`, `role`, `sentAt`, `status` |
| **Attachment** | `fileName`, `dataUrl` (base64), `type`, `size`, `uploadedAt` |
| **Submissions** | `idDoc`, `bondProof`, `advanceRentProof` |
