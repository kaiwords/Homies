# Out of Scope — Paid / Premium Features

These features are intentionally deferred. They require a payment integration layer (Stripe or similar) before they can be shipped. The UI stubs exist in the app (locked state, "Coming soon" badges) but no transaction logic is implemented.

---

## 1. Tenant: Unlock additional leaseholder reviews

**What**: Tenants browsing marketplace listings can see **1 free review** about a leaseholder left by a previous tenant. To see any additional reviews beyond the first, the tenant must pay.

**Where in the app**: `_PostCard` → `_LhReputationSection` → `_LockedMoreReviews` widget.

**Trigger**: Tapping "Unlock with Premium" on the locked review row.

**Suggested pricing**: Per-leaseholder unlock (e.g. $1.99) or a subscription bundle.

**Why deferred**: Stripe/payment SDK not yet integrated; review volume is also too low at launch to justify the friction.

---

## 2. Leaseholder: Unlock tenant performance reports from previous leaseholders

**What**: A leaseholder who receives an application from a tenant can pay to see a **performance report** about that tenant — compiled from feedback/ratings left by their previous leaseholders.

**Where in the app**: Leaseholder-to-leaseholder performance request flow (`_PerfRequestBanner` in `listings.dart`).

**Trigger**: When a leaseholder wants to view more than what is freely shared in the performance request response.

**Suggested pricing**: Per-tenant lookup (e.g. $2.99) or a credits bundle.

**Why deferred**: Same as above — payment integration required. Also needs a moderation layer so reports can't be abused vindictively.

---

## Notes for implementation

- Both features need a backend endpoint that records a completed purchase and unlocks the content for that specific user + target pair.
- Unlocks should be durable (stored against the user's account), not session-based.
- Consider a 7-day refund window if the review/report turns out to be empty.
- Abuse prevention: flag suspiciously negative review clusters for manual review before they're shown to paying users.
