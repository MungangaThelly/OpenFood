# API quick reference

The API is unauthenticated and intended for a local demo only. Actor names and confirmations are self-reported; they are not verified identities or food safety certification.

## Create offer

`POST /api/offers`

```json
{
  "business": "Northside Market",
  "posted_by": "Alex Andersson",
  "title": "Chilled vegetable soup",
  "quantity": 8,
  "unit": "portions",
  "pickup_by": "2027-04-30T18:30:00Z",
  "address": "12 Market Street, Stockholm",
  "kind": "donation",
  "price": 0,
  "date_type": "best_before",
  "date_value": "2027-04-30",
  "storage_temperature": "Keep chilled at 0-4 C",
  "ingredients": "Milk; contains dairy",
  "handling": "Keep chilled during transport",
  "donor_contact": "Store duty manager, 070-000 0000",
  "batch_reference": "NM-2027-04-30-01",
  "donor_safety_confirmed": true,
  "notes": "Outer box slightly marked"
}
```

`kind` is `donation` or `discount`. `date_type` is `best_before`, `use_by`, or `not_applicable`. Quantity must be positive and `pickup_by` must be an ISO-8601 timestamp. A use-by date must not precede the pickup date. The donor declaration is recorded as an assertion by the posting user; the platform does not inspect or certify food.

## Browse offers

`GET /api/offers` returns all offer records, including completed and expired records, for the demo board and history review.

## Claim, collect, exception, and audit

- `POST /api/offers/:id/claim` with `{"recipient":"Northside Community Pantry","actor":"Volunteer name"}`
- `POST /api/offers/:id/collect` with `{"quantity":5,"confirmed_by":"Volunteer name","package_intact":true,"date_checked":true,"temperature_c":4,"condition_notes":"Chilled and intact"}`
- `POST /api/offers/:id/cancel` with `{"actor":"Store manager"}`
- `POST /api/offers/:id/issue` with `{"actor":"Volunteer name","reason":"Seal damaged"}`
- `POST /api/offers/:id/resolve` with `{"actor":"Coordinator name","resolution":"Offer withdrawn and donor informed"}`
- `POST /api/offers/:id/audit` returns the chronological event history for the offer.

Pickup confirmation requires a positive received quantity no greater than the posted amount, a named confirmer, a package/condition check, and a date check. Temperature is optional because it does not apply to every food type; donor storage and handling instructions remain with the offer record.

## Impact and live updates

- `GET /api/impact` returns completed pickups and rescued quantities grouped by unit.
- `GET /api/events` streams offer changes as Server-Sent Events.
