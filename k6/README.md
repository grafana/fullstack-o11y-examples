# k6 browser load generation

Two entry points drive the **same** full storefront journey (a real headless
browser through the React frontend, exercising the products/checkout/shipping
backends and therefore the SQLCommenter + DB o11y + Faro pipelines). The journey
itself lives once in [`lib/journey.js`](lib/journey.js); both scripts import it:

- [`browser-flow.js`](browser-flow.js) — **local / one-off** runs. A fixed number
  of journeys (`shared-iterations`); good for a quick demo or manual burst.
- [`continuous-browser-load.js`](continuous-browser-load.js) — **continuous load
  via Grafana Cloud k6.** Holds a steady pool of browser VUs for a bounded window
  (`constant-vus`), configured for cloud execution + a recurring schedule. See
  [Continuous load via Grafana Cloud k6](#continuous-load-via-grafana-cloud-k6-scheduled).

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

## Continuous load via Grafana Cloud k6 (scheduled)

[`continuous-browser-load.js`](continuous-browser-load.js) is the same journey
wired for **Grafana Cloud k6**: it runs a steady pool of browser VUs
(`constant-vus`) for a bounded `DURATION`, and carries a `cloud` options block so
it can execute on Grafana Cloud load generators. "Continuous" is achieved by a
**recurring schedule** — Grafana Cloud k6 schedules run hourly at most, so an
hourly schedule of a short run keeps journeys (and their backend traces, DB o11y
activity, and Faro frontend telemetry) trickling in around the clock.

> ⚠️ **Cloud VUs cannot reach `localhost`.** For any cloud-executed or scheduled
> run, set `BASE_URL` to a publicly reachable host (e.g. your EC2 stack). The
> `localhost` default is only for local iteration. `setup()` fails fast with a
> clear message if the target is unreachable.
>
> 💸 **Browser VUs cost ~10× protocol VU-hours** in Grafana Cloud. Keep `VUS`
> small (default `3`) and lean on the schedule frequency for volume.

### 1. Authenticate the k6 CLI

Grab a token from **Testing & synthetics → Performance → Settings → Access**
(personal or stack token), then either:

```bash
k6 cloud login --token <TOKEN> --stack https://<your-stack>.grafana.net
# or per-command:
export K6_CLOUD_TOKEN=<TOKEN>
```

### 2. Run it once in the cloud (required before scheduling)

`k6 cloud run` uploads the script and executes it on Grafana Cloud infrastructure.
A test must have run in the cloud at least once before it can be scheduled.

```bash
# projectID selects the project; omit to use your default project.
k6 cloud run \
  -e BASE_URL=https://<public-host>:8080 \
  -e K6_PROJECT_ID=<project-id> \
  k6/continuous-browser-load.js
```

Iterate faster with local execution that still streams results to Grafana Cloud:

```bash
k6 cloud run --local-execution -e BASE_URL=http://localhost:8080 k6/continuous-browser-load.js
```

### 3. Set up the recurring schedule

This section documents the **UI** path:

1. **Testing & synthetics → Performance → Projects**
2. Open the project, select the **bookstore-continuous-browser** test
3. **Set up a schedule** → choose **Hourly** (most frequent) for near-continuous
   load; set a start time and, optionally, an end date / run count
4. **Add schedule**

> Schedules are stored in **UTC** and don't adjust for DST.

For automation (GitOps/CI), Grafana Cloud k6 also exposes a **Schedules REST API**
(`GET`/`POST https://api.k6.io/cloud/v6/load_tests/{id}/schedule`, auth via
`Authorization: Bearer <token>` + `X-Stack-Id`) — see the
[Cloud REST API › Schedules](https://grafana.com/docs/grafana-cloud/testing/k6/reference/cloud-rest-api/schedules/)
reference.

### Options (env vars)

| Var             | Default                          | Meaning |
| --------------- | -------------------------------- | ------- |
| `BASE_URL`      | `http://localhost:8080`          | Frontend base URL (**must be public for cloud runs**) |
| `VUS`           | `3`                              | Concurrent browser VUs held for the window |
| `DURATION`      | `5m`                             | How long each run drives load |
| `K6_PROJECT_ID` | *(default project)*              | Grafana Cloud k6 project ID for the run/schedule |
| `K6_TEST_NAME`  | `bookstore-continuous-browser`   | Test name shown/grouped in the k6 Cloud UI |
| `K6_LOAD_ZONE`  | *(Cloud default)*                | Load zone, e.g. `amazon:us:ashburn` |
| `INJECT_ERRORS` | *(off)*                          | Also inject a PostgreSQL error per iteration (see below) |
| `FLUSH_WAIT`    | `8`                              | Seconds to dwell so Faro flushes before the page closes |

### Data growth on long-running schedules

Every journey places a **real order**, and the `/orders` page then loads a
customer's *entire* order history and fans out one shipping lookup per order
before the warehouse column resolves. Over days of hourly runs the 10 seeded
customers accumulate orders, so the order-review step does progressively more
work and the per-run load stops being flat. Two mitigations:

- **In the script** (already done): the warehouse assertion uses a bounded
  `waitForFunction` poll rather than a fixed sleep, so step 4 stays reliable as
  histories grow (it no longer races a fixed 2s wait against N shipping fetches).
- **Reset the seed data periodically** to keep the load profile steady — for the
  docker-compose stacks, recreate the databases (which re-run the seed scripts):

  ```bash
  cd <stack>/docker-compose
  docker compose down -v && docker compose up -d --build   # -v drops the DB volumes
  ```

  Schedule this (e.g. weekly) alongside the k6 schedule for a demo environment
  that's meant to run unattended.

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
