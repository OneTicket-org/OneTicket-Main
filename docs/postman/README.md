# Postman imports

Import both JSON files into Postman:

1. `oneticket-milestone2.postman_collection.json` contains the requests grouped into one folder per service.
2. `oneticket-local.postman_environment.json` contains the local base URLs used by those requests.

Select the **OneTicket Local** environment before sending requests. Catalogue, Payments, and Notifications use the ports currently published by the central Compose file. Inventory & Orders (`3000`) and Ticketing (`3001`) are provisional local ports; update their environment values when those services' ports are confirmed.

Requests intentionally use no authentication for the current milestone. The folder descriptions record the role policies from the OpenAPI contracts for later implementation. Authentication must be added to Postman when the services enforce it.

Request bodies and parameters come from the Milestone 2 OpenAPI documents in `docs/milestones/milestone2/`. Those documents currently identify themselves as `0.1.0-draft`; regenerate or update the collection if a contract changes. Path IDs are sample values and should be replaced with IDs created by a running service. `Idempotency-Key` uses Postman's `{{$guid}}`; when retrying the same logical operation, reuse the same key.

The collection includes all HTTP operations in the five service contracts. It does not configure or test RabbitMQ message contracts, which are not defined in the current milestone documents.

The Catalogue, Payments, and Notifications folders also include Spring Boot Actuator requests for endpoint discovery, application info, aggregate health, readiness, and liveness. `/actuator/health/readiness` is an application-availability probe; Spring Boot does not include external dependency health in that probe by default. `/actuator/health` reports aggregate health, while the current services hide component details. Inventory & Orders and Ticketing use Rust/Axum and do not have Actuator endpoints; add their health requests when their health paths are defined.
