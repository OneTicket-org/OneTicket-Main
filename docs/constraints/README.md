# Constraints

## How to read this document

| Tag        | Meaning                                                                                                                                        |
| ---------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| **MUST**   | Explicitly binding for the project: stated as a project requirement, a milestone deliverable, a rule checked at review, or a grading criterion |
| **SHOULD** | Convention or recommendation the course gives for the platform's services; adopt by default, justify deviations in an ADR                      |
| **DOMAIN** | Business rule or invariant of the ticketing domain                                                                                             |
| **INFO**   | Useful fact: sizing figures, versions, scope notes                                                                                             |
| **TODO**   | Open point, still to be defined                                                                                                                |

Each rule carries a stable ID (`[API-07]`): prefix by file (`ARCH` this file, `BIZ`, `SVC`, `API`, `OPS`, `SEC`, `STY`), number unique within the prefix. IDs never change or get reused: new rules take the next free number, removed rules leave a gap, moved rules keep their ID.

## Project specifications

### Team, scope & actors

- **MUST** [ARCH-01] Teams of four students design, implement, operate and document a ticketing platform
- **DOMAIN** [ARCH-02] The platform serves three kinds of user: organisers, customers and gate staff
- **TODO** [ARCH-03] Define organiser and gate-staff rules (event creation, pricing) and the Keycloak roles and permissions of each actor
- **INFO** [ARCH-04] The client is an SPA; frontend frameworks, mobile clients, data engineering and Kubernetes internals are out of scope
- **INFO** [ARCH-05] In the project, work is parallel: SPA, services and integration are built at the same time, by different people, against the same API

### Architectural constraints

- **MUST** [ARCH-06] At least three services, each owning its own database schema
- **MUST** [ARCH-07] No service reads or writes the tables of another one: interaction happens only via APIs or messages; a shared database is ruled out, and everything crossing a boundary is visible in an API or an event
- **MUST** [ARCH-08] Both stacks are used: at least one service in Kotlin/Spring Boot and one in Rust/Axum
- **MUST** [ARCH-09] The two stacks of the project express the same domain model
- **MUST** [ARCH-10] `docker compose up` starts the whole system from a clean checkout
- **MUST** [ARCH-11] Every API is documented in OpenAPI 3.1, and the document is verified against the implementation in CI
- **SHOULD** [ARCH-12] Service-to-service calls on the Kotlin side go through `@HttpExchange` interfaces, generated from the callee's OpenAPI document
- **MUST** [ARCH-13] Live seat-map updates use Server-Sent Events, the platform never needs WebSocket
- **TODO** [ARCH-14] Define how the SSE seat stream is authenticated (browser `EventSource` cannot send an `Authorization` header)
- **TODO** [ARCH-15] Define SSE reconnection and resumption (e.g. `Last-Event-ID`) when the serving replica is stopped
- **MUST** [ARCH-16] In the project, synchronous calls are used on the read and purchase path, asynchronous messages for everything after payment
- **MUST** [ARCH-17] Application replicas are stateless: no request-specific data kept between requests, no session affinity, any replica can serve any request and be stopped at any time without losing user data; state lives only in backing tiers built for it
- **INFO** [ARCH-18] In this course a replica is a container started from the service image
- **SHOULD** [ARCH-19] Large payloads (posters, seating-map bundles, ticket PDFs) live in object storage, not the database

### Required ADRs

- **MUST** [ARCH-20] The project requires six ADRs: decomposition; stack per service; overselling prevention; one synchronous vs. asynchronous choice; payment flow; one more chosen by the team
- **MUST** [ARCH-21] Every service boundary is justified by an ADR stating which keep-together/split signal justified it
- **MUST** [ARCH-22] Each service is responsible for its own API versioning strategy, recorded in an ADR
- **SHOULD** [ARCH-23] The aggregate-choice ADR (also the lock-scope choice) is "the first one reviewers read"; the reference example is ADR-003 "Hold/order aggregates with DB-enforced seat uniqueness"
- **SHOULD** [ARCH-24] ADR form: a short (one-page) document kept in the repository next to the code, with context, decision (including rejected alternatives) and consequences

### Mandated infrastructure & toolchains

- **MUST** [ARCH-25] Stack 1: Kotlin 2.3 (baseline of Spring Boot 4.1), Spring Boot 4.1, Spring Framework 7, JDK 25, Gradle with the Kotlin DSL (`build.gradle.kts`)
- **SHOULD** [ARCH-26] Stack 2: Rust stable, edition 2024, Axum 0.8, Tokio 1.53, SQLx 0.9 (course `Cargo.toml` also pins serde 1, thiserror 2, tracing 0.1)
- **SHOULD** [ARCH-27] Shared infrastructure: PostgreSQL 18, Keycloak 26.7, Redis, RabbitMQ or Kafka, RustFS (object storage), Prometheus and Grafana, run by a single course `docker-compose.yaml` enabled step by step
- **SHOULD** [ARCH-28] Rust CI runs `cargo fmt --check`, `cargo audit` and `cargo deny` (CVEs and licence policy) besides clippy `cargo clippy -D warnings`
- **INFO** [ARCH-29] Contract tooling named in the slides: springdoc-openapi (Spring), utoipa or aide (Axum), oasdiff (change classification), openapi-generator / openapi-typescript (clients)

## Topic files

- [business-rules.md](business-rules.md) — seat, order, payment and ticket-validation rules
- [service-design.md](service-design.md) — internal service structure, service layer, transactions
- [http-api.md](http-api.md) — HTTP API design & contracts, request parsing
- [operations.md](operations.md) — resilience, performance & capacity, observability, configuration
- [security.md](security.md) — authentication
- [code-style.md](code-style.md) — Kotlin/Spring and Rust/Axum code conventions, testing & CI
