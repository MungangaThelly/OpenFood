# OTP architecture

## Starter topology

```text
Phone/browser
    | HTTP + Server-Sent Events
    v
Cowboy listener (nourish_http_sup)
    | REST requests             | SSE subscribers
    v                           v
Offer registry (gen_server) --> PubSub (pg + per-connection handler)
    |
    +-- in-memory state in this starter
```

`nourish_sup` supervises the web listener and registry. The registry serializes state-changing operations, so a claim is atomic within this node. It broadcasts state changes; clients use Server-Sent Events to update their feed. The starter deliberately keeps state in memory to make the first run simple.

## Production evolution

- Store offers, claims, users, and audit events in PostgreSQL. Enforce claim exclusivity with a transaction and conditional state transition; do not rely on a single BEAM process for correctness across nodes.
- Use an outbox table or durable message broker for notifications so a process restart does not lose alerts. Retry delivery and make consumers idempotent.
- Use Postgres geospatial queries (or a dedicated geo index) for radius matching. Keep recipient preferences and availability explicit.
- Keep the BEAM for connection handling, live event fanout, expiry scheduling, and resilient workers. Partition workers by neighborhood only after load data shows a need; begin with simple supervisors.
- Add authentication, role-based authorization, rate limits, audit trail, secrets management, structured logs, metrics, traces, backups, and health checks before public launch.
- Never store sensitive volunteer data in broad broadcast payloads. Send public listing updates to the feed; deliver recipient-specific contact details only after an authorized claim.

## Reliability notes

The OTP supervision tree restarts a failed registry, but the starter's memory state is lost on restart. Production durability belongs in a database. Use bounded retries for push/email delivery, scheduled expiry backed by persisted deadlines, and reconciliation jobs for stuck claims. For multi-node deployment, use a shared durable event transport; local process groups alone are not cross-cluster durability.

## Suggested production service boundaries

- Offer API: validation, access control, state transitions
- Matching: location and recipient preferences
- Notification workers: push/email/SMS adapters, retries, delivery status
- Pickup coordination: claim lifecycle and exception resolution
- Impact reporting: aggregate completed quantities by unit and date
