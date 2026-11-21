# Local Docker environment

This guide covers the local Docker Compose stack in the repository root. The Compose project currently starts PostgreSQL, Keycloak, RabbitMQ, and the Kotlin services Catalogue, Payments, and Notifications. Inventory & Orders and Ticketing databases are provisioned, but those Rust services are not yet defined in this Compose file.

## Prerequisites and local files

- Docker Desktop with Docker Compose v2
- A local `.env` file in the repository root

Create `.env` from the committed example. Keep real credentials in `.env`; it is ignored by Git.

```powershell
Copy-Item .env.example .env -NoClobber
```

The `.env.example` values are local development placeholders. Change them if needed before sharing the setup beyond your own machine.

### Building from standalone service checkouts

The tracked `docker-compose.yaml` builds services from their submodule paths (`services/catalogue`, etc.). To build from the separate sibling repositories used during local feature work, copy the provided override template:

```powershell
Copy-Item docker-compose.local.example.yaml docker-compose.local.yaml
```

Edit the `build.context` paths in `docker-compose.local.yaml` if your checkouts are not named or located as in the template. This developer-only override is ignored by Git. When the pinned service submodules contain the code and Dockerfiles you want to run, you can omit the override file.

The commands below use both files so they work with the standalone checkouts. If you are building directly from submodules, omit `-f docker-compose.local.yaml` from each command.

## Start the stack

Build and start all services defined in Compose:

```powershell
docker compose -f docker-compose.yaml -f docker-compose.local.yaml up -d --build
```

To start the same stack with the optional Adminer database UI:

```powershell
docker compose -f docker-compose.yaml -f docker-compose.local.yaml --profile tools up -d --build
```

Adminer is optional and does not start during a normal `up`. It can also be started on its own; Compose starts its PostgreSQL dependency if needed:

```powershell
docker compose --profile tools up -d adminer
```

## Start one service

Specify a service name to build and start only that service and its declared dependencies. For example, Payments starts PostgreSQL and RabbitMQ, but not the other application services:

```powershell
docker compose -f docker-compose.yaml -f docker-compose.local.yaml up -d --build payments
```

Other useful targets are `catalogue`, `notifications`, `postgres`, `keycloak`, and `rabbitmq`. Adminer uses the `tools` profile as shown above. After changing a service's source or build dependencies, repeat its `up` command with `--build`.

## Inspect and stop the stack

Show container status:

```powershell
docker compose -f docker-compose.yaml -f docker-compose.local.yaml ps
```

Follow one service's logs:

```powershell
docker compose -f docker-compose.yaml -f docker-compose.local.yaml logs -f payments
```

Stop and remove the containers while keeping database and RabbitMQ data:

```powershell
docker compose -f docker-compose.yaml -f docker-compose.local.yaml down
```

To also erase the persistent PostgreSQL and RabbitMQ volumes, use `down -v`. This permanently deletes local database data, Keycloak state, and broker state:

```powershell
docker compose -f docker-compose.yaml -f docker-compose.local.yaml down -v
```

PostgreSQL initialization scripts in `infra/postgres/init` run only when the PostgreSQL volume is first created. Changing an init script or a password in `.env` does not update an already initialized database. Apply the required SQL/password change manually, or use `down -v` only when the existing local data can be discarded.

## Local URLs and ports

| Component | URL or host port | Notes |
| --- | --- | --- |
| PostgreSQL | `localhost:5433` | Host access; other Compose containers use `postgres:5432`. |
| Keycloak | `http://localhost:8080` | Admin console and local realm. |
| Catalogue | `http://localhost:8081` | Spring Boot service; readiness at `/actuator/health/readiness`. |
| Payments | `http://localhost:8082` | Spring Boot service; readiness at `/actuator/health/readiness`. |
| Notifications | `http://localhost:8083` | Spring Boot service; readiness at `/actuator/health/readiness`. |
| RabbitMQ AMQP | `localhost:5672` | Application protocol port; Compose containers use `rabbitmq:5672`. |
| RabbitMQ management | `http://localhost:15672` | Browser management console. |
| Adminer | `http://localhost:8090` | Optional; start with profile `tools`. |

The lab stack also uses host ports `5433` and `8090`; stop it before starting this stack, or change one stack's host port mappings to avoid conflicts.

## Credentials and database ownership

The Compose project runs one PostgreSQL container with separate logical databases and roles. Each service account owns and connects to its own database; the bootstrap account can administer all of them.

| Database | PostgreSQL user | Password variable in `.env` | Owner |
| --- | --- | --- | --- |
| `keycloak_db` | `keycloak` | `KEYCLOAK_DB_PASSWORD` | Keycloak |
| `catalogue_db` | `catalogue` | `CATALOGUE_DB_PASSWORD` | Catalogue |
| `inventory_db` | `inventory` | `INVENTORY_DB_PASSWORD` | Inventory & Orders |
| `payments_db` | `payments` | `PAYMENTS_DB_PASSWORD` | Payments |
| `ticketing_db` | `ticketing` | `TICKETING_DB_PASSWORD` | Ticketing |
| `notifications_db` | `notifications` | `NOTIFICATIONS_DB_PASSWORD` | Notifications |
| `postgres` | `POSTGRES_USER` (default: `oneticket_admin`) | `POSTGRES_PASSWORD` | Local bootstrap administrator |

In Adminer, select system `PostgreSQL` and server `postgres`. Use a service's user, matching password variable, and database name to inspect that service's data. Use the bootstrap administrator only for local administration. Postman is separate: it calls the services' HTTP APIs and does not connect to PostgreSQL.

Management UI credentials are separate from the PostgreSQL accounts:

| UI | Username variable/value | Password variable | Notes |
| --- | --- | --- | --- |
| Keycloak admin console | `KEYCLOAK_ADMIN_USERNAME` | `KEYCLOAK_ADMIN_PASSWORD` | Keycloak administration; not the `keycloak` PostgreSQL role. |
| RabbitMQ management | `RABBITMQ_USER` | `RABBITMQ_PASSWORD` | These credentials also configure the AMQP account used by the current local services. |
| Adminer | A PostgreSQL username from the database table above | Corresponding database password variable | Adminer has no separate account; PostgreSQL controls what the selected role can access. |
