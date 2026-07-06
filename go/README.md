# go

Go implementation of the bookstore reference app. **Fully implemented.**

- [`docker-compose/`](./docker-compose) — runnable stack: React storefront + three
  Go (`net/http`) services + MySQL + PostgreSQL + Grafana Alloy.
- [`k8s/`](./k8s) — full manifests (Deployments/StatefulSets, Services, ConfigMaps, Secrets).

## Stack

- **Backends** (products / checkout / shipping): standard-library `net/http`
  (Go 1.22 `ServeMux` routing), one Go module under `docker-compose/services`.
- **DB spans / SQLCommenter**: [`XSAM/otelsql`](https://github.com/XSAM/otelsql)
  creates a span per query with the SQL as `db.statement`, composed with
  [`google/sqlcommenter/go/database/sql`](https://google.github.io/sqlcommenter/go/database_sql/)
  (`EnableTraceparent`) so statements also carry the trace context as a SQL comment.
- **MySQL driver**: `github.com/go-sql-driver/mysql`.
  **Postgres driver**: `github.com/lib/pq`.
- **OpenTelemetry**: `go.opentelemetry.io/otel` + OTLP/gRPC exporters +
  `otelhttp` server/client instrumentation → `alloy:4317`.
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
