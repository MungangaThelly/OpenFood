# Nourish Network

A neighborhood food rescue pilot: local shops publish surplus, charities and volunteers coordinate pickups, and each handoff has a reviewable activity history.

## Start locally

Requires Erlang/OTP and Rebar3. From the project root:

```sh
rebar3 get-deps
rebar3 shell
```

Open [http://localhost:8080](http://localhost:8080). The demo stores offers in memory; restarting the app clears them. API examples are in `docs/API.md`.

## Project documents

- [Pilot product requirements](docs/PRODUCT.md)
- [OTP architecture](docs/ARCHITECTURE.md)
- [API quick reference](docs/API.md)

The demo captures donor-provided date marking, traceability reference, handling instructions, a donor safety declaration, recipient checks, and issue resolution. Actor names are self-reported and records are in memory, so it is not a production food safety or audit system. Before real use, add durable tamper-resistant storage, authentication and organization roles, privacy controls, monitoring, and workflows reviewed with local food businesses and municipal food control.
