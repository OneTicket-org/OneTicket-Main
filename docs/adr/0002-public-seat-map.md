# ADR-0002: Seat maps are readable without authentication

- Status: Accepted
- Date: 2026-11-07
- Rules: [SEC-02], [SEC-05], [API-31], [API-46], [ARCH-14], [ARCH-30]

## Context

[SEC-02] (SHOULD) asks every service to verify the JWT on every hop and the edge to reject requests without a valid token before they consume capacity. Customers browse events and their seat availability before deciding to buy, often before logging in. Seat reads expose no personal data: a seat's state (FREE / HELD / SOLD) and price, never who holds or bought it.

## Decision

The seat reads of Inventory & Orders, `GET /api/v1/events/{eventId}/seats` and `GET /api/v1/events/{eventId}/seats/{seatId}`, are public: they declare `security: []` in OpenAPI ([SEC-05]) and accept requests without a token. Every other operation keeps requiring a Keycloak JWT with the role it declares ([ARCH-30]); placing a hold requires the `customer` role.

This deviates from [SEC-02] for these two operations only.

### Rejected alternatives

| Alternative | Why rejected |
| --- | --- |
| Require a token for seat reads, as [SEC-02] states | Forces login before a customer can see availability; the protected data is not personal. |
| Anonymous Keycloak token issued to every visitor | Satisfies the letter of [SEC-02] but adds a token round trip and Keycloak load on the busiest read path without protecting anything. |

## Consequences

- The edge (load balancer / gateway) must let unauthenticated requests reach these two routes, and only these; every other route still rejects missing tokens at the edge.
- Unauthenticated traffic cannot be rate-limited per user: these routes need per-client (e.g. per-IP) limits and load shedding with `429`/`503` + `Retry-After` ([API-46]), since the seat map is not cacheable ([API-31]) and is read hardest at sales opening.
- The SPA can render the seat map before login and asks for a token only when the customer places a hold.
- The seat stream is not covered: its authentication stays open ([ARCH-14]), although this decision makes a public stream a consistent option.
