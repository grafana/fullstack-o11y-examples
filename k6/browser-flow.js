// k6 browser load-gen for The Observable Bookstore frontend.
//
// Drives a full storefront journey against the running stack:
//   1. Log in            (/login  — mock login, pick a seeded customer)
//   2. Add a book to cart (/books)
//   3. Go to cart + check out (/cart → order confirmation)
//   4. Review orders     (/orders)
//   5. Log out           (back to /login)
//
// The app is a React SPA (React Router), so most steps are client-side route
// changes — we wait on target elements, not full-page navigations.
//
// Run (full stack must be up: frontend on :8080 + products/checkout/shipping):
//   k6 run k6/browser-flow.js
//   k6 run -e BASE_URL=http://localhost:8080 -e VUS=5 -e ITERATIONS=50 k6/browser-flow.js
//   K6_BROWSER_HEADLESS=false k6 run k6/browser-flow.js   # watch it drive the UI

import { browser } from 'k6/browser';
import { check, sleep } from 'k6';
import http from 'k6/http';
import exec from 'k6/execution';

const BASE = __ENV.BASE_URL || 'http://localhost:8080';

export const options = {
  scenarios: {
    checkout_flow: {
      executor: 'shared-iterations',
      vus: Number(__ENV.VUS) || 1,
      iterations: Number(__ENV.ITERATIONS) || 10,
      maxDuration: __ENV.MAX_DURATION || '10m',
      options: { browser: { type: 'chromium' } },
    },
  },
  thresholds: {
    checks: ['rate==1.0'], // every step assertion must pass
  },
};

// Preflight (runs once, protocol-level — no browser): fail fast with a clear
// message if the stack isn't up, instead of a cryptic per-iteration
// net::ERR_CONNECTION_REFUSED from the browser.
export function setup() {
  let res;
  try {
    res = http.get(`${BASE}/api/products`, { timeout: '5s' });
  } catch (e) {
    res = { status: 0, error: String(e) };
  }
  if (res.status !== 200) {
    exec.test.abort(
      `Cannot reach the bookstore at ${BASE} ` +
        `(GET /api/products -> ${res.status || res.error || 'no response'}). ` +
        `Start the full stack first, e.g.: ` +
        `(cd go/docker-compose && docker compose up -d --build), then re-run.`,
    );
  }
}

export default async function () {
  const page = await browser.newPage();
  try {
    // ── 1. Log in ─────────────────────────────────────────────────────────
    // Mock login: select a seeded customer (id 1–10) and submit — no password.
    // Vary the customer per VU/iteration so the backends see different queries.
    await page.goto(`${BASE}/login`, { waitUntil: 'networkidle' });
    await page.waitForSelector('.login-card', { state: 'visible', timeout: 15000 });

    const customerId = String(((__VU - 1 + __ITER) % 10) + 1);
    await page.locator('.login-card select').selectOption(customerId);
    await page.locator('.login-card button[type="submit"]').click();

    // Login navigates to /books; wait for the catalog to render.
    await page.waitForSelector('.book-card', { state: 'visible', timeout: 20000 });
    const onBooks = await page.locator('.nav a[href="/books"]').isVisible();
    check(onBooks, { '1. logged in — catalog visible': (v) => v === true });
    sleep(1);

    // ── Optional: inject a PostgreSQL error (INJECT_ERRORS=1) ──────────────
    // database_observability_pg_errors_total is a Prometheus counter, so it doesn't
    // exist until PostgreSQL logs its first error — a clean run leaves the DB o11y
    // "PostgreSQL errors" panel showing "No data" instead of 0. When enabled, POST an
    // over-length `state` to the shipping service (shipments.state is VARCHAR(32));
    // PostgreSQL rejects it with SQLSTATE 22001, a real server error the Alloy "logs"
    // collector counts. Protocol-level call — independent of the browser session.
    if (__ENV.INJECT_ERRORS === '1' || __ENV.INJECT_ERRORS === 'true') {
      const res = http.post(
        `${BASE}/api/shipments`,
        JSON.stringify({
          order_id: 900000 + (__VU * 1000 + __ITER),
          customer_name: 'load-test',
          shipping_address: '1 Test St',
          city: 'Testville',
          state: 'INJECTED_ERROR__STATE_VALUE_TOO_LONG_FOR_VARCHAR_32',
          zip: '00000',
        }),
        { headers: { 'Content-Type': 'application/json' }, tags: { name: 'inject_pg_error' } },
      );
      // Expected to be rejected (Go reference: HTTP 500 + PostgreSQL 22001).
      check(res, { 'inject: PostgreSQL error triggered (rejected)': (r) => r.status >= 400 });
    }

    // ── 2. Add a book to the cart ─────────────────────────────────────────
    // Pick a random in-stock book (out-of-stock buttons are disabled).
    const addButtons = await page.$$('.book-card button:not([disabled])');
    check(addButtons, { '2a. in-stock books available': (b) => b.length > 0 });
    const addBtn = addButtons[Math.floor(Math.random() * addButtons.length)];
    await addBtn.click();

    // The nav cart badge ("Cart 🛒 N") should now show a positive count.
    const cartLabel = await page.locator('.nav a[href="/cart"]').textContent();
    check(cartLabel, { '2b. book added to cart': (t) => /🛒\s*[1-9]/.test(t) });
    sleep(1);

    // ── 3. Go to the cart and check out ───────────────────────────────────
    await page.locator('.nav a[href="/cart"]').click();
    await page.waitForSelector('.cart-page .btn-primary', { state: 'visible', timeout: 10000 });
    await page.locator('.cart-page button.btn-primary').click(); // "Pay $X.XX"

    // Checkout POSTs to /api/checkout; success swaps in the confirmation view.
    await page.waitForSelector('.confirmation', { state: 'visible', timeout: 20000 });
    const confirmText = await page.locator('.confirmation h2').textContent();
    check(confirmText, { '3. order confirmed': (t) => t.includes('Order confirmed') });
    sleep(1);

    // ── 4. Review orders (with warehouse location from Postgres shipments) ─
    await page.locator('.nav a[href="/orders"]').click();
    // Seeded customers always have prior orders, plus the one just placed.
    await page.waitForSelector('.orders-table tbody tr', { state: 'visible', timeout: 20000 });
    const orderRows = await page.$$('.orders-table tbody tr');
    check(orderRows, { '4a. orders listed': (r) => r.length >= 1 });

    // The Warehouse column (6th cell) is filled in per-order from the shipments
    // table in PostgreSQL (via the shipping service). Let those fetches resolve,
    // then confirm a real location rendered — not the "…"/"—" placeholder. A real
    // "Name — City, State" label contains a comma; the placeholders don't.
    sleep(2);
    const warehouseCells = await page.$$('.orders-table tbody tr td:nth-child(6)');
    const warehouseTexts = [];
    for (const c of warehouseCells) warehouseTexts.push((await c.textContent()).trim());
    check(warehouseTexts, {
      '4b. warehouse location shown from Postgres': (t) => t.some((x) => x.includes(',')),
    });
    sleep(1);

    // ── 5. Log out ────────────────────────────────────────────────────────
    await page.locator('.user button').click(); // "Log out"
    await page.waitForSelector('.login-card', { state: 'visible', timeout: 10000 });
    const backToLogin = await page.locator('.login-card').isVisible();
    check(backToLogin, { '5. logged out — back to login': (v) => v === true });

    // ── Flush Faro telemetry before the browser context is destroyed ───────
    // Faro batches web events + OpenTelemetry spans and flushes them on a timer
    // (a few seconds) and on page unload. k6's page.close() below is immediate and
    // doesn't reliably fire the pagehide/visibilitychange lifecycle Faro uses to
    // flush-on-exit, so without this the journey's tail HTTP activities + traces
    // sit in the batch buffer and never reach Grafana Cloud Frontend Observability.
    // Force an OTel flush, nudge the visibility/beacon path, then dwell past the
    // batch interval so everything is transmitted.
    await page.evaluate(async () => {
      try {
        await globalThis.faro?.api?.getOTEL?.()?.trace?.getTracerProvider?.()?.forceFlush?.();
      } catch (_e) {
        /* best-effort — force-flush is not always exposed via the API provider */
      }
      try {
        Object.defineProperty(document, 'visibilityState', { value: 'hidden', configurable: true });
        document.dispatchEvent(new Event('visibilitychange'));
      } catch (_e) {
        /* best-effort */
      }
    });
    sleep(Number(__ENV.FLUSH_WAIT) || 8); // > Faro/OTel batch interval, so the buffer flushes
  } finally {
    await page.close();
  }
}
