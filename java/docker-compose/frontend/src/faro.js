import {
  createRoutesFromChildren,
  matchRoutes,
  Routes,
  useLocation,
  useNavigationType,
} from "react-router-dom";
import {
  getWebInstrumentations,
  initializeFaro,
  ReactIntegration,
  ReactRouterVersion,
} from "@grafana/faro-react";
import { TracingInstrumentation } from "@grafana/faro-web-tracing";
import { ReplayInstrumentation } from "@grafana/faro-instrumentation-replay";

// Grafana Faro for frontend observability, via @grafana/faro-react. Initializes as
// a side effect so this module can be the first import in main.jsx — capturing
// errors from the moment the app loads. The Grafana Cloud collector URL embeds the
// app key as its final path segment, so no separate apiKey is needed.
//
// ReactIntegration adds React Router v7 instrumentation (route-templated page views
// via <FaroRoutes>) and backs the <FaroErrorBoundary>. TracingInstrumentation
// propagates W3C traceparent on same-origin /api calls, linking browser spans to
// the backend service + SQL spans in one distributed trace.
//
// Session Replay (ReplayInstrumentation) is opt-in via VITE_SESSION_REPLAY=1 —
// deliberately separate from the VITE_FARO_ENDPOINT switch above, since enabling
// it makes you responsible for disclosing session recording to end users and
// getting any consent required by applicable law. It also requires Session
// Replay to be enabled on your Grafana Cloud stack first (a support enablement
// request, not a code change) before recordings appear. Defaults mask all input
// values and text content client-side before anything leaves the browser; see
// https://grafana.com/docs/grafana-cloud/observe-and-act/monitor-applications/session-replay/
// before loosening that (or enabling this at all) in production.
const url = import.meta.env.VITE_FARO_ENDPOINT;
const sessionReplayEnabled = import.meta.env.VITE_SESSION_REPLAY === "1";

if (!url || url.includes("<")) {
  console.info("[faro] disabled — set VITE_FARO_ENDPOINT to your Grafana Cloud collector URL to enable");
} else {
  initializeFaro({
    url,
    app: {
      name: "bookstore-frontend",
      version: "1.0.0",
      environment: import.meta.env.VITE_ASSERTS_ENV || "dev", // deployment_environment / asserts_env
    },
    instrumentations: [
      ...getWebInstrumentations(),
      new TracingInstrumentation(),
      ...(sessionReplayEnabled ? [new ReplayInstrumentation({ inlineStylesheet: true })] : []),
      new ReactIntegration({
        router: {
          version: ReactRouterVersion.V7,
          dependencies: {
            createRoutesFromChildren,
            matchRoutes,
            Routes,
            useLocation,
            useNavigationType,
          },
        },
      }),
    ],
    // Filter harmless browser noise so it doesn't drown out real errors.
    ignoreErrors: [
      /^ResizeObserver loop limit exceeded$/,
      /^ResizeObserver loop completed with undelivered notifications$/,
      /^Script error\.$/,
      /chrome-extension:\/\//,
      /moz-extension:\/\//,
    ],
  });
}
