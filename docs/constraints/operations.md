# Constraints: operations

Tags (**MUST**, **SHOULD**, **DOMAIN**, **INFO**, **TODO**): see [README.md](README.md).

## Resilience

### General

- **SHOULD** [OPS-01] Apply the five boundary patterns: timeouts, retries, circuit breakers, bulkheads, graceful degradation
- **SHOULD** [OPS-02] Circuit breaker wraps all calls to a dependency: Closed (failures counted over a sliding window) → Open when the failure rate exceeds a threshold (calls rejected with 503 for a cool-down, without reaching the dependency) → Half-open (few probe calls; success closes, failure re-opens)
- **SHOULD** [OPS-03] Bulkhead: each dependency gets its own resource pool (a slow PSP must not consume the threads serving the seat map); Spring `@ConcurrencyLimit` bounds concurrent outbound calls
- **SHOULD** [OPS-04] Never rely on an unbounded queue (the worst and default option); the only sound responses to overload are bounded queues with immediate rejection (backpressure), load shedding of optional work, and timeouts
- **TODO** [OPS-05] Define timeout, retry and circuit-breaker values, and SLO targets

## Performance and capacity

### Release-day profile

- **SHOULD** [OPS-06] Anticipate the failure sequence (pool saturates → requests queue → latency grows → clients time out and retry → retries amplify load) with bounded queues, load shedding, admission control and waiting rooms, and an idempotent purchase path; load-test this profile
- **SHOULD** [OPS-07] The database fails first (pool saturation, lock contention on hot seat rows); replicas multiply cheaply, the primary does not — so protect it: cache reads, queue deferrable writes, admit only what it can handle
- **SHOULD** [OPS-08] Each tier protects the one below: "cached at the top, queued in the middle, admitted at the bottom"; a properly configured CDN absorbs static/cacheable reads and fails last

### Latency
- **SHOULD** [OPS-09] Report latency as percentiles (p50, p95, p99), never as a mean alone; dashboards based on means are not trusted; state testable targets (e.g. "p99 below 200 ms at 5 000 req/s")
- **SHOULD** [OPS-10] Measure connection setup (DNS, TCP, TLS) before blaming application code; reuse keep-alive connections; HTTP/2 browser↔proxy, HTTP/1.1 proxy↔application
- **INFO** [OPS-11] Indicative hold-request budget: warm connection ~15–60 ms (middleware + handler ~5–15 ms, SQL + pool ~5–30 ms, serialise ~1–15 ms); on release day the pool queue feels the spike first

## Observability

### Correlation / request IDs

- **SHOULD** [OPS-12] Every request gets a correlation id (`X-Request-Id`, reusing the caller's or a new UUID) by the outermost middleware, before tracing, returned on the response, and attached to every log record and to error responses (header or `instance`)
- **SHOULD** [OPS-13] Spring: request-id filter extends `OncePerRequestFilter`, is registered early (before the security chain), puts the id in MDC and removes it in `finally` (pooled threads); coroutines need `MDCContext`
- **SHOULD** [OPS-14] Axum layer order: `SetRequestIdLayer` outermost, `TraceLayer` (one span per request carrying the id), `TimeoutLayer` inside tracing so cancelled requests stay visible, `PropagateRequestIdLayer` on the way out; for each adjacent pair it must be clear what swapping would lose

### Logs
- **SHOULD** [OPS-15] Logs go to stdout as structured JSON with correlation identifiers
- **SHOULD** [OPS-16] Log levels: DEBUG expected events, INFO notable-normal, WARN suspicious, ERROR only when an operator must act (ERROR is an alerting budget)
- **SHOULD** [OPS-17] Bugs/panics/uncaught exceptions: ERROR log with full trace and correlation id inside, only the class outside (Spring catch-all `@ExceptionHandler(Exception::class)`; Axum `CatchPanicLayer`); database causes logged with `tracing::error!` and hidden from the body

### Health endpoints
- **SHOULD** [OPS-18] Liveness answers "restart the process?" (false on deadlock/corrupt state) and never checks the database; readiness answers "send traffic?" (false while starting, draining, or a critical dependency is down) and only removes the replica from load balancing
- **SHOULD** [OPS-19] Spring: enable probes (`management.endpoint.health.probes.enabled=true` → `/actuator/health/liveness`, `/actuator/health/readiness`); the DB indicator belongs to readiness only
- **SHOULD** [OPS-20] A replica becomes ready in seconds; one still migrating is alive but not ready

## Configuration

- **SHOULD** [OPS-21] Configuration is externalised, typed, validated and fail-fast: an invalid value stops the boot naming the offending key, before the pool is created and the listener bound (e.g. a wrong hold TTL must stop the deployment, not produce anomalous holds at the peak)
- **SHOULD** [OPS-22] Spring: `@ConfigurationProperties(prefix = "tickets")` + `@Validated` with Jakarta constraints, cross-field rules in `init { require(...) }`, discovered by `@ConfigurationPropertiesScan`
- **SHOULD** [OPS-23] Rust: figment merges committed `config/default.toml` with `Env::prefixed("TICKETS_").split("__")` (`TICKETS_HOLD_TTL` → `hold_ttl`); `validate()` right after `extract()`; `TicketingConfig::load()?` in `main`
- **SHOULD** [OPS-24] Profiles (`dev`, `test`, `prod`) are activated from outside via `SPRING_PROFILES_ACTIVE`, never hard-coded; precedence: command line > env vars > profile YAML > `application.yaml`; relaxed binding lets Compose/Kubernetes `environment:` configure the app without changing the image
- **SHOULD** [OPS-25] One build artefact serves every environment; every environment-specific value comes from outside it
- **INFO** [OPS-26] Operational values such as hold TTL, per-customer hold limit, idempotency-key retention and maximum pagination `limit` are defined in configuration, not in these requirements
