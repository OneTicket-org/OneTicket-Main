# Constraints: code style & testing

Tags (**MUST**, **SHOULD**, **DOMAIN**, **INFO**, **TODO**): see [README.md](README.md). Rules already stated elsewhere are not repeated here; related IDs are cited inline.

## Kotlin / Spring Boot

### Build

- **MUST** [STY-01] Every Spring Boot service is written in Kotlin and applies `kotlin("plugin.spring")` (all-open): final classes cannot be proxied, so `@Transactional`, `@Configuration` and `@Async` fail at start-up or silently do nothing
- **SHOULD** [STY-02] `build.gradle.kts` applies `kotlin("jvm")`, `kotlin("plugin.spring")`, `kotlin("plugin.jpa")` 2.3.0 (no-arg constructor for every `@Entity`), `org.springframework.boot` 4.1.0, `io.spring.dependency-management` 1.1.7, and pins JDK 25 ([ARCH-25]) with `kotlin { jvmToolchain(25) }`
- **SHOULD** [STY-03] Every capability used appears as an explicit starter (Boot 4 no longer brings auto-configuration transitively), e.g. `spring-boot-starter-webmvc`, `spring-boot-starter-validation`, `tools.jackson.module:jackson-module-kotlin`, `kotlinx-coroutines-reactor`; the build file is the SBOM inventory

### Kotlin idioms

- **SHOULD** [STY-04] No `!!`: use an explicit `?:` decision or a type that removes the question
- **SHOULD** [STY-05] Platform types from unannotated Java are assigned to an explicit `T` or `T?` at the Java boundary
- **SHOULD** [STY-06] At most one scope function per expression (no nested `let`/`apply`/`run`); accepted uses: `x?.let { … }` to transform only when present, `.also { … }` for a side effect in a chain

### Dependency injection

- **SHOULD** [STY-07] Constructor injection only, dependencies as immutable `val`s (a single primary constructor needs no annotation); no field injection (`@Autowired lateinit var`); setter injection only for rare optional collaborators, preferably a constructor parameter with a default
- **SHOULD** [STY-08] Use the stereotype stating the real role: `@Component` (generic), `@Service` (service layer), `@Repository` (data access, translates persistence exceptions), `@RestController` (HTTP; `@Controller` alone is not used)
- **SHOULD** [STY-09] Resolve ambiguous injection in this order: narrower type, `@Primary` on the default candidate, `@Qualifier("name")`
- **SHOULD** [STY-10] Library objects (`Clock`, HTTP client, connection pool) are `@Bean` methods in a `@Configuration` class, with their parameters injected
- **SHOULD** [STY-11] `@PostConstruct` only for light initialisation, `@PreDestroy` for resource release
- **SHOULD** [STY-12] Configuration ([OPS-22]) binds onto immutable Kotlin classes, one per concern, injected as typed classes (e.g. `TicketingProps`); no scattered `@Value("${…}")`

### Web layer & Jackson

- **SHOULD** [STY-13] Pipeline placement: filter chain for protocol-level concerns and security, interceptors for logic depending on the handler, argument resolvers (`@PathVariable`, `@RequestParam`, `@RequestBody`), `HttpMessageConverter` (Jackson), `@ControllerAdvice` for exceptions
- **SHOULD** [STY-14] The request-id filter ([OPS-13]) also sets the `X-Request-Id` response header, and an interceptor copies the id onto `RestClient` calls
- **SHOULD** [STY-15] Jackson 3 packages are `tools.jackson.*` (not `com.fasterxml.jackson.*`); register the Kotlin and java.time modules and handle (unchecked) serialisation failures in one place
- **SHOULD** [STY-16] Service-wide Jackson policy lives in properties, set once on the shared mapper (`spring.jackson.default-property-inclusion=non_null`, naming strategy, fail-on-unknown-properties, no type coercion; see [API-51], [API-52]); `@JsonProperty`, `@JsonInclude`, `@JsonIgnore`, `@JsonFormat` only for local exceptions
- **SHOULD** [STY-17] Requiredness comes from Kotlin types: non-nullable `seat: String` is required, `quantity: Int = 1` is optional
- **SHOULD** [STY-18] PATCH DTOs use `JsonNullable<T>` (default `JsonNullable.undefined()`) to distinguish absent / null / value ([API-53])
- **SHOULD** [STY-19] Polymorphic payloads: sealed hierarchy with `@JsonTypeInfo(use = NAME, property = "type")` and one `@JsonSubTypes` entry per variant; enum wire names fixed with `@JsonProperty`
- **SHOULD** [STY-20] Syntactic validation with `@field:NotBlank`, `@field:Size(max = …)`, `@field:Min`/`@field:Max` on DTO fields, `@field:Valid` on nested objects, `@Valid` on `@RequestBody`; the advice overrides `handleMethodArgumentNotValid` to map `fieldErrors` to `{field, code, detail}`
- **SHOULD** [STY-21] Newtypes are `@JvmInline value class` with `init { require(…) }` and a `@JsonCreator` constructor, so Jackson goes through the same validation
- **SHOULD** [STY-22] Set `spring.threads.virtual.enabled=true` and `spring.mvc.problemdetails.enabled=true`; small direct uploads (e.g. the poster) use `MultipartFile`, capped per [API-48]
- **SHOULD** [STY-23] Streaming responses return `StreamingResponseBody`, reading rows with a scrolling result, a bounded JDBC fetch size or a `Stream` return type
- **SHOULD** [STY-24] API versioning ([ARCH-22]) via `WebMvcConfigurer.configureApiVersioning(...)` (`useRequestHeader`, `addSupportedVersions`, `setDefaultVersion`) and the `version` attribute of mappings
- **SHOULD** [STY-25] Actuator keys: `management.endpoints.web.exposure.include`, `management.endpoint.health.probes.enabled`, `management.endpoint.health.show-details`

### Concurrency model

- **SHOULD** [STY-26] Spring MVC on virtual threads: plain blocking code when the handler is sequential, coroutines (suspending controllers) when it splits into concurrent children sharing one lifetime
- **SHOULD** [STY-27] Check that virtual threads do not pin (blocking inside `synchronized` or a native call); they fix I/O-wait exhaustion, not CPU-bound overload
- **SHOULD** [STY-28] No WebFlux/Reactor for a JSON-over-SQL service; only for streaming pipelines, extreme fan-out or explicit backpressure

### Errors & outbound clients

- **SHOULD** [STY-29] One `@RestControllerAdvice` extending `ResponseEntityExceptionHandler` holds every `@ExceptionHandler`; bodies are built with `ProblemDetail.forStatusAndDetail(...)`, setting `type`, `title` and the stable `code` via `setProperty("code", …)`; `ErrorResponseException` may carry a full `ProblemDetail`
- **SHOULD** [STY-30] `@HttpExchange` clients ([ARCH-12]) are registered with `@ImportHttpServices`, one configured `RestClient` per group, generated with openapi-generator (Kotlin)
- **SHOULD** [STY-31] Retries use Spring Framework 7's built-in `@Retryable` (not spring-retry): retryable exceptions, max attempts, exponential backoff with jitter, idempotent calls only, placed on the service method and never inside the transaction it restarts; `@ConcurrencyLimit` as bulkhead ([OPS-03]); timeouts on the HTTP client and the pool; values are typed configuration ([OPS-05])

### Service layer & transactions

- **SHOULD** [STY-32] A use case is a `@Service` class with constructor-injected ports (`HoldRepository`, `EventPublisher`), a `Clock` and `TicketingProps`, with `@Transactional` on the use-case method; when boundaries are decided at run time use `TransactionTemplate` (traps: [SVC-19])

### Persistence & migrations

- **SHOULD** [STY-33] Persistence uses JPA/Hibernate
- **SHOULD** [STY-34] Hikari: `maximum-pool-size` 25 and `minimum-idle` 25 (global budget of 100 connections / 4 replicas), `connection-timeout` 1000 ms (fail fast → 503), `max-lifetime` 1800000 ms, `leak-detection-threshold` 30000 ms
- **SHOULD** [STY-35] `spring.jpa.open-in-view=false`; entities are plain classes (not data classes) with `var` fields and primary-key-based `equals`/`hashCode`
- **SHOULD** [STY-36] A lazy relation read inside a list mapping is an N+1 defect: read-only lists use a JPQL DTO projection (`SELECT new EventCardDto(…)`), `JOIN FETCH` only for entities to be modified (at most one collection per query), `@BatchSize(50)` as a pragmatic fix for existing code; bulk writes use JDBC batching
- **SHOULD** [STY-37] Optimistic versioning with `@Version` ([API-29]); a stale flush raises `OptimisticLockingFailureException`
- **SHOULD** [STY-38] Flyway: versioned `V<n>__<description>.sql`, repeatable `R__<name>.sql`; Flyway runs before JPA at boot; `spring.jpa.hibernate.ddl-auto=validate` in production, `update`/`create` banned

### OpenAPI

- **SHOULD** [STY-39] springdoc-openapi: `@Operation(operationId = "…")` and one `@ApiResponse` per status (e.g. `409` with `ProblemDetail`); document at `/v3/api-docs`, UI at `/swagger-ui.html`

## Rust / Axum

### Workspace

- **SHOULD** [STY-40] Rust services live in one Cargo workspace with a committed `Cargo.lock`, dependency versions ([ARCH-26]) in `[workspace.dependencies]`, and `rust-toolchain.toml` pinning the compiler

### Language conventions

- **SHOULD** [STY-41] Kotlin→Rust modelling: `data class` → `struct` with `#[derive(Debug, Clone, PartialEq)]`; `sealed interface` + `when` → enum with data + exhaustive `match`; `T?` → `Option<T>`; exceptions → `Result<T, E>`; composition and traits instead of inheritance
- **SHOULD** [STY-42] No `unwrap()`/`expect()` in request-path code outside tests, enforced by a clippy lint in CI
- **SHOULD** [STY-43] Explicit lifetime parameters only in generic library code; `Send`/`Sync` are never implemented by hand

### Async & Tokio

- **SHOULD** [STY-44] No synchronous I/O (`std::fs::read`) or CPU-heavy work (bcrypt/argon2, image resizing) inside an `async fn`: use `tokio::fs` and `tokio::task::spawn_blocking`; `tokio::spawn` for cheap waiting tasks such as the hold-expiry sweeper
- **SHOULD** [STY-45] Shared state is an `Arc<AppState>` (immutable or internally synchronised), an `Arc` clone moved into each task
- **SHOULD** [STY-46] Never hold a `std::sync::MutexGuard` across `.await` (release it in an explicit block); `std::sync::Mutex` for short sections, `tokio::sync::Mutex` only when a section must span an await, which signals a design to reconsider (narrow the section or use an actor)

### Routing, state & middleware

- **SHOULD** [STY-47] `#[tokio::main] async fn main() -> anyhow::Result<()>` loads config, applies migrations (`sqlx::migrate!()` embedded in the binary), builds state and calls `axum::serve(listener, app)` on a `Router<()>`, with a `CancellationToken` for shutdown; the router is assembled in `lib.rs` so integration tests import it
- **SHOULD** [STY-48] `FromRef` lets handlers take only the part of state they need (e.g. `State<PgPool>`); `State<S>` for wiring built once in `main`, `Extension<T>` for request-scoped values set by middleware (a missing `Extension` is a run-time 500)
- **SHOULD** [STY-49] Use `#[debug_handler]` first whenever a route line does not compile
- **SHOULD** [STY-50] Layers are composed in `ServiceBuilder`, first listed = outermost: `SetRequestIdLayer` → `TraceLayer` → `TimeoutLayer` → `CorsLayer` → compression → `RequestBodyLimitLayer` → `PropagateRequestIdLayer` (rationale: [OPS-14])
- **SHOULD** [STY-51] `.layer(...)` for global layers (including the fallback), `.route_layer(...)` for auth on registered routes only; `middleware::from_fn` unless the middleware has its own configuration (then a full `Layer`)
- **SHOULD** [STY-52] Request context: middleware puts values in request extensions, a typed `CurrentUser`/`RequestContext` extractor hands them to handlers, and reqwest middleware adds the correlation header from the current span

### Extractors, serde & validation

- **SHOULD** [STY-53] Use the built-in extractors (`Path`, `Query`, `Json`, `Form`, `State`, `Extension`, `Multipart`); custom extractors implement `FromRequestParts`/`FromRequest` with `Rejection = AppError`
- **SHOULD** [STY-54] DTOs derive `Deserialize` + `Validate` with `#[serde(rename_all = "camelCase", deny_unknown_fields)]` on every DTO (there is no global mapper) and `#[validate(length(...))]`/`#[validate(range(...))]`; a `ValidatedJson<T>` extractor parses then calls `validate()`, so handlers receive only validated values
- **SHOULD** [STY-55] Requiredness from types: `seat: String` (missing ⇒ 422 at parse), `#[serde(default = "one")]` for an absent `quantity`, unsigned types make negatives unrepresentable
- **SHOULD** [STY-56] PATCH uses `Option<Option<T>>` with `#[serde(default, with = "serde_with::rust::double_option")]`; polymorphic payloads use `#[serde(tag = "type")]`; enum wire names via `#[serde(rename_all)]`
- **SHOULD** [STY-57] Newtypes have a private field, `TryFrom`, and `#[serde(try_from = "String")]`, so parsing and validation are one step
- **SHOULD** [STY-58] Durations in configuration ([OPS-23]) use `humantime_serde`

### Errors

- **SHOULD** [STY-59] `AppError` is a `thiserror` enum with one variant per failure class; a single `impl IntoResponse for AppError` chooses status and code, logs at the class's level and serialises `application/problem+json`
- **SHOULD** [STY-60] `TimeoutLayer` + `HandleErrorLayer` produce a problem document on timeout; retries are a retry layer with a budget; attempts, delays and budgets are typed configuration ([OPS-05])
- **SHOULD** [STY-61] Unique violations map via `sqlx::Error::Database(db)` + `db.is_unique_violation()` to a domain error (e.g. `AppError::SeatTaken`)

### Service layer & wiring

- **SHOULD** [STY-62] Services hold trait objects (`Arc<dyn HoldRepository>`, `Arc<dyn EventPublisher>`, `Arc<dyn Clock>`, `Arc<TicketingConfig>`) rather than generic parameters, wired by hand in `main` (no container; a missing dependency is a compile error)
- **SHOULD** [STY-63] Cross-cutting behaviour is an explicit wrapper struct forwarding calls, or a Tower layer

### Persistence with sqlx

- **SHOULD** [STY-64] `query!`/`query_as!` checked at compile time; runtime `query_as::<_, T>` + `FromRow` only for dynamic SQL that cannot be checked statically
- **SHOULD** [STY-65] Pool: `max_connections(25)` (same global budget as [STY-34]), `acquire_timeout(1 s)`, `max_lifetime(1800 s)`
- **SHOULD** [STY-66] Publish events after `tx.commit()` (transaction rules: [SVC-18])
- **SHOULD** [STY-67] Optimistic updates put the version check in the `WHERE` clause and check the affected-row count
- **SHOULD** [STY-68] Avoid N+1 by batching (collect the page's keys, one `WHERE id IN (...)`, join in memory); bulk insert with `UNNEST` over bound arrays; stream with `fetch()` in constant memory (`Body::from_stream` for CSV; client disconnect cancels the query)
- **SHOULD** [STY-69] Migrations are named like `0007_add_holds.sql`; concurrent replicas are coordinated by sqlx's PostgreSQL advisory lock

### OpenAPI

- **SHOULD** [STY-70] utoipa: `#[derive(ToSchema)]` on DTOs and `#[utoipa::path(...)]` on handlers (e.g. `201` → `HoldDto`, `409` → `Problem`); UI via `utoipa-swagger-ui`

## Both stacks

- **SHOULD** [STY-71] The keyset cursor ([API-36]) is `base64("${startsAt}|${id}")`

## Testing & CI

### Review-checked

- **MUST** [STY-72] An automated concurrency test issuing many simultaneous purchases of one seat shows no overselling ([BIZ-01]); checked at every milestone review
- **MUST** [STY-73] The OpenAPI document ([ARCH-11]) is committed and the build fails whenever running code disagrees with it; springdoc/utoipa annotations alone do not prove behaviour
- **MUST** [STY-74] Milestone 3: one feature working end to end across two services in two stacks, with tests passing in CI
- **MUST** [STY-75] `cargo clippy -D warnings` passes in CI
- **SHOULD** [STY-76] Tests run at several levels (unit, integration with a real database, API contract, load), all in CI on every change

### Contract checks

- **SHOULD** [STY-77] On every pull request the contract gate: generate the document (or fetch `/v3/api-docs`); diff against the committed one (any difference fails); classify with oasdiff (additive passes, breaking fails unless accompanied by a version bump and deprecation plan); regenerate and compile the SPA TypeScript client and the cross-service Kotlin client
- **SHOULD** [STY-78] Contract tests start the real service and verify it behaves as the document states; semantics (units, ordering) still need human review
- **SHOULD** [STY-79] Error `code` values never change (changing or removing one is breaking) and are covered by the contract checks

### Unit tests

- **SHOULD** [STY-80] Services ([SVC-16]) are built with a plain constructor call, no Spring; fakes are hand-written (`InMemoryHoldRepository`, `RecordingPublisher`; in Rust over `Mutex<HashMap>` behind `Arc<dyn Trait>`)
- **SHOULD** [STY-81] Expiry is tested at boundary times with a fixed clock ([SVC-15]): alive at ttl − 1 s, not active at ttl + 1 s
- **SHOULD** [STY-82] Arrange-Act-Assert: JUnit 5 `@Test` + AssertJ `assertThat` (or Kotest) on the JVM; `#[test]`/`#[tokio::test]` + `assert_eq!`/`assert!` in Rust
- **SHOULD** [STY-83] One test per failure class checks status, format and absence of leaks

### Concurrency tests

- **SHOULD** [STY-84] Check-then-act rules need concurrency-specific tests (one-request-at-a-time suites cannot reproduce the race); transaction boundaries are verified by tests

### Persistence tests

- **SHOULD** [STY-85] The real adapter is tested against an empty PostgreSQL started with Testcontainers, applying the migration chain from version zero, so dev, CI and production schemas are identical
- **SHOULD** [STY-86] N+1 is caught by a query-count regression test in CI: reset the counter (Hibernate Statistics / datasource proxy; sqlx statement log), call the endpoint once over HTTP, assert at most 2 statements for the event list
- **SHOULD** [STY-87] sqlx CI needs no live database: commit `cargo sqlx prepare` metadata and build with `SQLX_OFFLINE=true`

### Load tests

- **SHOULD** [STY-88] Blocking-call faults are invisible at low concurrency and are tested under production-level load; avoid closed-loop load generators (coordinated omission); latency targets per [OPS-09]
