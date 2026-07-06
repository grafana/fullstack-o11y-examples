# fullstack-o11y-examples

An online bookstore e‑commerce reference application, implemented per
[SQLCommenter](https://google.github.io/sqlcommenter/)‑supported language, and
instrumented end‑to‑end with **SQLCommenter + OpenTelemetry → Grafana Alloy → Grafana Cloud**.

Each language folder contains a `docker-compose/` and a `k8s/` deployment of the
same app: a **React** storefront where users browse books, add them to a cart,
and check out. The frontend talks to three backend services — **products**,
**checkout**, and **shipping** — written in that folder's language.

## Architecture

```
                 ┌─────────────┐
  Browser  ───▶  │  React FE   │  (Faro React SDK → Grafana Cloud)
                 │  + nginx    │
                 └──────┬──────┘
        /api/products   │   /api/checkout   /api/shipping
        ┌───────────────┼───────────────────┐
        ▼               ▼                    ▼
  ┌───────────┐   ┌───────────┐        ┌───────────┐
  │ products  │   │ checkout  │        │ shipping  │
  └─────┬─────┘   └─────┬─────┘        └─────┬─────┘
        │  MySQL        │  MySQL             │  PostgreSQL
        └───────────────┴────────┐          │
                                  ▼          ▼
                           ┌──────────┐  ┌──────────┐
                           │  MySQL   │  │ Postgres │
                           │ bookstore│  │ shipping │
                           └──────────┘  └──────────┘

  All services export OTLP (traces/metrics/logs) → Grafana Alloy → Grafana Cloud.
  SQL statements carry SQLCommenter tags (trace context) for trace↔SQL correlation.
```

### Databases

- **MySQL** (`bookstore`): `books_inventory` (20 titles), `customers` (10),
  `orders` (10 per customer = 100).
- **PostgreSQL** (`shipping`): `warehouses` (2 — California & New York) and
  `shipments` mapping each order → warehouse → customer shipping address.

## Languages (SQLCommenter‑supported)

| Language | docker-compose | k8s | Status |
|----------|:--------------:|:---:|--------|
| [python](./python)  | ✅ | ✅ | **Fully implemented reference** (Flask + SQLAlchemy) |
| [go](./go)          | ✅ | ✅ | **Fully implemented** (net/http + database/sql) |
| [nodejs](./nodejs)  | ✅ | ✅ | **Fully implemented** (Express + mysql2/pg) |
| [java](./java)      | ✅ | ✅ | **Fully implemented** (Spring Boot + JdbcTemplate) |
| [ruby](./ruby)      | ✅ | ✅ | **Fully implemented** (Sinatra + Sequel) |

All five languages are fully implemented and share the same HTTP API contract,
database schema/seed data, React frontend, and Alloy → Grafana Cloud pipeline;
each `docker-compose` stack has been verified end-to-end (catalog → cart →
checkout → shipping) with the SQLCommenter `traceparent` confirmed in real SQL.
[`python/docker-compose`](./python/docker-compose) is the canonical reference for
the shared contract.

## Quick start (any language)

```bash
cd python/docker-compose   # or go / nodejs / java / ruby
cp .env.example .env        # fill in Grafana Cloud values
docker compose up --build
# Storefront:  http://localhost:8080
# Alloy UI:    http://localhost:12345
```

Run one language at a time — every stack binds the same host ports (8080, 8001–8003, 3306, 5432).
