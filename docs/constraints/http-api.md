# Constraints: HTTP API

Tags (**MUST**, **SHOULD**, **DOMAIN**, **INFO**, **TODO**): see [README.md](README.md).

## HTTP API design & contracts

### General

- **MUST** Every endpoint passes the six-question API review checklist: URIs name things and verb-like operations create inspectable resources; safety/idempotency respected with no state change on GET; 400/422, 401/403, 404-for-privacy, 409/412 chosen deliberately and no 500 for user errors; unsafe operations safely retryable with a defined, atomic key store; collections with cursors, clamped limit, costed totals and whitelisted sort fields; validators where useful, `no-store` for personal data, a single versioning strategy per service
- **MUST** One naming and casing convention throughout the API: camelCase properties, ISO 8601 timestamps, plural kebab-case paths
- **MUST** OpenAPI style rules enforced at project review: every operation has an `operationId`, every schema and parameter has a `description`, every response carries an `example`
- **MUST** All services use a single error format, RFC 9457 problem documents, in both stacks, and the SPA parses that single format
- **MUST** Timestamps are ISO 8601 with an explicit UTC offset (`OffsetDateTime`, e.g. `2026-09-01T21:00:00+02:00`); timestamps without offset are rejected in requests

### Resources & URIs

- **SHOULD** Plural nouns for collections, kebab-case path segments (`/seat-stream`), identifiers rather than descriptions in paths
- **SHOULD** No verbs in paths (the method is the verb, avoid `/api/getSeats`), and no state-hiding smells such as `/doHold`, `?action=cancel` or a generic `/rpc` endpoint
- **SHOULD** An operation whose result can be queried later is modelled as a resource: `POST /events/{id}/holds` creates a hold with its own URI
- **SHOULD** Consistency across the API: every collection paginates, filters and reports errors the same way
- **SHOULD** The `/api/v1` version prefix is mounted once (`nest("/api/v1", api)`), operational routes such as `/health` stay outside it
- **SHOULD** Unmatched requests get a uniform JSON 404 from a `fallback` handler; a matched path with the wrong method gets 405 with an `Allow` header, as HTTP requires
- **SHOULD** Every operation is either a command or a query, never both (CQS); safe methods such as GET correspond to queries

### Methods & status codes

- **MUST** Nothing that changes state may answer GET (a state-changing GET lets prefetchers and crawlers corrupt state); a method declared idempotent must really tolerate repetitions
- **SHOULD** `DELETE /holds/{id}` is idempotent: a repeated call returns 204 again
- **SHOULD** PUT replaces the whole representation (an omitted field is removed); PATCH uses JSON Merge Patch (RFC 7396: present fields replace, null clears); POST covers creation with server-assigned identity and everything else
- **SHOULD** Create, replace and patch all return the full resulting representation of the resource
- **SHOULD** 2xx contract: 200 with the result in the body; 201 Created with `Location` (e.g. `/api/v1/holds/98213`); 202 Accepted for deferred work with a body telling where progress is observed; 204 No Content (e.g. `DELETE /holds/{id}`)
- **SHOULD** 4xx discipline: 400 for unparseable bodies vs 422 for well-formed but invalid ones (field errors in the body); 401 missing/invalid credentials vs 403 denied; 404 instead of 403 to hide another customer's resource (IDOR); 409 for a clash with current state vs 412 for a failed precondition; 429 with `Retry-After` for rate limits
- **SHOULD** 5xx: 503 with `Retry-After` signals deliberate load shedding; returning 500 for invalid input is a bug
- **MUST** Concurrency outcomes: a hold request for a seat that is already HELD or SOLD maps to 409 Conflict; a general-admission request when capacity is exhausted means sold out, mapped to 409
- **MUST** Always prefer failing fast over waiting on a lock: for seat selection a fast 409 ("seat taken, choose another", seat map refreshed)
- **SHOULD** Spring: return a DTO (200 implied), `ResponseEntity.created(location).body(dto)` for 201, `ResponseEntity.noContent()` for 204; Axum: tuple `(StatusCode::CREATED, [(LOCATION, uri)], Json(dto))`, and a precise return type such as `Result<Json<HoldDto>, AppError>` when the contract should appear in the signature

### Idempotency

- **MUST** Unsafe operations that must be retryable (POST has none of safety, idempotency, cacheability) are made idempotent with the Idempotency-Key protocol
- **SHOULD** The client generates one unique key (a UUID) per logical operation, reuses it on every retry of that attempt, and sends it in the `Idempotency-Key` header
- **SHOULD** The server atomically checks the key: unseen → execute, store the complete response (status and body) with the key and return it; seen and finished → replay the stored response without re-executing; still running → 409 (or wait)
- **SHOULD** A request fingerprint (hash of method, URI, body) is stored with the key; a key reused with a different body is rejected with 422
- **SHOULD** Keys expire and the contract states for how long a retry is safe
- **SHOULD** Handlers bind the key as a typed header (`@RequestHeader("Idempotency-Key") key: String`)

### Caching & conditional requests

- **MUST** Reserved seating exposes optimistic versioning to clients: the row version is sent as an `ETag`, and `If-Match` on the write turns a stale update into 412 Precondition Failed
- **MUST** Holds and orders (personal data) are `no-store`
- **SHOULD** Cache policy via `Cache-Control` (`max-age=300`, `public`, `private`, `no-store`): event details cacheable for minutes, the seat map is not cacheable
- **SHOULD** Conditional reads: `If-None-Match` against the ETag answers 304 Not Modified with an empty body when unchanged
- **SHOULD** Conditional writes: `PUT … If-Match: "v42"`; if another update happened, 412 Precondition Failed and the client re-reads and reapplies its change; a successful write returns the new ETag
- **SHOULD** If an ETag is emitted, the conditional headers must be honoured

### Collections & pagination

- **MUST** Collections use cursor (keyset) pagination with a server-clamped `limit`, whitelisted filter/sort fields and a stated totals policy; no endpoint returns the whole catalogue in one response
- **SHOULD** The cursor is opaque: clients store and echo it, never parse or build it
- **SHOULD** `limit` is clamped by the server and the contract states the maximum (e.g. 500 requested, 200 served)
- **SHOULD** Collection responses use a body envelope `{"items": [...], "nextCursor": ..., "limit": ...}`. `nextCursor` is null on the last page
- **SHOULD** The contract states whether `totalCount` is exact (`COUNT(*)` per page), on request (`?include=total`), an estimate, or absent; a common compromise counts at most 1 001 rows and reports "more than 1 000"
- **SHOULD** OFFSET pagination is acceptable only for shallow navigation over small, stable data (e.g. back-office), never the public event list

### Media types & bodies

- **SHOULD** JSON (`application/json`) is the default; besides it, tickets are `application/pdf`, sales exports `text/csv`, the seat stream `text/event-stream`, errors `application/problem+json`
- **SHOULD** Accepted request bodies: JSON, form encoding (`application/x-www-form-urlencoded`, e.g. OAuth flows) and `multipart/form-data` (file uploads)
- **SHOULD** Every endpoint declares the media types it produces and consumes, recorded per operation in OpenAPI; unmatched `Accept`/`Content-Type` yields 406/415
- **SHOULD** The API is token-based and does not read cookies

### Cross-cutting headers

- **SHOULD** CORS policy is part of the API contract, enforced in the application with one central configuration per service (Spring `WebMvcConfigurer`, Axum `CorsLayer`; `@CrossOrigin` only for local exceptions): exact origins from typed configuration differing between dev and prod, methods GET/POST/PUT/PATCH/DELETE, allowed request headers `Authorization`, `Content-Type`, `Idempotency-Key`, `If-Match`, `If-None-Match`, `X-Request-Id`, exposed response headers `ETag`, `Location`, `Retry-After`, `X-Request-Id`, `Access-Control-Max-Age` to cache preflights
- **SHOULD** Under overload, admission is bounded and the excess is refused immediately with 429/503 + `Retry-After` so clients can retry with backoff

## Request parsing

### Limits before the handler

- **SHOULD** The server enforces limits before any handler runs — maximum body size, maximum number of headers, read timeouts (DoS protection)
- **SHOULD** Stack mechanisms: Spring `spring.servlet.multipart.max-file-size`/`max-request-size` plus a server-level limit; Axum `DefaultBodyLimit` (2 MB default) and `RequestBodyLimitLayer` per route (example `64 * 1024`)
- **SHOULD** Parse, don't validate: convert input once at the boundary into narrow types that only represent legal values

### Strictness policy

- **SHOULD** Strict requests, tolerant responses: the strictness policy is answered once, globally, as configuration
- **SHOULD** Unknown fields are rejected with 400/422 (`#[serde(deny_unknown_fields)]`, Jackson fail-on-unknown-properties)
- **SHOULD** No implicit coercion between JSON types (no `"42"` for an integer, no `1`/`"true"` for a boolean)
- **SHOULD** Missing, null and absent are distinct request cases (PATCH depends on it; use a presence wrapper / `Option<Option<T>>`, or offer PUT instead)
