# nodejs

Node.js implementation of the bookstore reference app. **Fully implemented.**

- [`docker-compose/`](./docker-compose) — runnable stack: React storefront + three
  Express services + MySQL + PostgreSQL + Grafana Alloy.
- [`k8s/`](./k8s) — full manifests (Deployments/StatefulSets, Services, ConfigMaps, Secrets).

## Stack

- **Backends** (products / checkout / shipping): [Express](https://expressjs.com/)
  on Node 22, one shared npm project under `docker-compose/services`.
- **DB / SQLCommenter**: the OpenTelemetry `mysql2` and `pg` instrumentations run
  with `addSqlCommenterCommentToQueries: true`, so every statement carries the
  active W3C traceparent as a SQL comment
  ([`services/common/otel.js`](docker-compose/services/common/otel.js)).
- **MySQL driver**: `mysql2`. **Postgres driver**: `pg`.
- **OpenTelemetry**: `@opentelemetry/sdk-node` +
  `@opentelemetry/exporter-trace-otlp-grpc` with `instrumentation-http`,
  `-express`, `-mysql2`, `-pg` → `alloy:4317`. Loaded via
  `node -r ./common/otel.js` so the SDK patches modules before they load.
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
