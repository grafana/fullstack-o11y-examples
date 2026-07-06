# ruby / docker-compose — Observable Bookstore

Fully implemented Ruby stack: a React storefront + three **Sinatra + Sequel**
backend services + MySQL + PostgreSQL + Grafana Alloy, instrumented with
**SQLCommenter + OpenTelemetry** and exporting to **Grafana Cloud**. Mirrors the
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

- Each service configures OpenTelemetry (OTLP/gRPC to `alloy:4317`) in
  [`services/common/otel.rb`](services/common/otel.rb): a small Rack middleware
  opens a server span per request, the **Faraday** instrumentation covers outbound
  client spans, and the **`mysql2` + `pg`** instrumentations create a span per
  query with the SQL as the **`db.statement`** attribute (Sequel runs on those
  client gems, which are required up front so they can be patched at install time).
- **SQLCommenter** is implemented as a Sequel database extension
  ([`services/common/sqlcommenter.rb`](services/common/sqlcommenter.rb)): it
  overrides `execute`/`execute_dui`/`execute_insert` and appends a SQLCommenter
  comment built from the active span context
  (`OpenTelemetry::Trace.current_span.context` → hex trace_id/span_id) to every
  SQL statement, e.g. `SELECT ... /*traceparent='00-<traceid>-<spanid>-01'*/`.
  This powers trace↔SQL correlation in Grafana Cloud.
- The checkout→shipping call uses **Faraday** with the OpenTelemetry Faraday
  instrumentation, which injects the W3C `traceparent` header, so a single
  checkout produces one distributed trace: **browser (Faro) → checkout → MySQL**
  and **→ shipping → PostgreSQL**.
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
└── services/                 # shared build context, one Gemfile
    ├── Gemfile
    ├── common/               # otel.rb, db.rb, sqlcommenter.rb (Sequel extension)
    ├── products/             # Sinatra + Sequel → MySQL
    ├── checkout/             # Sinatra + Sequel → MySQL, calls shipping (Faraday)
    └── shipping/             # Sinatra + Sequel → PostgreSQL
```
