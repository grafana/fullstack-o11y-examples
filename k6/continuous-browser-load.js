// Continuous browser load-gen for The Observable Bookstore, built to run as a
// scheduled test in Grafana Cloud k6.
//
// Same storefront journey as browser-flow.js (shared in ./lib/journey.js), but
// configured for cloud execution + a recurring schedule: instead of a fixed
// iteration count it drives a constant pool of browser VUs for a bounded
// DURATION each run. Grafana Cloud k6 schedules run hourly at most, so an hourly
// schedule of a ~5m run keeps a steady trickle of full browser journeys — and
// therefore backend traces, DB o11y activity, and Faro frontend telemetry —
// flowing into the stack continuously.
//
// Cloud execution runs on Grafana Cloud load generators, which CANNOT reach
// localhost — set BASE_URL to a publicly reachable host (e.g. your EC2 stack)
// for scheduled/cloud runs. The localhost default is for local iteration only.
//
// Run in the cloud (uploads + executes on cloud infra):
//   K6_CLOUD_TOKEN=... k6 cloud run -e BASE_URL=https://<public-host>:8080 k6/continuous-browser-load.js
// Iterate locally, streaming results to Grafana Cloud k6:
//   K6_CLOUD_TOKEN=... k6 cloud run --local-execution -e BASE_URL=http://localhost:8080 k6/continuous-browser-load.js
// Plain local run (no cloud):
//   k6 run k6/continuous-browser-load.js
//
// After one successful cloud run, set up the recurring schedule in the UI:
//   Testing & synthetics → Performance → Projects → (this test) → Set up a schedule
// (See k6/README.md → "Continuous load via Grafana Cloud k6".)

import { preflight, runJourney } from './lib/journey.js';

const BASE = __ENV.BASE_URL || 'http://localhost:8080';

// Browser VUs cost 10x protocol VU-hours in Grafana Cloud, so keep the pool
// small and lean on the hourly schedule for "continuous" rather than a big fleet.
const VUS = Number(__ENV.VUS) || 3;
const DURATION = __ENV.DURATION || '5m';

export const options = {
  // Grafana Cloud k6 test metadata. projectID selects the project the run (and
  // its schedule) live under; omit K6_PROJECT_ID to use your default project.
  // Set the load zone(s) with K6_LOAD_ZONE (default: Grafana Cloud's default).
  cloud: {
    name: __ENV.K6_TEST_NAME || 'bookstore-continuous-browser',
    projectID: __ENV.K6_PROJECT_ID ? Number(__ENV.K6_PROJECT_ID) : undefined,
    distribution: __ENV.K6_LOAD_ZONE
      ? { primary: { loadZone: __ENV.K6_LOAD_ZONE, percent: 100 } }
      : undefined,
  },
  scenarios: {
    continuous_browser: {
      // constant-vus (not arrival-rate): browser iterations are heavy and
      // variable, so hold a steady pool of concurrent browsers for the window.
      executor: 'constant-vus',
      vus: VUS,
      duration: DURATION,
      options: { browser: { type: 'chromium' } },
    },
  },
  thresholds: {
    // Load-gen, not a gate: allow the odd transient blip so one flaky iteration
    // doesn't mark the whole scheduled run failed, while still catching real
    // breakage (the journey persistently failing its step checks).
    checks: ['rate>0.90'],
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
  });
}
