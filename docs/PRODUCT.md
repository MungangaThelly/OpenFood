# Product requirements: neighborhood food rescue pilot

## Goal

Help local food businesses get edible surplus to charities, volunteers, and residents before it expires. The pilot should make the handoff clear and measure completed rescues rather than merely posted food.

## Pilot users

- **Business staff** publish a surplus listing with a description, quantity, unit, pickup address, pickup deadline, and free/discounted price.
- **Charity coordinators and volunteers** discover nearby listings, claim one, and mark it collected.
- **Residents** browse discounted and donated food and see the pickup details they need.
- **Pilot coordinator** reviews activity and resolves missed or disputed pickups.

## Core flow

1. Business posts an offer with an explicit pickup deadline and quantity.
2. The system makes it visible and sends matching nearby organizations/volunteers an alert.
3. One eligible recipient claims the offer; the listing is no longer claimable.
4. The recipient collects it and records the completed quantity.
5. Unclaimed listings expire at the deadline. A coordinator can cancel or resolve exceptions.

## First release scope

- Create, browse, claim, collect, cancel, and expire offers.
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

## Pilot measures

- Completed pickups / published offers
- Quantity collected by unit
- Time from publication to claim
- Offers expiring unclaimed
- Repeat participation by businesses and recipient organizations

## Operational and trust requirements

Show ingredients/allergen notes when supplied, handling instructions, and the responsible business contact. The platform should not imply that it inspected or certified food. Use verified organization accounts for charity-only allocations, collect only necessary personal data, and set retention rules before launch.
