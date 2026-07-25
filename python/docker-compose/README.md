# python / docker-compose — Observable Bookstore

Fully implemented reference stack: a React storefront + three Flask/SQLAlchemy
backend services + MySQL + PostgreSQL + Grafana Alloy, instrumented with
**SQLCommenter + OpenTelemetry** and exporting to **Grafana Cloud**.

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
fill in `.env` to see traces/metrics/logs. Faro is disabled until
`VITE_FARO_*` are set.

## Observability

- Each backend runs OpenTelemetry auto-instrumentation (Flask, requests,
  SQLAlchemy) configured in [`services/common/otel_setup.py`](services/common/otel_setup.py).
- SQLAlchemy is instrumented with `enable_commenter=True`, so every SQL
  statement is annotated with **SQLCommenter** tags carrying the active trace
  context — enabling trace↔SQL correlation in Grafana Cloud.
- A checkout produces one distributed trace: **browser (Faro) → checkout →
  MySQL** and **→ shipping → PostgreSQL**.
- **Continuous profiling (Pyroscope)**: each service starts the
  [Pyroscope Python SDK](https://grafana.com/docs/pyroscope/latest/configure-client/language-sdks/python/)
  (`pyroscope-io`, a py-spy-derived in-process sampling CPU profiler) in
  [`services/common/pyroscope_setup.py`](services/common/pyroscope_setup.py).
  Both gunicorn workers run the sampler and push under the same application
  name; Pyroscope aggregates them server-side, so flame graphs show the
  service, not individual processes.
  Profiling is opt-in via `PYROSCOPE_SERVER_ADDRESS` in `docker-compose.yml`
  (`x-pyroscope-env`); when it is unset the init logs one line and does nothing,
  so consumers of the same images that don't configure profiling (e.g.
  [`../k8s`](../k8s)) are unaffected. When enabled, the `pyroscope-otel` span
  processor (added to the tracer provider in `otel_setup.py`) labels profile
  samples recorded during local root spans with `span_id`, `span_name`, and
  `trace_id`, linking traces to profiles ("Flame graph" tab on a span; uses the
  Tempo datasource's traces-to-profiles link, preconfigured in Grafana Cloud).
  The `trace_id` profile label needs a Pyroscope server ≥ v2.0.3 (Grafana Cloud
  qualifies). Profiles are pushed to Alloy (`pyroscope.receive_http` on
  `alloy:9999`) and forwarded to Grafana Cloud Profiles (`GCLOUD_PYROSCOPE_*` in
  `.env`). `PYROSCOPE_APPLICATION_NAME` matches the OTel service name so
  profiles and traces correlate on `service_name`.
- All OTLP + Faro data flows through **Grafana Alloy** ([`alloy/config.alloy`](alloy/config.alloy))
  to Grafana Cloud (Tempo / Prometheus / Loki / Pyroscope).

## HTTP API contract

Every language implementation must expose the same routes (single origin via nginx):

| Method & path | Service | Purpose |
|---------------|---------|---------|
| `GET /api/products` | products | List all books |
| `GET /api/products/{id}` | products | One book |
| `POST /api/checkout` | checkout | Body `{customer_id, items:[{book_id, quantity}]}` → order + mock payment + shipment |
| `GET /api/orders?customer_id={id}` | checkout | A customer's past orders (with book title) — powers the "My Orders" page |
| `GET /api/orders/{id}` | checkout | One order |
| `POST /api/shipments` | shipping | Create a shipment for an order (chooses warehouse) |
| `GET /api/shipping/{order_id}` | shipping | Shipment + warehouse for an order |
| `GET /health` | all | Liveness probe |

## Database schema & seed data

**MySQL (`bookstore`)** — [`databases/mysql/init.sql`](databases/mysql/init.sql):

- `books_inventory` — 20 unique titles (title, author, isbn, genre, price, stock_quantity)
- `customers` — 10 customers with names + shipping addresses (5 western, 5 eastern)
- `orders` — 100 rows (10 per customer)

**PostgreSQL (`shipping`)** — [`databases/postgres/init.sql`](databases/postgres/init.sql):

- `warehouses` — 2 locations: **California** (West Coast) and **New York** (East Coast)
- `shipments` — 1 per order, mapping order → warehouse → customer shipping address.
  Western customers ship from California, eastern from New York.

## Storefront pages

The React app (shared by every language) uses React Router with a mock login
(no password — pick one of the 10 seeded customers, persisted in `localStorage`):

| Route | Page | Notes |
|-------|------|-------|
| `/login` | Log in | Select a seeded customer to enter the store |
| `/books` | Browse | Catalog from `GET /api/products`; add to cart |
| `/cart` | Cart & checkout | Review cart, pay (mock) via `POST /api/checkout` as the logged-in customer |
| `/orders` | My Orders | Past orders from `GET /api/orders?customer_id=…` |

Everything but `/login` is behind an auth guard that redirects to `/login`.

## Layout

```
docker-compose/
├── docker-compose.yml
├── .env.example
├── alloy/config.alloy
├── databases/{mysql,postgres}/init.sql
├── frontend/            # React + Vite + Faro, served by nginx
└── services/
    ├── common/              # otel_setup.py + pyroscope_setup.py (shared bootstrap)
    ├── products/        # Flask + SQLAlchemy → MySQL
    ├── checkout/        # Flask + SQLAlchemy → MySQL, calls shipping
    └── shipping/        # Flask + SQLAlchemy → PostgreSQL
```
