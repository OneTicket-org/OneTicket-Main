# Purchase flow

Happy path and failure paths of a ticket purchase. Operations are those of the Milestone 2 OpenAPI drafts; every path is mounted under `/api/v1` ([API-10]). Synchronous calls cover the purchase path, asynchronous messages everything after payment ([ARCH-16]). Message names are descriptive: their contract is not defined yet.

```mermaid
sequenceDiagram
  autonumber
  actor C as Client (SPA)
  participant INV as Inventory and Orders
  participant PAY as Payments
  participant PSP as PSP sandbox
  participant BR as Broker
  participant TKT as Ticketing
  participant NTF as Notifications

  C->>INV: GET /events/{eventId}/seats
  INV-->>C: 200 seat map

  loop one hold per seat
    C->>INV: POST /events/{eventId}/holds {seatId}
    Note over INV: seat FREE -> HELD
    INV-->>C: 201 Hold {id, expiresAt}
  end
  Note over C,INV: 409 SEAT_UNAVAILABLE / HOLD_LIMIT_REACHED / SALES_CLOSED

  C->>INV: POST /orders {holdIds}
  Note over INV: order PENDING
  INV->>PAY: POST /payments {orderId, customerId, amount}
  PAY->>PSP: register payment
  PSP-->>PAY: registered
  PAY-->>INV: 201 Payment {id, status: PENDING}
  INV-->>C: 201 Order {id, status: PENDING, paymentId}, Location
  Note over C,PAY: if issue, client retries with the same Idempotency-Key

  C->>PSP: pay with paymentId
  PSP->>PAY: POST /psp-events {id, type, paymentId}
  PAY-->>PSP: 204

  loop until status is not PENDING
    C->>INV: GET /orders/{orderId}, If-None-Match
    INV-->>C: 200 Order / 304
  end

  alt payment.succeeded
    Note over PAY: payment PENDING -> SUCCEEDED
    PAY-)BR: payment succeeded {orderId, paymentId}
    BR-)INV: payment succeeded
    Note over INV: order PENDING -> PAID, seats HELD -> SOLD
    INV-)BR: order paid

    BR-)TKT: order paid
    Note over TKT: issue one VALID ticket per seat
    TKT-)BR: tickets issued
    BR-)NTF: tickets issued
    Note over NTF: TICKETS email, PDFs attached

    BR-)NTF: order paid
    Note over NTF: ORDER_CONFIRMATION email

  else payment.failed, or no outcome within the payment timeout
    Note over PAY: payment PENDING -> DECLINED
    PAY-)BR: payment failed {orderId, reason}
    BR-)INV: payment failed
    Note over INV: order PENDING -> CANCELLED seats HELD -> FREE
  end
```
