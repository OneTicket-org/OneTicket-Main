# ADR-0003: PSP webhooks are authenticated by signature, not by a Keycloak token

- Status: Pending
- Date: 2026-11-07
- Rules: [SEC-02], [SEC-05], [SEC-07], [BIZ-12], [BIZ-16], [BIZ-18], [BIZ-19], [ARCH-16]

## Context

The payment outcome reaches the platform through the PSP: the customer pays at the PSP, the PSP reports the result to Payments with a webhook, and Payments notifies Inventory & Orders with an asynchronous message ([BIZ-12], [ARCH-16]). Webhooks are delivered at least once and possibly out of order ([BIZ-16], [BIZ-18]).

[SEC-02] (SHOULD) asks every hop to carry a Keycloak JWT and the edge to reject requests without one. The PSP is an external system: it cannot obtain Keycloak tokens, and it authenticates its deliveries with its own mechanism, a signature computed with a secret shared with the merchant.

## Decision

- Payments exposes `POST /api/v1/psp-events` to receive PSP webhooks. It declares the PSP signature scheme instead of `bearerAuth` in OpenAPI ([SEC-05]) and accepts requests without a Keycloak token.
- Every delivery is authenticated by verifying the PSP signature over the raw request body, before the body is parsed, with the shared secret injected at deployment ([SEC-07]). A missing or invalid signature answers `401`. Header name, algorithm and replay window follow the PSP sandbox's documentation.
- Deliveries are deduplicated by the PSP event identifier ([BIZ-18]): a duplicate answers `204` without re-executing, so the PSP stops redelivering. Events that would cause an illegal transition (e.g. a failure reported after a success) are recorded and ignored ([BIZ-15], [BIZ-16]).

This deviates from [SEC-02] for this operation only.

### Rejected alternatives

| Alternative | Why rejected |
| --- | --- |
| Require a Keycloak JWT, as [SEC-02] states | The PSP cannot obtain one; webhooks would be impossible. |
| IP allow-list of the PSP only | Addresses can change and be spoofed behind proxies; it proves where a request came from, not that the PSP wrote its body. Acceptable as an extra layer, not as the authentication. |
| Poll the PSP for outcomes instead of receiving webhooks | Adds latency between payment and confirmation and load proportional to pending payments; [BIZ-18] already assumes webhooks. |

## Consequences

- The edge must let unauthenticated requests reach `POST /api/v1/psp-events`, and only it among Payments' routes; it is rate-limited per client like the public reads of [ADR-0002](0002-public-seat-map.md).
- The webhook secret is a deployment secret: never committed nor baked into the image, rotatable without a new build ([SEC-07]).
- Processed PSP event identifiers must be stored and checked atomically across stateless replicas; where they live is still open (**TODO** [BIZ-19]).
- The signature scheme is PSP-specific: switching PSP changes this operation's security scheme and body, not the rest of the Payments API.
