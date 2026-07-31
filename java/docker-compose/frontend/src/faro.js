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

// Grafana Faro for frontend observability, via @grafana/faro-react. Initializes as
// a side effect so this module can be the first import in main.jsx — capturing
// errors from the moment the app loads. The Grafana Cloud collector URL embeds the
// app key as its final path segment, so no separate apiKey is needed.
//
// ReactIntegration adds React Router v6 instrumentation (route-templated page views
// via <FaroRoutes>) and backs the <FaroErrorBoundary>. TracingInstrumentation
// propagates W3C traceparent on same-origin /api calls, linking browser spans to
// the backend service + SQL spans in one distributed trace.
const url = import.meta.env.VITE_FARO_ENDPOINT;

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
      new ReactIntegration({
        router: {
          version: ReactRouterVersion.V6,
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
