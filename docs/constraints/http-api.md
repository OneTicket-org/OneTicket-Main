# Constraints: HTTP API

Tags (**MUST**, **SHOULD**, **DOMAIN**, **INFO**, **TODO**): see [README.md](README.md).

## HTTP API design & contracts

### General

- **MUST** [API-01] Every endpoint passes the six-question API review checklist: URIs name things and verb-like operations create inspectable resources; safety/idempotency respected with no state change on GET; 400/422, 401/403, 404-for-privacy, 409/412 chosen deliberately and no 500 for user errors; unsafe operations safely retryable with a defined, atomic key store; collections with cursors, clamped limit, costed totals and whitelisted sort fields; validators where useful, `no-store` for personal data, a single versioning strategy per service
- **MUST** [API-02] One naming and casing convention throughout the API: camelCase properties, ISO 8601 timestamps, plural kebab-case paths
- **MUST** [API-03] OpenAPI style rules enforced at project review: every operation has an `operationId`, every schema and parameter has a `description`, every response carries an `example`
- **MUST** [API-04] All services use a single error format, RFC 9457 problem documents, in both stacks, and the SPA parses that single format
- **MUST** [API-05] Timestamps are ISO 8601 with an explicit UTC offset (`OffsetDateTime`, e.g. `2026-09-01T21:00:00+02:00`); timestamps without offset are rejected in requests

### Resources & URIs

- **SHOULD** [API-06] Plural nouns for collections, kebab-case path segments (`/seat-stream`), identifiers rather than descriptions in paths
- **SHOULD** [API-07] No verbs in paths (the method is the verb, avoid `/api/getSeats`), and no state-hiding smells such as `/doHold`, `?action=cancel` or a generic `/rpc` endpoint
- **SHOULD** [API-08] An operation whose result can be queried later is modelled as a resource: `POST /events/{id}/holds` creates a hold with its own URI
- **SHOULD** [API-09] Consistency across the API: every collection paginates, filters and reports errors the same way
- **SHOULD** [API-10] The `/api/v1` version prefix is mounted once (`nest("/api/v1", api)`), operational routes such as `/health` stay outside it
- **SHOULD** [API-11] Unmatched requests get a uniform JSON 404 from a `fallback` handler; a matched path with the wrong method gets 405 with an `Allow` header, as HTTP requires
- **SHOULD** [API-12] Every operation is either a command or a query, never both (CQS); safe methods such as GET correspond to queries

### Methods & status codes

- **MUST** [API-13] Nothing that changes state may answer GET (a state-changing GET lets prefetchers and crawlers corrupt state); a method declared idempotent must really tolerate repetitions
- **SHOULD** [API-14] `DELETE /holds/{id}` is idempotent: a repeated call returns 204 again
- **SHOULD** [API-15] PUT replaces the whole representation (an omitted field is removed); PATCH uses JSON Merge Patch (RFC 7396: present fields replace, null clears); POST covers creation with server-assigned identity and everything else
- **SHOULD** [API-16] Create, replace and patch all return the full resulting representation of the resource
- **SHOULD** [API-17] 2xx contract: 200 with the result in the body; 201 Created with `Location` (e.g. `/api/v1/holds/98213`); 202 Accepted for deferred work with a body telling where progress is observed; 204 No Content (e.g. `DELETE /holds/{id}`)
- **SHOULD** [API-18] 4xx discipline: 400 for unparseable bodies vs 422 for well-formed but invalid ones (field errors in the body); 401 missing/invalid credentials vs 403 denied; 404 instead of 403 to hide another customer's resource (IDOR); 409 for a clash with current state vs 412 for a failed precondition; 429 with `Retry-After` for rate limits
- **SHOULD** [API-19] 5xx: 503 with `Retry-After` signals deliberate load shedding; returning 500 for invalid input is a bug
- **MUST** [API-20] Concurrency outcomes: a hold request for a seat that is already HELD or SOLD maps to 409 Conflict; a general-admission request when capacity is exhausted means sold out, mapped to 409
- **MUST** [API-21] Always prefer failing fast over waiting on a lock: for seat selection a fast 409 ("seat taken, choose another", seat map refreshed)
- **SHOULD** [API-22] Spring: return a DTO (200 implied), `ResponseEntity.created(location).body(dto)` for 201, `ResponseEntity.noContent()` for 204; Axum: tuple `(StatusCode::CREATED, [(LOCATION, uri)], Json(dto))`, and a precise return type such as `Result<Json<HoldDto>, AppError>` when the contract should appear in the signature

### Idempotency

- **MUST** [API-23] Unsafe operations that must be retryable (POST has none of safety, idempotency, cacheability) are made idempotent with the Idempotency-Key protocol
- **SHOULD** [API-24] The client generates one unique key (a UUID) per logical operation, reuses it on every retry of that attempt, and sends it in the `Idempotency-Key` header
- **SHOULD** [API-25] The server atomically checks the key: unseen → execute, store the complete response (status and body) with the key and return it; seen and finished → replay the stored response without re-executing; still running → 409 (or wait)
- **SHOULD** [API-26] A request fingerprint (hash of method, URI, body) is stored with the key; a key reused with a different body is rejected with 422
- **SHOULD** [API-27] Keys expire and the contract states for how long a retry is safe
- **SHOULD** [API-28] Handlers bind the key as a typed header (`@RequestHeader("Idempotency-Key") key: String`)

### Caching & conditional requests

- **MUST** [API-29] Reserved seating exposes optimistic versioning to clients: the row version is sent as an `ETag`, and `If-Match` on the write turns a stale update into 412 Precondition Failed
- **MUST** [API-30] Holds and orders (personal data) are `no-store`
- **SHOULD** [API-31] Cache policy via `Cache-Control` (`max-age=300`, `public`, `private`, `no-store`): event details cacheable for minutes, the seat map is not cacheable
- **SHOULD** [API-32] Conditional reads: `If-None-Match` against the ETag answers 304 Not Modified with an empty body when unchanged
- **SHOULD** [API-33] Conditional writes: `PUT … If-Match: "v42"`; if another update happened, 412 Precondition Failed and the client re-reads and reapplies its change; a successful write returns the new ETag
- **SHOULD** [API-34] If an ETag is emitted, the conditional headers must be honoured

### Collections & pagination

- **MUST** [API-35] Collections use cursor (keyset) pagination with a server-clamped `limit`, whitelisted filter/sort fields and a stated totals policy; no endpoint returns the whole catalogue in one response
- **SHOULD** [API-36] The cursor is opaque: clients store and echo it, never parse or build it
- **SHOULD** [API-37] `limit` is clamped by the server and the contract states the maximum (e.g. 500 requested, 200 served)
- **SHOULD** [API-38] Collection responses use a body envelope `{"items": [...], "nextCursor": ..., "limit": ...}`. `nextCursor` is null on the last page
- **SHOULD** [API-39] The contract states whether `totalCount` is exact (`COUNT(*)` per page), on request (`?include=total`), an estimate, or absent; a common compromise counts at most 1 001 rows and reports "more than 1 000"
- **SHOULD** [API-40] OFFSET pagination is acceptable only for shallow navigation over small, stable data (e.g. back-office), never the public event list

### Media types & bodies

- **SHOULD** [API-41] JSON (`application/json`) is the default; besides it, tickets are `application/pdf`, sales exports `text/csv`, the seat stream `text/event-stream`, errors `application/problem+json`
- **SHOULD** [API-42] Accepted request bodies: JSON, form encoding (`application/x-www-form-urlencoded`, e.g. OAuth flows) and `multipart/form-data` (file uploads)
- **SHOULD** [API-43] Every endpoint declares the media types it produces and consumes, recorded per operation in OpenAPI; unmatched `Accept`/`Content-Type` yields 406/415
- **SHOULD** [API-44] The API is token-based and does not read cookies

### Cross-cutting headers

- **SHOULD** [API-45] CORS policy is part of the API contract, enforced in the application with one central configuration per service (Spring `WebMvcConfigurer`, Axum `CorsLayer`; `@CrossOrigin` only for local exceptions): exact origins from typed configuration differing between dev and prod, methods GET/POST/PUT/PATCH/DELETE, allowed request headers `Authorization`, `Content-Type`, `Idempotency-Key`, `If-Match`, `If-None-Match`, `X-Request-Id`, exposed response headers `ETag`, `Location`, `Retry-After`, `X-Request-Id`, `Access-Control-Max-Age` to cache preflights
- **SHOULD** [API-46] Under overload, admission is bounded and the excess is refused immediately with 429/503 + `Retry-After` so clients can retry with backoff

## Request parsing

### Limits before the handler

- **SHOULD** [API-47] The server enforces limits before any handler runs — maximum body size, maximum number of headers, read timeouts (DoS protection)
- **SHOULD** [API-48] Stack mechanisms: Spring `spring.servlet.multipart.max-file-size`/`max-request-size` plus a server-level limit; Axum `DefaultBodyLimit` (2 MB default) and `RequestBodyLimitLayer` per route (example `64 * 1024`)
- **SHOULD** [API-49] Parse, don't validate: convert input once at the boundary into narrow types that only represent legal values

### Strictness policy

- **SHOULD** [API-50] Strict requests, tolerant responses: the strictness policy is answered once, globally, as configuration
- **SHOULD** [API-51] Unknown fields are rejected with 400/422 (`#[serde(deny_unknown_fields)]`, Jackson fail-on-unknown-properties)
- **SHOULD** [API-52] No implicit coercion between JSON types (no `"42"` for an integer, no `1`/`"true"` for a boolean)
- **SHOULD** [API-53] Missing, null and absent are distinct request cases (PATCH depends on it; use a presence wrapper / `Option<Option<T>>`, or offer PUT instead)
