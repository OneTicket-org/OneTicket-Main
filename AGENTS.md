# OneTicket documentation

## Doc map

- [docs/constraints/README.md](docs/constraints/README.md) — tag legend, team/scope/actors, architectural constraints, required ADRs, mandated infrastructure. Read first.
  - [business-rules.md](docs/constraints/business-rules.md) — seat, order, payment, ticket-validation rules. Read for domain/feature work.
  - [service-design.md](docs/constraints/service-design.md) — layering, domain model, ports/adapters, transactions. Read when implementing service internals.
  - [http-api.md](docs/constraints/http-api.md) — URIs, methods/status codes, idempotency, caching, pagination, headers, request parsing. Read when designing/implementing endpoints.
  - [operations.md](docs/constraints/operations.md) — resilience, performance & capacity, observability, configuration. Read for NFR/infra/deployment work.
  - [security.md](docs/constraints/security.md) — authentication. Read for auth work.
  - [code-style.md](docs/constraints/code-style.md) — Kotlin/Spring and Rust/Axum conventions, testing & CI. Read when writing, reviewing or testing code.
- [docs/glossary.md](docs/glossary.md) — domain terms.
- [docs/milestones/milestone1/milestone1.md](docs/milestones/milestone1/milestone1.md) — Milestone 1: domain scope, actors, user stories, service decomposition.
- [docs/milestones/milestone2/data_ownership.md](docs/milestones/milestone2/data_ownership.md) — Milestone 2: which service owns which data.
- [docs/milestones/milestone2/purchase_flow.md](docs/milestones/milestone2/purchase_flow.md) — Milestone 2: ticket purchase flow (sequence diagram).
- [docs/adr/](docs/adr/) — architecture decision records.
  - [0001-seat-inventory-placement.md](docs/adr/0001-seat-inventory-placement.md) — seats, holds and orders in Inventory & Orders; Catalogue keeps events and venues.
  - [0002-public-seat-map.md](docs/adr/0002-public-seat-map.md) — seat maps and catalogue event/venue reads readable without authentication (deviation from [SEC-02]).

## Rules for agents

- Precedence: `docs/constraints/` is binding. Milestone docs record decisions and history; a later milestone supersedes an earlier one. Constraints win over milestone docs; report any conflict instead of resolving it silently.
- **TODO** rules are open points: never invent an answer for them. Flag the gap, or propose an ADR.
- Cite rules by ID (e.g. `[API-07]`) in code comments, reviews and ADRs. IDs are stable; see [docs/constraints/README.md](docs/constraints/README.md) for the scheme.

## Service repositories

Each service lives in its own repository; links are listed in [README.md](README.md#service-repositories).
