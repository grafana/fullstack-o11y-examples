// Shared OpenTelemetry + SQLCommenter bootstrap for the bookstore services.
//
// Loaded via `node -r ./common/otel.js <svc>/index.js` so the SDK starts BEFORE
// express and the HTTP layer are instrumented before the service modules load.
//
// Exports OTLP/gRPC (traces) to Grafana Alloy at OTEL_EXPORTER_OTLP_ENDPOINT.
// SQL Server query spans and SQLCommenter comments are created in common/sqlserver.js.
// Each comment carries the active W3C traceparent for trace-to-query correlation.
'use strict';

const { NodeSDK } = require('@opentelemetry/sdk-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');
const { resourceFromAttributes } = require('@opentelemetry/resources');
const { ATTR_SERVICE_NAME } = require('@opentelemetry/semantic-conventions');
const { HttpInstrumentation } = require('@opentelemetry/instrumentation-http');
const { ExpressInstrumentation } = require('@opentelemetry/instrumentation-express');
const { startProfiling } = require('./profiling');

const serviceName = process.env.OTEL_SERVICE_NAME || 'bookstore-service';

const sdk = new NodeSDK({
  resource: resourceFromAttributes({ [ATTR_SERVICE_NAME]: serviceName }),
  traceExporter: new OTLPTraceExporter(),
  instrumentations: [
    new HttpInstrumentation(),
    new ExpressInstrumentation(),
  ],
});

sdk.start();

// Continuous profiling (Pyroscope) — a no-op unless PYROSCOPE_SERVER_ADDRESS is set.
const stopProfiling = startProfiling(serviceName);

process.on('SIGTERM', () => {
  Promise.allSettled([sdk.shutdown(), stopProfiling()]).finally(() => process.exit(0));
});
