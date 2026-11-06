# Constraints: operations

Tags (**MUST**, **SHOULD**, **DOMAIN**, **INFO**, **TODO**): see [README.md](README.md).

## Resilience

### General

- **SHOULD** Apply the five boundary patterns: timeouts, retries, circuit breakers, bulkheads, graceful degradation
- **SHOULD** Circuit breaker wraps all calls to a dependency: Closed (failures counted over a sliding window) → Open when the failure rate exceeds a threshold (calls rejected with 503 for a cool-down, without reaching the dependency) → Half-open (few probe calls; success closes, failure re-opens)
- **SHOULD** Bulkhead: each dependency gets its own resource pool (a slow PSP must not consume the threads serving the seat map); Spring `@ConcurrencyLimit` bounds concurrent outbound calls
- **SHOULD** Never rely on an unbounded queue (the worst and default option); the only sound responses to overload are bounded queues with immediate rejection (backpressure), load shedding of optional work, and timeouts
- **TODO** Define timeout, retry and circuit-breaker values, and SLO targets

## Performance and capacity

### Release-day profile

- **SHOULD** Anticipate the failure sequence (pool saturates → requests queue → latency grows → clients time out and retry → retries amplify load) with bounded queues, load shedding, admission control and waiting rooms, and an idempotent purchase path; load-test this profile
- **SHOULD** The database fails first (pool saturation, lock contention on hot seat rows); replicas multiply cheaply, the primary does not — so protect it: cache reads, queue deferrable writes, admit only what it can handle
- **SHOULD** Each tier protects the one below: "cached at the top, queued in the middle, admitted at the bottom"; a properly configured CDN absorbs static/cacheable reads and fails last

### Latency
- **SHOULD** Report latency as percentiles (p50, p95, p99), never as a mean alone; dashboards based on means are not trusted; state testable targets (e.g. "p99 below 200 ms at 5 000 req/s")
- **SHOULD** Measure connection setup (DNS, TCP, TLS) before blaming application code; reuse keep-alive connections; HTTP/2 browser↔proxy, HTTP/1.1 proxy↔application
- **INFO** Indicative hold-request budget: warm connection ~15–60 ms (middleware + handler ~5–15 ms, SQL + pool ~5–30 ms, serialise ~1–15 ms); on release day the pool queue feels the spike first

## Observability

### Correlation / request IDs

- **SHOULD** Every request gets a correlation id (`X-Request-Id`, reusing the caller's or a new UUID) by the outermost middleware, before tracing, returned on the response, and attached to every log record and to error responses (header or `instance`)
- **SHOULD** Spring: request-id filter extends `OncePerRequestFilter`, is registered early (before the security chain), puts the id in MDC and removes it in `finally` (pooled threads); coroutines need `MDCContext`
- **SHOULD** Axum layer order: `SetRequestIdLayer` outermost, `TraceLayer` (one span per request carrying the id), `TimeoutLayer` inside tracing so cancelled requests stay visible, `PropagateRequestIdLayer` on the way out; for each adjacent pair it must be clear what swapping would lose

### Logs
- **SHOULD** Logs go to stdout as structured JSON with correlation identifiers
- **SHOULD** Log levels: DEBUG expected events, INFO notable-normal, WARN suspicious, ERROR only when an operator must act (ERROR is an alerting budget)
- **SHOULD** Bugs/panics/uncaught exceptions: ERROR log with full trace and correlation id inside, only the class outside (Spring catch-all `@ExceptionHandler(Exception::class)`; Axum `CatchPanicLayer`); database causes logged with `tracing::error!` and hidden from the body

### Health endpoints
- **SHOULD** Liveness answers "restart the process?" (false on deadlock/corrupt state) and never checks the database; readiness answers "send traffic?" (false while starting, draining, or a critical dependency is down) and only removes the replica from load balancing
- **SHOULD** Spring: enable probes (`management.endpoint.health.probes.enabled=true` → `/actuator/health/liveness`, `/actuator/health/readiness`); the DB indicator belongs to readiness only
- **SHOULD** A replica becomes ready in seconds; one still migrating is alive but not ready

## Configuration

- **SHOULD** Configuration is externalised, typed, validated and fail-fast: an invalid value stops the boot naming the offending key, before the pool is created and the listener bound (e.g. a wrong hold TTL must stop the deployment, not produce anomalous holds at the peak)
- **SHOULD** Spring: `@ConfigurationProperties(prefix = "tickets")` + `@Validated` with Jakarta constraints, cross-field rules in `init { require(...) }`, discovered by `@ConfigurationPropertiesScan`
- **SHOULD** Rust: figment merges committed `config/default.toml` with `Env::prefixed("TICKETS_").split("__")` (`TICKETS_HOLD_TTL` → `hold_ttl`); `validate()` right after `extract()`; `TicketingConfig::load()?` in `main`
- **SHOULD** Profiles (`dev`, `test`, `prod`) are activated from outside via `SPRING_PROFILES_ACTIVE`, never hard-coded; precedence: command line > env vars > profile YAML > `application.yaml`; relaxed binding lets Compose/Kubernetes `environment:` configure the app without changing the image
- **SHOULD** One build artefact serves every environment; every environment-specific value comes from outside it
- **INFO** Operational values such as hold TTL, per-customer hold limit, idempotency-key retention and maximum pagination `limit` are defined in configuration, not in these requirements
