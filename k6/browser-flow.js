// k6 browser load-gen for The Observable Bookstore frontend.
//
// Drives a full storefront journey against the running stack (the journey itself
// lives in ./lib/journey.js, shared with continuous-browser-load.js):
//   1. Log in → 2. Add to cart → 3. Check out → 4. Review orders → 5. Log out
//
// Run (full stack must be up: frontend on :8080 + products/checkout/shipping):
//   k6 run k6/browser-flow.js
//   k6 run -e BASE_URL=http://localhost:8080 -e VUS=5 -e ITERATIONS=50 k6/browser-flow.js
//   K6_BROWSER_HEADLESS=false k6 run k6/browser-flow.js   # watch it drive the UI
//   k6 run -e INJECT_ERRORS=1 k6/browser-flow.js          # light up the DB o11y PG-errors panel

import { preflight, runJourney } from './lib/journey.js';

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
    journey_success: ['rate==1.0'], // every iteration must complete (catches thrown journeys)
  },
};

export function setup() {
  preflight(BASE);
}

export default async function () {
  await runJourney({
    base: BASE,
    injectErrors: __ENV.INJECT_ERRORS === '1' || __ENV.INJECT_ERRORS === 'true',
    flushWait: Number(__ENV.FLUSH_WAIT) || 8,
    // Faro is optional for local runs — opt in with EXPECT_FARO=1 to hard-fail
    // if the frontend's Faro SDK didn't initialize.
    expectFaro: __ENV.EXPECT_FARO === '1' || __ENV.EXPECT_FARO === 'true',
  });
}
