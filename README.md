# Nourish Network

A neighborhood food rescue pilot: local shops publish surplus, charities and volunteers claim pickups, and the community can see what was rescued.

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

This is a starter for a single-neighborhood pilot, not a production food safety or logistics system. Before real use, add durable storage, authentication and organization roles, privacy controls, monitoring, and locally appropriate food safety workflows.
