# java / docker-compose — Observable Bookstore

Fully implemented Java stack: a React storefront + three Spring Boot 3 (Java 21)
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

- Each service is instrumented with the **OpenTelemetry Java agent**, downloaded
  into the image in the `Dockerfile` and enabled via
  `-javaagent:/otel/opentelemetry-javaagent.jar`. The agent auto-instruments
  Spring MVC (server spans + metrics), JDBC (DB client spans), and outbound HTTP
  (`RestClient`), reading `OTEL_EXPORTER_OTLP_ENDPOINT` (→ `alloy:4317`) and
  `OTEL_SERVICE_NAME` (products-service / checkout-service / shipping-service).
- **SQLCommenter**: the agent does not inject SQLCommenter by default, so each
  service ships a small `SqlCommenter` helper (`SqlCommenter.annotate(sql)`) that
  is applied to every `JdbcTemplate` query/update. It reads the active span via
  `io.opentelemetry.api.trace.Span.current().getSpanContext()` and appends a
  comment carrying the W3C traceparent, e.g.
  `SELECT ... /*traceparent='00-<traceId>-<spanId>-01',db_driver='spring-jdbc'*/`.
  Values are URL-encoded per the SQLCommenter spec — enabling trace↔SQL correlation.
- Outbound calls from checkout propagate trace context (agent-injected
  `traceparent` header), so one checkout produces a single distributed trace:
  **browser (Faro) → checkout → MySQL** and **→ shipping → PostgreSQL**.
- All telemetry flows through **Grafana Alloy** ([`alloy/config.alloy`](alloy/config.alloy))
  to Grafana Cloud (Tempo / Prometheus / Loki).

## HTTP API contract & database schema

Identical to the Python reference — see
[`../../python/docker-compose/README.md`](../../python/docker-compose/README.md)
for the full route table and the MySQL/PostgreSQL schema and seed data
(20 books, 10 customers, 100 orders, 2 warehouses, 100 shipments). JSON keys use
snake_case (`book_id`, `order_id`, `warehouse_id`, `grand_total`, ...) to match
the shared React frontend and the Python/Go implementations.

## Layout

```
docker-compose/
├── docker-compose.yml
├── .env.example
├── alloy/config.alloy
├── databases/{mysql,postgres}/init.sql
├── frontend/                 # React + Vite + Faro, served by nginx
└── services/                 # three independent Spring Boot Maven projects
    ├── products/             # Spring Web + JdbcTemplate → MySQL
    ├── checkout/             # Spring Web + JdbcTemplate → MySQL, calls shipping
    └── shipping/             # Spring Web + JdbcTemplate → PostgreSQL
```

Each service has its own `pom.xml`, `src/main/java/...`, `application.properties`,
and a multi-stage `Dockerfile` (build: `maven:3.9-eclipse-temurin-21`; runtime:
`eclipse-temurin:21-jre` + the OTel Java agent).
