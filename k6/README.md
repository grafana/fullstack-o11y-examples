# k6 browser load generation

[`browser-flow.js`](browser-flow.js) drives a full storefront journey through the
React frontend with a real (headless) browser, exercising the products, checkout,
and shipping backends — and therefore the SQLCommenter + DB o11y pipelines.

Flow per iteration:

1. **Log in** — `/login` (mock login; picks a seeded customer 1–10, no password)
2. **Add a book to cart** — `/books` (random in-stock book)
3. **Check out** — `/cart` → “Pay” → order confirmation
4. **Review orders** — `/orders` (asserts the per-order **Warehouse** location, which the page pulls from the Postgres `shipments` table via the shipping service)
5. **Log out** — back to `/login`

Each step has a `check`; the `checks: ['rate==1.0']` threshold fails the run if any
step breaks. Works against any language stack — they all serve the same frontend on
`:8080`.

## Prerequisites

- **The full stack must be running** (frontend + products/checkout/shipping + DBs),
  not just the databases:

  ```bash
  cd ../go/docker-compose      # or python/ nodejs/ java/ ruby/
  docker compose up -d --build
  curl -sf http://localhost:8080/api/products >/dev/null && echo "stack ready"
  ```

- **Chrome or Chromium installed.** k6's browser module drives it. On macOS with
  Google Chrome, point k6 at it:

  ```bash
  export K6_BROWSER_EXECUTABLE_PATH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  ```

- **Frontend built with `VITE_FARO_ENDPOINT`** — required for the browser journeys
  to show up in Grafana Cloud **Frontend Observability** (sessions, HTTP activities,
  and traces). The frontend's Faro SDK only initializes when this build arg is set to
  your Alloy `faro.receiver` (or Cloud collector) URL; otherwise it logs
  `[faro] disabled` and the journeys run but emit **no** frontend telemetry. Set it
  in the stack's `.env` (`VITE_FARO_ENDPOINT=...`) and rebuild the `frontend` image.

  > Faro batches events/traces and flushes on a timer + on page unload. Because k6
  > closes the page immediately, the script force-flushes Faro and dwells
  > (`FLUSH_WAIT`, default 8s) at the end of each journey so the tail activities and
  > traces actually reach Grafana Cloud.

## Run

```bash
# one journey
k6 run k6/browser-flow.js

# sustained load: 5 concurrent users, 50 journeys total
k6 run -e VUS=5 -e ITERATIONS=50 k6/browser-flow.js

# point at a different host
k6 run -e BASE_URL=http://localhost:8080 k6/browser-flow.js

# watch it drive the UI (headful)
K6_BROWSER_HEADLESS=false k6 run k6/browser-flow.js
```

### Options (env vars)

| Var           | Default              | Meaning                          |
| ------------- | -------------------- | -------------------------------- |
| `BASE_URL`    | `http://localhost:8080` | Frontend base URL             |
| `VUS`         | `1`                  | Concurrent virtual users (browsers) |
| `ITERATIONS`  | `10`                 | Total journeys across all VUs    |
| `MAX_DURATION`| `10m`                | Hard cap on the scenario         |
| `FLUSH_WAIT`  | `8`                  | Seconds to dwell after logout so Faro flushes its batched activities/traces before the page closes |

> Each VU is a full browser — browser tests are heavy, so scale `VUS` with an eye
> on local CPU/RAM rather than pushing it like a protocol-level test.

## Populate the DB o11y "PostgreSQL errors" panel (`INJECT_ERRORS`)

`database_observability_pg_errors_total` is a Prometheus **counter**, so it doesn't
exist until PostgreSQL logs its first error. On a clean run the Database
Observability **PostgreSQL errors** panel therefore shows **"No data"** rather than
`0`. To light it up during a demo, enable error injection:

```bash
k6 run -e INJECT_ERRORS=1 k6/browser-flow.js
```

Each iteration then POSTs an over-length `state` to the shipping service
(`shipments.state` is `VARCHAR(32)`), which PostgreSQL rejects with **SQLSTATE
`22001`** — a real server error the Alloy `"logs"` collector parses into
`database_observability_pg_errors_total`. It's **off by default** so normal load
stays clean.

> Verified on the Go stack (HTTP 500 + a `22001` PostgreSQL server-log line, counted
> into the metric). The `shipments` schema is shared across all five languages; a
> backend that validates field length before insert would reject it at the app layer
> instead, so confirm the panel actually populates for your stack.
