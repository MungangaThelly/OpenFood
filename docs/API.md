# API quick reference

The starter API is unauthenticated and intended for local development only.

## Create offer

`POST /api/offers`

```json
{
  "business": "Northside Market",
  "title": "Bakery and produce box",
  "quantity": 8,
  "unit": "boxes",
  "pickup_by": "2027-04-30T18:30:00Z",
  "address": "12 Market Street",
  "kind": "donation",
  "price": 0,
  "notes": "Contains mixed produce; ask staff about allergens"
}
```

`kind` is `donation` or `discount`. `quantity` must be positive; `pickup_by` must be an ISO-8601 UTC timestamp.

## Browse offers

`GET /api/offers` returns currently available, unexpired offers.

## Claim / collect / cancel

- `POST /api/offers/:id/claim` with `{"recipient":"Northside Community Pantry"}`
- `POST /api/offers/:id/collect` with `{"quantity":5}`
- `POST /api/offers/:id/cancel`

## Impact and live updates

- `GET /api/impact` returns collected totals grouped by unit.
- `GET /api/events` streams offer changes as Server-Sent Events.
