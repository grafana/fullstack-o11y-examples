// Shared OpenTelemetry + SQLCommenter bootstrap for the bookstore services.
//
// Loaded via `node -r ./common/otel.js <svc>/index.js` so the SDK starts BEFORE
// express/mysql2/pg are required and their instrumentations can patch them.
//
// Exports OTLP/gRPC (traces) to Grafana Alloy at OTEL_EXPORTER_OTLP_ENDPOINT.
// The mysql2 and pg instrumentations run with `addSqlCommenterCommentToQueries:
// true`, so every SQL statement is annotated with a SQLCommenter comment that
// carries the active W3C traceparent (e.g. /*traceparent='00-<trace>-<span>-01'*/)
// — this is what powers trace<->SQL correlation in Grafana Cloud.
'use strict';

const { NodeSDK } = require('@opentelemetry/sdk-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');
const { Resource } = require('@opentelemetry/resources');
const { ATTR_SERVICE_NAME } = require('@opentelemetry/semantic-conventions');
const { HttpInstrumentation } = require('@opentelemetry/instrumentation-http');
const { ExpressInstrumentation } = require('@opentelemetry/instrumentation-express');
const { MySQL2Instrumentation } = require('@opentelemetry/instrumentation-mysql2');
const { PgInstrumentation } = require('@opentelemetry/instrumentation-pg');
const { startProfiling } = require('./profiling');

const serviceName = process.env.OTEL_SERVICE_NAME || 'bookstore-service';

const sdk = new NodeSDK({
  resource: new Resource({ [ATTR_SERVICE_NAME]: serviceName }),
  traceExporter: new OTLPTraceExporter(),
  instrumentations: [
    new HttpInstrumentation(),
    new ExpressInstrumentation(),
    // SQLCommenter: inject the active traceparent into every MySQL statement.
    new MySQL2Instrumentation({ addSqlCommenterCommentToQueries: true }),
    // SQLCommenter: inject the active traceparent into every Postgres statement.
    new PgInstrumentation({ addSqlCommenterCommentToQueries: true }),
  ],
});

sdk.start();

// Continuous profiling (Pyroscope) — a no-op unless PYROSCOPE_SERVER_ADDRESS is set.
startProfiling(serviceName);

process.on('SIGTERM', () => {
  sdk.shutdown().finally(() => process.exit(0));
});
