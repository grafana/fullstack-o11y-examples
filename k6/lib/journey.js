// Shared storefront journey for the k6 browser scripts.
//
// Both browser-flow.js (one-off / local sustained runs) and
// continuous-browser-load.js (scheduled Grafana Cloud k6 runs) drive the exact
// same flow, so it lives here once to avoid drift:
//   1. Log in            (/login  — mock login, pick a seeded customer)
//   2. Add a book to cart (/books)
//   3. Go to cart + check out (/cart → order confirmation)
//   4. Review orders     (/orders — asserts warehouse location from Postgres)
//   5. Log out           (back to /login)
//
// The app is a React SPA (React Router), so most steps are client-side route
// changes — we wait on target elements, not full-page navigations.

import { browser } from 'k6/browser';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';
import http from 'k6/http';
import exec from 'k6/execution';

// One sample per iteration: true only if the journey ran to completion, false if
// any browser op threw. The `checks` threshold only counts checks that actually
// execute, so an exception after an early passing check would otherwise leave a
// scheduled run green with zero completed journeys. Threshold this in each script.
export const journeySuccess = new Rate('journey_success');

// preflight runs once (protocol-level — no browser): fail fast with a clear
// message if the stack isn't reachable, instead of a cryptic per-iteration
// net::ERR_CONNECTION_REFUSED from the browser. On cloud execution this runs on
// the cloud load generator, so a localhost BASE will (correctly) abort here —
// point BASE_URL at a publicly reachable host for scheduled cloud runs.
export function preflight(base) {
  let res;
  try {
    res = http.get(`${base}/api/products`, { timeout: '5s' });
  } catch (e) {
    res = { status: 0, error: String(e) };
  }
  if (res.status !== 200) {
    exec.test.abort(
      `Cannot reach the bookstore at ${base} ` +
        `(GET /api/products -> ${res.status || res.error || 'no response'}). ` +
        `Start the full stack (e.g. cd go/docker-compose && docker compose up -d --build), ` +
        `and for cloud runs set BASE_URL to a publicly reachable host — ` +
        `Grafana Cloud load generators cannot reach localhost.`,
    );
  }
}

// injectPgError POSTs an over-length `state` to the shipping service
// (shipments.state is VARCHAR(32)); PostgreSQL rejects it with SQLSTATE 22001, a
// real server error the Alloy "logs" collector counts into
// database_observability_pg_errors_total (a counter that shows "No data" until
// its first error). Protocol-level — independent of the browser session.
function injectPgError(base) {
  const res = http.post(
    `${base}/api/shipments`,
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
  check(res, { 'inject: PostgreSQL error triggered (rejected)': (r) => r.status >= 400 });
}

// flushFaro force-flushes batched Faro web events + OpenTelemetry spans before
// the browser context is destroyed. Faro flushes on a timer and on page unload;
// k6's page.close() is immediate and doesn't reliably fire the lifecycle Faro
// uses, so the journey's tail activities/traces would otherwise never reach
// Grafana Cloud Frontend Observability. Force an OTel flush, nudge the
// visibility/beacon path, then dwell past the batch interval.
async function flushFaro(page, flushWait) {
  await page.evaluate(async () => {
    try {
      await globalThis.faro?.api?.getOTEL?.()?.trace?.getTracerProvider?.()?.forceFlush?.();
    } catch (_e) {
      /* best-effort — force-flush is not always exposed via the API provider */
    }
    try {
      // Nudge both lifecycle events Faro transports may flush on — we can't be
      // sure which the deployed build listens on (visibilitychange, pagehide,
      // or both), so fire both.
      Object.defineProperty(document, 'visibilityState', { value: 'hidden', configurable: true });
      document.dispatchEvent(new Event('visibilitychange'));
      window.dispatchEvent(new Event('pagehide'));
    } catch (_e) {
      /* best-effort */
    }
  });
  sleep(flushWait);
}

// ── 1. Log in ─────────────────────────────────────────────────────────────
// Mock login: select a seeded customer (id 1–10) and submit — no password.
// Vary the customer per VU/iteration so the backends see different queries.
async function stepLogin(page, base, expectFaro) {
  await page.goto(`${base}/login`, { waitUntil: 'networkidle' });
  await page.waitForSelector('.login-card', { state: 'visible', timeout: 15000 });

  // Detect whether the frontend's Faro Web SDK initialized (the frontend leaves
  // window.faro undefined when VITE_FARO_ENDPOINT is unset — see
  // frontend/src/faro.js). Always log when it's missing, so a run that captures
  // no frontend telemetry says so instead of failing silently in flushFaro; and
  // when the run expects Faro, additionally hard-fail via a check.
  const faroLoaded = await page.evaluate(() => typeof globalThis.faro !== 'undefined');
  if (!faroLoaded) {
    console.log(
      `[faro] Web SDK did not initialize on ${base} — no frontend telemetry will ` +
        `be captured (VITE_FARO_ENDPOINT unset, wrong build, CSP, or unreachable collector).`,
    );
  }
  if (expectFaro) {
    check(faroLoaded, { 'faro: web SDK initialized on page': (v) => v === true });
  }

  const customerId = String(((__VU - 1 + __ITER) % 10) + 1);
  await page.locator('.login-card select').selectOption(customerId);
  await page.locator('.login-card button[type="submit"]').click();

  // Login navigates to /books; wait for the catalog to render.
  await page.waitForSelector('.book-card', { state: 'visible', timeout: 20000 });
  const onBooks = await page.locator('.nav a[href="/books"]').isVisible();
  check(onBooks, { '1. logged in — catalog visible': (v) => v === true });
  sleep(1);
}

// ── 2. Add a book to the cart ───────────────────────────────────────────────
async function stepAddToCart(page) {
  // Pick a random in-stock book (out-of-stock buttons are disabled).
  const addButtons = await page.$$('.book-card button:not([disabled])');
  check(addButtons, { '2a. in-stock books available': (b) => b.length > 0 });
  const addBtn = addButtons[Math.floor(Math.random() * addButtons.length)];
  await addBtn.click();

  // The nav cart badge ("Cart 🛒 N") should now show a positive count.
  const cartLabel = await page.locator('.nav a[href="/cart"]').textContent();
  check(cartLabel, { '2b. book added to cart': (t) => /🛒\s*[1-9]/.test(t) });
  sleep(1);
}

// ── 3. Go to the cart and check out ─────────────────────────────────────────
async function stepCheckout(page) {
  await page.locator('.nav a[href="/cart"]').click();
  await page.waitForSelector('.cart-page .btn-primary', { state: 'visible', timeout: 10000 });
  await page.locator('.cart-page button.btn-primary').click(); // "Pay $X.XX"

  // Checkout POSTs to /api/checkout; success swaps in the confirmation view.
  await page.waitForSelector('.confirmation', { state: 'visible', timeout: 20000 });
  const confirmText = await page.locator('.confirmation h2').textContent();
  check(confirmText, { '3. order confirmed': (t) => t.includes('Order confirmed') });
  sleep(1);
}

// ── 4. Review orders (warehouse location comes from Postgres shipments) ──────
async function stepReviewOrders(page) {
  await page.locator('.nav a[href="/orders"]').click();
  // Seeded customers always have prior orders, plus the one just placed.
  await page.waitForSelector('.orders-table tbody tr', { state: 'visible', timeout: 20000 });
  const orderRows = await page.$$('.orders-table tbody tr');
  check(orderRows, { '4a. orders listed': (r) => r.length >= 1 });

  // The Warehouse column (6th cell) is filled per-order from the Postgres
  // shipments table (via the shipping service). Wait — bounded, not a fixed
  // sleep — until at least one cell resolves to a real "Name — City, State"
  // label (contains a comma) rather than the "…"/"—" placeholder. A bounded
  // poll keeps this step steady even as a customer's order history grows over
  // long scheduled runs (see the README note on resetting seed data); a fixed
  // sleep would get flaky as /orders fans out more per-order shipping fetches.
  const warehouseResolved = await page
    .waitForFunction(
      "Array.from(document.querySelectorAll('.orders-table tbody tr td:nth-child(6)'))" +
        ".some((c) => c.textContent.includes(','))",
      { polling: 500, timeout: 15000 },
    )
    .then(() => true)
    .catch(() => false);
  check(warehouseResolved, { '4b. warehouse location shown from Postgres': (v) => v === true });
  sleep(1);
}

// ── 5. Log out ──────────────────────────────────────────────────────────────
async function stepLogout(page) {
  await page.locator('.user button').click(); // "Log out"
  await page.waitForSelector('.login-card', { state: 'visible', timeout: 10000 });
  const backToLogin = await page.locator('.login-card').isVisible();
  check(backToLogin, { '5. logged out — back to login': (v) => v === true });
}

// runJourney executes one full storefront journey in a fresh browser page.
// opts: { base, injectErrors, flushWait, expectFaro }.
export async function runJourney({ base, injectErrors, flushWait, expectFaro }) {
  const page = await browser.newPage();
  try {
    await stepLogin(page, base, expectFaro);
    if (injectErrors) injectPgError(base);
    await stepAddToCart(page);
    await stepCheckout(page);
    await stepReviewOrders(page);
    await stepLogout(page);
    await flushFaro(page, flushWait);
    journeySuccess.add(true);
  } catch (e) {
    // Record the failed iteration for the journey_success threshold, then
    // re-throw so k6 still logs the underlying browser error.
    journeySuccess.add(false);
    throw e;
  } finally {
    await page.close();
  }
}
