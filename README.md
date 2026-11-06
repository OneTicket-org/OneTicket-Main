# OneTicket-main

Central documentation for the OneTicket ticketing platform microservices: binding project constraints ([docs/constraints/](docs/constraints/README.md)), the domain [glossary](docs/glossary.md), and milestone design documents ([docs/milestones/](docs/milestones/)). Start from [AGENTS.md](AGENTS.md) for a map of every document and the rules for citing constraints by ID; it serves both humans and coding agents.

## Service repositories

Each service lives in its own repository, included here as a git submodule under `services/`.

| Service              | Stack         | Submodule                   | Repository                                                                              |
| -------------------- | ------------- | --------------------------- | --------------------------------------------------------------------------------------- |
| Catalogue            | Kotlin/Spring | `services/catalogue`        | [OneTicket-Catalogue](https://github.com/OneTicket-org/OneTicket-Catalogue)             |
| Inventory and orders | Rust/Axum     | `services/inventory-orders` | [OneTicket-InventoryOrders](https://github.com/OneTicket-org/OneTicket-InventoryOrders) |
| Ticketing            | Rust/Axum     | `services/ticketing`        | [OneTicket-Ticketing](https://github.com/OneTicket-org/OneTicket-Ticketing)             |
| Payments             | Kotlin/Spring | `services/payments`         | [OneTicket-Payments](https://github.com/OneTicket-org/OneTicket-Payments)               |
| Notifications        | Kotlin/Spring | `services/notifications`    | [OneTicket-Notifications](https://github.com/OneTicket-org/OneTicket-Notifications)     |

Clone with the submodules:

```sh
git clone --recurse-submodules git@github.com:OneTicket-org/OneTicket-main.git
```

In an existing clone, run `git submodule update --init`. Submodules are pinned to a commit. A merge to a service's `main` moves its pointer automatically: the service's `notify-main.yml` workflow triggers [`update-submodules.yml`](.github/workflows/update-submodules.yml) here, which commits the new pointer. To test against the latest code locally, run `git submodule update --remote` and don't commit the resulting pointer changes.
