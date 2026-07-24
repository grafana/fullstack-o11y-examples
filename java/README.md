# java

Java implementation of the bookstore reference app. **Fully implemented.**

- [`docker-compose/`](./docker-compose) — runnable stack: React storefront + three
  Spring Boot (Java 21) services + MySQL + PostgreSQL + Grafana Alloy.
- [`k8s/`](./k8s) — full manifests (Deployments/StatefulSets, Services, ConfigMaps, Secrets).

## Stack

- **Backends** (products / checkout / shipping): **Spring Boot 3.3** on **Java 21**,
  Spring Web + `spring-boot-starter-jdbc` (`JdbcTemplate`). Each is an independent
  Maven project under `docker-compose/services/<svc>`.
- **DB / SQLCommenter**: every SQL statement is passed through a small
  `SqlCommenter.annotate(...)` helper that appends a Google
  [SQLCommenter](https://google.github.io/sqlcommenter/) comment carrying the
  active W3C `traceparent` (read from `io.opentelemetry.api.trace.Span.current()`),
  so statements carry the trace context for trace↔SQL correlation.
- **MySQL driver**: `com.mysql:mysql-connector-j` (caching_sha2 / MySQL 9).
  **Postgres driver**: `org.postgresql:postgresql` (Postgres 18).
- **OpenTelemetry**: the **OTel Java agent** (`-javaagent:opentelemetry-javaagent.jar`)
  auto-instruments Spring MVC, JDBC, and outbound HTTP, exporting OTLP
  (`http/protobuf`, the agent's default since 2.x) to `alloy:4318`; service
  name is set per service via `OTEL_SERVICE_NAME`.
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
