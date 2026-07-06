# ruby

Ruby implementation of the bookstore reference app. **Fully implemented.**

- [`docker-compose/`](./docker-compose) — runnable stack: React storefront + three
  Sinatra + Sequel services + MySQL + PostgreSQL + Grafana Alloy.
- [`k8s/`](./k8s) — full manifests (Deployments/StatefulSets, Services, ConfigMaps, Secrets).

## Stack

- **Backends** (products / checkout / shipping): [Sinatra](https://sinatrarb.com/)
  (modular apps) on Puma, one shared `Gemfile` under `docker-compose/services`.
- **ORM / SQLCommenter**: [Sequel](https://github.com/jeremyevans/sequel). A custom
  Sequel database extension (`common/sqlcommenter.rb`) appends a SQLCommenter
  comment carrying the active W3C `traceparent`
  (`OpenTelemetry::Trace.current_span.context` → hex trace_id/span_id) to every
  SQL statement.
- **MySQL driver**: `mysql2` (supports MySQL 9 caching_sha2).
  **Postgres driver**: `pg` (Postgres 18).
- **DB spans**: the `opentelemetry-instrumentation-mysql2` and `-pg` instrumentations
  create a span per query with the SQL as the **`db.statement`** attribute (Sequel
  runs on those client gems).
- **OpenTelemetry**: `opentelemetry-sdk` + `opentelemetry-exporter-otlp` +
  Faraday/mysql2/pg instrumentation → `alloy:4317`, plus a small Rack middleware for
  server spans. The checkout→shipping call uses Faraday, which propagates trace
  context via the `traceparent` header.
- **Frontend**: shared React storefront (identical to the Python reference).

## Quick start

```bash
cd docker-compose
cp .env.example .env      # fill in Grafana Cloud values
docker compose up --build # storefront → http://localhost:8080
```

See [`docker-compose/README.md`](./docker-compose/README.md) for details and
[`../python/docker-compose/README.md`](../python/docker-compose/README.md) for
the shared HTTP API contract and database schema/seed data.
