# Purchase flow

```mermaid
sequenceDiagram
  autonumber
  actor C as Client
  participant INV as Inventory and Orders
  participant PAY as Payments
  participant PSP as PSP sandbox
  participant BR as Broker
  participant TKT as Ticketing
  participant NTF as Notifications

  C->>INV: POST /events/{eventId}/holds
  Note over INV: UPDATE seat state FREE -> HELD
  INV-->>C: 201 hold, expires_at
  C->>INV: POST /orders/{hold_id}/checkout
  Note over INV: order PENDING
  INV->>PAY: POST /payments
  PAY->>PSP: POST /psp
  PAY-->>INV: 202 payment_id
  INV-->>C: 202 payment_id (waiting for payment)
  C->>PSP: POST /psp/{paymentId}/pay
  PSP->>PAY: PATCH /payments/{paymentsId}
  Note over PAY: payment received
  PAY-)BR: Payment received for {orderId}
  BR-)INV: PaymentCompleted
  Note over INV: check expires_at delta
  INV-)BR: OrderCompleted
  BR-)TKT: OrderCompleted
  Note over TKT: Creates ticket files
  TKT-)BR: TicketIssued
  BR-)NTF: TicketIssued
  NTF-