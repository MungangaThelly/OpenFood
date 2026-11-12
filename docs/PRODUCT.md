# Product requirements: neighborhood food rescue pilot

## Goal

Help local food businesses get edible surplus to charities, volunteers, and residents before it expires. The pilot should make the handoff clear and measure completed rescues rather than merely posted food.

## Pilot users

- **Business staff** publish a surplus listing with a description, quantity, unit, pickup address, pickup deadline, date marking, handling/storage instructions, donor contact, batch reference, and free/discounted price.
- **Charity coordinators and volunteers** discover listings, claim one, check the food and its date at handoff, record quantity and pickup conditions, and raise an issue if needed.
- **Residents** browse discounted and donated food and see the pickup details they need.
- **Pilot coordinator** reviews activity and resolves missed or disputed pickups.

## Core flow

1. Business posts an offer with an explicit pickup deadline and quantity.
2. The system makes it visible and sends matching nearby organizations/volunteers an alert.
3. One eligible recipient claims the offer; the listing is no longer claimable.
4. The recipient checks condition, package, date marking, and applicable temperature; they record the received quantity and named confirmation.
5. Either party can report a pickup or food issue. A coordinator records how it was resolved.
6. Unclaimed listings expire at the deadline. The event is recorded in the offer history.

## First release scope

- Create, browse, claim, collect, cancel, and expire offers; report and resolve handoff exceptions.
- Keep a chronological per-offer activity log with timestamp, actor label, action, and relevant handoff details.
- Capture date marking, storage/handling, traceability reference, donor contact, and recipient handoff checks.
- Live offer updates in the browser.
- Basic impact totals: completed pickups and rescued quantity, grouped by unit. Do not combine unlike units into a misleading weight total.
- A responsive web view usable on a phone at pickup.
- One pilot neighborhood with manually entered addresses and a single default radius; no routing or payments.

## Excluded from the pilot

Household pantry tracking, route optimization, automated payments, multi-region dispatch, ratings, and carbon-equivalent claims. Add only after validating the local pickup loop.

## Acceptance criteria

- A business can publish all required offer details and see it appear in the feed.
- Two recipients racing to claim the same offer cannot both succeed.
- A claimed offer cannot be claimed again; only a claimed offer can be marked collected.
- Expired and cancelled offers are not claimable.
- Impact counts only collected quantity and keeps units separate.
- A connected feed receives offer and status changes without manual refresh.
- The interface clearly distinguishes free from discounted and displays the pickup deadline.
- A pickup cannot be completed without a named recipient confirmer, quantity, package/condition check, and date check.
- Each state transition is visible in the offer's activity history.

## Pilot measures

- Completed pickups / published offers
- Quantity collected by unit
- Time from publication to claim
- Offers expiring unclaimed
- Repeat participation by businesses and recipient organizations

## Operational and trust requirements

Show ingredients/allergen notes when supplied, handling instructions, and the responsible business contact. The platform should not imply that it inspected or certified food. The demo records self-reported actor labels and is not authenticated or tamper-proof; use verified organization accounts, durable append-only audit storage, access controls, privacy controls, and retention rules before a live pilot.
