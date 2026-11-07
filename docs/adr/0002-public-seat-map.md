# ADR-0002: Seat maps and catalogue reads are readable without authentication

- Status: Accepted
- Date: 2026-11-07
- Rules: [SEC-02], [SEC-05], [API-31], [API-46], [ARCH-14], [ARCH-30]
- Amended: 2026-11-07, extended to the Catalogue event and venue reads

## Context

[SEC-02] (SHOULD) asks every service to verify the JWT on every hop and the edge to reject requests without a valid token before they consume capacity. Customers browse events and their seat availability before deciding to buy, often before logging in. Seat reads expose no personal data: a seat's state (FREE / HELD / SOLD) and price, never who holds or bought it. Event and venue descriptions are published information meant to be found by anyone, and a seat map is only reachable after an event has been found.

## Decision

The following reads are public: they declare `security: []` in OpenAPI ([SEC-05]) and accept requests without a token.

- Inventory & Orders seat reads: `GET /api/v1/events/{eventId}/seats` and `GET /api/v1/events/{eventId}/seats/{seatId}`.
- Catalogue event and venue reads: `GET /api/v1/events`, `GET /api/v1/events/{eventId}`, `GET /api/v1/venues` and `GET /api/v1/venues/{venueId}`.

Every other operation keeps requiring a Keycloak JWT with the role it declares ([ARCH-30]); placing a hold requires the `customer` role, creating or changing events and venues the `organizer` role.

This deviates from [SEC-02] for these read operations only.

### Rejected alternatives

| Alternative | Why rejected |
| --- | --- |
| Require a token for seat and catalogue reads, as [SEC-02] states | Forces login before a customer can find an event or see availability; the protected data is not personal. |
| Anonymous Keycloak token issued to every visitor | Satisfies the letter of [SEC-02] but adds a token round trip and Keycloak load on the busiest read path without protecting anything. |

## Consequences

- The edge (load balancer / gateway) must let unauthenticated requests reach these read routes, and only these; every other route still rejects missing tokens at the edge. The Inventory & Orders and Catalogue routes share the `/api/v1/events/{eventId}` prefix, so the edge matches method and full path, not the prefix.
- Unauthenticated traffic cannot be rate-limited per user: these routes need per-client (e.g. per-IP) limits and load shedding with `429`/`503` + `Retry-After` ([API-46]). The seat map is not cacheable ([API-31]) and is read hardest at sales opening; catalogue reads are cacheable for minutes ([API-31]), which absorbs most of their load.
- The SPA can render events, venues and the seat map before login and asks for a token only when the customer places a hold.
- The seat stream is not covered: its authentication stays open ([ARCH-14]), although this decision makes a public stream a consistent option.
