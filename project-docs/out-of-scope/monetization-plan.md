# Monetization Plan

These are the planned revenue streams for Homies. None require changes to core app logic — they layer on top of what's already built. All require a payment integration (Stripe or similar) before shipping.

---

## Revenue Streams

### 1. Premium Subscription — Leaseholders (~$9–15/month per house)

Leaseholders are the power users: they recruit tenants, manage finances, and have the highest intent. One leaseholder per house pays; tenants stay free.

**What goes behind the paywall:**
- Full leaseholder review history in the marketplace (stub already exists — `_LockedMoreReviews` widget in `listings.dart`)
- Tenant performance reports / portable references (perf-request/perf-share flow already built)
- Boosted or pinned room listings
- Data export (`/export` screen already exists)
- Priority inspection scheduling

**Why this first:** The locked-reviews UI is already shipped. It's a matter of wiring up a payment gate.

---

### 2. Listing Boosts — One-off (~$5–10 per listing, 7-day pin)

Leaseholders pay to have their room listing shown at the top of the marketplace for a week. Targets the highest-intent moment: urgently needing a tenant.

**Where:** "Boost this listing" button on the `_PostCard` owner footer in `listings.dart`.

**Why:** Low friction, one-tap transaction. No subscription required.

---

### 3. Verified Tenant Profile — One-off or annual (~$15–20)

Tenants pay for a "Verified" badge on their marketplace profile, covering:
- Verified ID
- Verified income/employment
- Portable reference from previous leaseholder (via the existing perf-share flow)

**Why:** Leaseholders prefer verified applicants → tenants have incentive to pay to stand out in a competitive market.

---

## What's Out of Scope (for now)

| Idea | Why not yet |
|---|---|
| Rent payment processing | High compliance burden, thin margins, complex integration |
| B2B property manager SaaS | Different product and sales motion — don't pivot |
| In-app advertising | Kills trust; users share sensitive financial info in this app |

---

## Implementation Notes

- All three streams need a backend payment endpoint that records a completed purchase and unlocks the relevant content for that user.
- Unlocks must be durable (stored server-side), not session-based.
- Start with stream 1 (Premium) since the UI gate already exists.
- Stream 2 (boosts) is the fastest to ship — single button, single charge, no subscription logic.
- Stream 3 (Verified badge) needs an ID verification partner (e.g. Stripe Identity, Persona).
