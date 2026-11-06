# Constraints: service design

Tags (**MUST**, **SHOULD**, **DOMAIN**, **INFO**, **TODO**): see [README.md](README.md).

## Internal structure of a service

### Layering

- **SHOULD** [SVC-01] Layer each service as transport -> framework -> middleware -> handler -> application service -> data access -> local db
- **SHOULD** [SVC-02] Handlers are thin: they bind input, call the service and build the response — no business rules, no SQL
- **SHOULD** [SVC-03] Application services contain no HTTP concepts
- **SHOULD** [SVC-04] Business rules are written once in the service and reused by all entrypoints
- **SHOULD** [SVC-05] Repositories take no domain decisions and accept/return domain objects only (never `ResultSet`, `Row` or JPA entity)
- **SHOULD** [SVC-06] Keep three type families — wire DTOs (versioned with the API), domain types, persistence types — with plain mapper functions
- **SHOULD** [SVC-07] Services receive collaborators already built (Spring container injection; Rust construction in `main` shared via `Arc`); neither creates a repository nor reads the system clock
- **SHOULD** [SVC-08] Enforce the dependency rule in the build: ArchUnit/Konsist on the JVM (e.g. "no class in ..service.. may depend on org.springframework.web..", a service importing `jakarta.persistence` breaks the build); in Rust, `pub(crate)` visibility plus clippy, or workspace crates whose domain `Cargo.toml` lists neither axum nor sqlx

## Service layer

### Domain model, invariants and aggregates

- **SHOULD** [SVC-09] Avoid an anaemic model: single-object invariants belong on the entity (`hold.isActive(clock)`, `order.cancel(now)`), while rules spanning several objects or needing ports (per-customer hold limit) stay in the service
- **SHOULD** [SVC-10] Domain objects and services accept only precise types (newtypes with smart constructors: `SeatId`, `Quantity`, `Email`); the DTO->domain mapper parses loose DTO types into them, and value objects are used in all signatures
- **SHOULD** [SVC-11] Domain types enforce invariants and know nothing about JSON or SQL
- **SHOULD** [SVC-12] Aggregates are small and reference each other by identifier; invariants inside one aggregate are enforced in one transaction, only eventual consistency (events) holds between aggregates, and ideally a transaction touches a single aggregate

### Ports, adapters and repositories

- **SHOULD** [SVC-13] The core defines ports in domain terms (`HoldRepository`, `EventPublisher`, `Clock`, `PaymentGateway`), and technology-specific adapters (`PgHoldRepository`, broker publisher, in-memory fake) implement them; dependencies point inwards
- **SHOULD** [SVC-14] Repository methods are named after domain questions (`findActiveBy(customer)`, `seatPage(event, cursor)`) and still make sense if the UI were replaced; avoid derived-name chains and one-method-per-screen
- **SHOULD** [SVC-15] Time and identifiers are injected ports: a `Clock` bean (`Clock.systemUTC()` in production, `Clock.fixed(…)`/`FixedClock` in tests) and an id generator, so expiry is tested deterministically at the deadline and ±1 s; never `Instant.now()`/`Uuid::new_v4()` inside a service
- **SHOULD** [SVC-16] Services are unit-tested with hand-written fakes of ports (e.g. `InMemoryHoldRepository`), with no server and no database; the real adapter is tested against real PostgreSQL

## Transactions

### Implementation

- **SHOULD** [SVC-17] Prefer `FOR NO KEY UPDATE` over `FOR UPDATE` when key columns are not updated
- **SHOULD** [SVC-18] In Rust, the service opens `pool.begin()` and repositories take `&mut Transaction` (never `&PgPool`), so they cannot open their own; `tx.commit()` is the only path that persists, and any early return, `?` or cancellation drops the value and rolls back
- **SHOULD** [SVC-19] Keep in mind the `@Transactional` traps: self-invocation bypasses the proxy (put the boundary on another bean's method); checked exceptions commit by default (declare `rollbackFor`); without `@Transactional` each repository call commits alone, reproducing the lost update; never call the PSP inside the transaction
