# OneTicket documentation

## Doc map

- [docs/constraints/README.md](docs/constraints/README.md) — tag legend, team/scope/actors, architectural constraints, required ADRs, mandated infrastructure. Read first.
  - [business-rules.md](docs/constraints/business-rules.md) — seat, order, payment, ticket-validation rules. Read for domain/feature work.
  - [service-design.md](docs/constraints/service-design.md) — layering, domain model, ports/adapters, transactions. Read when implementing service internals.
  - [http-api.md](docs/constraints/http-api.md) — URIs, methods/status codes, idempotency, caching, pagination, headers, request parsing. Read when designing/implementing endpoints.
  - [operations.md](docs/constraints/operations.md) — resilience, performance & capacity, observability, configuration. Read for NFR/infra/deployment work.
  - [security.md](docs/constraints/security.md) — authentication. Read for auth work.
- [docs/glossary.md](docs/glossary.md) — domain terms.
- [docs/milestones/milestone1/milestone1.md](docs/milestones/milestone1/milestone1.md) — Milestone 1: domain scope, actors, user stories, service decomposition.
- [docs/milestones/milestone2/data_ownership.md](docs/milestones/milestone2/data_ownership.md) — Milestone 2: which service owns which data.
- [docs/milestones/milestone2/purchase_flow.md](docs/milestones/milestone2/purchase_flow.md) — Milestone 2: ticket purchase flow (sequence diagram).
