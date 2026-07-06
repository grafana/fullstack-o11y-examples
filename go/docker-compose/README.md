# go / docker-compose — Observable Bookstore

Fully implemented Go stack: a React storefront + three Go (`net/http`) backend
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
fill in `.env` to see traces/metrics. Faro is disabled until `VITE_FARO_*` are set.

## Observability

- Each service configures OpenTelemetry (OTLP/gRPC to Alloy) in
  [`services/common/otel.go`](services/common/otel.go) and wraps its HTTP handler
  with `otelhttp` for server spans + metrics.
- Databases are opened in [`services/common/db.go`](services/common/db.go) through
  [`XSAM/otelsql`](https://github.com/XSAM/otelsql) — which creates a child span per
  query/exec carrying the SQL as the **`db.statement`** attribute — composed with
  Google's **SQLCommenter** `go/database/sql` integration (`EnableTraceparent`), so
  each statement also carries the active W3C traceparent as a SQL comment. Together
  that gives per-query DB spans plus trace↔SQL correlation.
- Outbound calls use an `otelhttp` transport, so a checkout produces one
  distributed trace: **browser (Faro) → checkout → MySQL** and **→ shipping → PostgreSQL**.
- All telemetry flows through **Grafana Alloy** ([`alloy/config.alloy`](alloy/config.alloy))
  to Grafana Cloud (Tempo / Prometheus / Loki).

## HTTP API contract & database schema

Identical to the Python reference — see
[`../../python/docker-compose/README.md`](../../python/docker-compose/README.md)
for the full route table and the MySQL/PostgreSQL schema and seed data
(20 books, 10 customers, 100 orders, 2 warehouses, 100 shipments).

## Layout

```
docker-compose/
├── docker-compose.yml
├── .env.example
├── alloy/config.alloy
├── databases/{mysql,postgres}/init.sql
├── frontend/                 # React + Vite + Faro, served by nginx
└── services/                 # single Go module (module "bookstore")
    ├── go.mod / go.sum
    ├── common/               # otel.go, db.go (SQLCommenter), http.go
    ├── products/             # net/http → MySQL
    ├── checkout/             # net/http → MySQL, calls shipping
    └── shipping/             # net/http → PostgreSQL
```
