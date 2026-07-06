# nodejs / docker-compose — Observable Bookstore

Fully implemented Node.js stack: a React storefront + three Express backend
services + MySQL + PostgreSQL + Grafana Alloy, instrumented with **SQLCommenter +
OpenTelemetry** and exporting to **Grafana Cloud**. Mirrors the
[Python reference](../../python/docker-compose) exactly at the API and database level.

## Run

```bash
cp .env.example .env          # fill in Grafana Cloud + Faro values
docker compose up --build     # first run seeds both databases
```

| Component | URL |
|-----------|-----|
| Storefront (nginx + React) | http://localhost:8080 |
| Products service           | http://localhost:8001/api/products |
| Checkout service           | http://localhost:8002 |
| Shipping service           | http://localhost:8003 |
| Alloy UI                   | http://localhost:12345 |
| MySQL                      | localhost:3306 |
| PostgreSQL                 | localhost:5432 |

Telemetry works without Grafana Cloud credentials (export just fails silently);
fill in `.env` to see traces. Faro is disabled until `VITE_FARO_*` are set.

## Observability

- Each service starts the OpenTelemetry Node SDK (OTLP/gRPC to Alloy) in
  [`services/common/otel.js`](services/common/otel.js), loaded via
  `node -r ./common/otel.js <svc>/index.js` **before** express/mysql2/pg are
  required so their instrumentations can patch them. Instrumentations:
  `instrumentation-http`, `-express`, `-mysql2`, `-pg`.
- The `mysql2` and `pg` instrumentations run with
  `addSqlCommenterCommentToQueries: true`, so every SQL statement is annotated
  with a **SQLCommenter** comment carrying the active W3C traceparent, e.g.
  `... /*traceparent='00-<traceid>-<spanid>-01'*/`. This enables trace↔SQL
  correlation in Grafana Cloud (same mechanism as the Python reference).
- The checkout→shipping call is made through Node's core `http` module (see
  [`services/checkout/shipping_client.js`](services/checkout/shipping_client.js))
  so `instrumentation-http` injects the traceparent header. A checkout therefore
  produces one distributed trace: **browser (Faro) → checkout → MySQL** and
  **→ shipping → PostgreSQL**.
- All telemetry flows through **Grafana Alloy** ([`alloy/config.alloy`](alloy/config.alloy))
  to Grafana Cloud (Tempo / Prometheus / Loki).

## HTTP API contract & database schema

Identical to the Python reference — see
[`../../python/docker-compose/README.md`](../../python/docker-compose/README.md)
for the full route table and the MySQL/PostgreSQL schema and seed data
(20 books, 10 customers, 100 orders, 2 warehouses, 100 shipments).

## Ports

| Port | Service |
|------|---------|
| 8080 | frontend (nginx + React) |
| 8001 | products |
| 8002 | checkout |
| 8003 | shipping |
| 3306 | MySQL |
| 5432 | PostgreSQL |
| 4317 | Alloy OTLP gRPC |
| 4318 | Alloy OTLP HTTP |
| 12345 | Alloy UI |
| 12347 | Alloy Faro receiver |

## Layout

```
docker-compose/
├── docker-compose.yml
├── .env.example
├── alloy/config.alloy
├── databases/{mysql,postgres}/init.sql
├── frontend/                # React + Vite + Faro, served by nginx
└── services/                # single npm workspace, shared build context
    ├── package.json         # all deps (express, mysql2, pg, OTel)
    ├── common/otel.js       # OTel SDK + SQLCommenter bootstrap
    ├── products/            # Express → MySQL
    ├── checkout/            # Express → MySQL, calls shipping
    └── shipping/            # Express → PostgreSQL
```
