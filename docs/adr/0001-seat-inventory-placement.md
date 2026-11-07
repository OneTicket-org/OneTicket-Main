# ADR-0001: Seats, holds and orders live in Inventory & Orders; Catalogue keeps events and venues

- Status: Accepted
- Date: 2026-11-07
- Rules: [ARCH-07], [ARCH-21], [ARCH-23], [SVC-12], [BIZ-01], [BIZ-02], [BIZ-13]

## Context

The purchase path touches four kinds of data: event and venue descriptions, per-event seat state (FREE / HELD / SOLD, [BIZ-03]), holds and orders. They must be split across services that own their own schema and talk only through APIs or messages ([ARCH-06], [ARCH-07]); every boundary needs a justifying ADR ([ARCH-21]).

Two placements were viable for seat state and holds: next to the event data in Catalogue, or next to orders in Inventory & Orders. The deciding invariants span seats and orders:

- a seat is sold at most once ([BIZ-01]) and only against a paid order ([BIZ-05], [BIZ-12]);
- a cancelled order releases its held seats ([BIZ-13]);
- a hold may expire while its order is still pending ([BIZ-10], open).

The two data sets also behave differently. Events and venues are written rarely by organisers, mostly before sales open, are read-heavy and cacheable for minutes ([API-31]). Seat state changes on every hold, is not cacheable ([API-31]), and concentrates write contention on hot rows at sales opening, where the database fails first ([OPS-07]).

## Decision

- **Catalogue** owns events and venues: descriptive data, venue seating plan (layout), price tiers, sales opening time.
- **Inventory & Orders** owns the sellable seat inventory of each event (seat, state, version, price), holds and orders.
- Seat state, holds and orders form one transactional boundary: a hold, its order and the resulting seat transitions are enforced in a single local transaction with DB-enforced seat uniqueness ([SVC-12], [ARCH-23]).

Keep-together signal (seats + holds + orders): shared invariants that must hold atomically and data that changes on the same request path. Split signal (Catalogue vs Inventory): different writers and change rate, different read/write and caching profile, different load peak, and fault isolation of browsing from sales.

### Rejected alternatives

| Alternative | Why rejected |
| --- | --- |
| Seats and holds in Catalogue, orders in Inventory & Orders | Order creation needs a synchronous Catalogue call to check and lock the hold; payment completion, cancellation and hold expiry become cross-service sagas with windows where a paid order points at a freed seat ([BIZ-01], [BIZ-02]); every purchase crosses the boundary. Volatile seat state also breaks Catalogue's caching profile. |
| Events, seats, holds and orders all in one service | Removes the boundary but couples read-heavy, cacheable browsing with write-heavy sales on the same database and replicas: contention at sales opening degrades browsing. |

## Consequences

- Purchase-path operations (seat map, holds, orders, seat stream) are Inventory & Orders endpoints; the only synchronous dependency left on the purchase path is Payments.
- The SPA composes the seat map from two sources: static layout from Catalogue (cacheable, possibly an object-storage bundle, [ARCH-19]) and live seat state from Inventory (not cacheable, plus SSE, [ARCH-13]).
- Inventory & Orders carries the release-day peak alone and must be sized and protected for it ([OPS-06], [OPS-07]); this matches its Rust/Axum stack choice in milestone 1.
