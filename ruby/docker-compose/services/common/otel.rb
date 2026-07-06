# Shared OpenTelemetry bootstrap for the bookstore services.
#
# Configures OTLP export (traces) to Grafana Alloy, enables Faraday client
# instrumentation (W3C trace-context propagation on the checkout -> shipping call),
# and provides a small Rack middleware that opens a server span per request. That
# span is what SQLCommenter (db.rb) reads to tag SQL with the active traceparent.
require "opentelemetry/sdk"
require "opentelemetry/common"
require "opentelemetry/exporter/otlp"
require "opentelemetry/instrumentation/faraday"
require "opentelemetry/instrumentation/mysql2"
require "opentelemetry/instrumentation/pg"

# Load the DB client libraries up front (before configure runs) so the mysql2/pg
# instrumentations can patch them at install time — Sequel would otherwise load
# them later, after instrumentation setup, leaving DB calls untraced.
require "mysql2"
require "pg"

module Common
  module Otel
    # Install the global tracer provider (OTLP/gRPC endpoint from the shared
    # compose env is HTTP for the Ruby exporter, so redirect :4317 -> :4318).
    def self.configure(service_name)
      redirect_otlp_endpoint
      ::OpenTelemetry::SDK.configure do |c|
        c.service_name = service_name
        c.use "OpenTelemetry::Instrumentation::Faraday"
        # DB spans per query, carrying the SQL as the db.statement attribute.
        c.use "OpenTelemetry::Instrumentation::Mysql2"
        c.use "OpenTelemetry::Instrumentation::PG"
      end
    end

    def self.redirect_otlp_endpoint
      ep = ENV["OTEL_EXPORTER_OTLP_ENDPOINT"]
      return if ep.nil? || ENV["OTEL_EXPORTER_OTLP_TRACES_ENDPOINT"]
      ENV["OTEL_EXPORTER_OTLP_TRACES_ENDPOINT"] = "#{ep.sub(':4317', ':4318').chomp('/')}/v1/traces"
    end

    def self.tracer
      ::OpenTelemetry.tracer_provider.tracer("bookstore")
    end

    # Wraps each request in an active server span so downstream DB queries and
    # outbound Faraday calls share one trace. Extracts upstream context (from
    # nginx / the checkout service) for distributed traces.
    class ServerSpanMiddleware
      def initialize(app)
        @app = app
      end

      def call(env)
        getter = ::OpenTelemetry::Common::Propagation.rack_env_getter
        parent = ::OpenTelemetry.propagation.extract(env, getter: getter)
        name = "#{env['REQUEST_METHOD']} #{env['PATH_INFO']}"
        span = Otel.tracer.start_span(name, with_parent: parent, kind: :server)
        ::OpenTelemetry::Trace.with_span(span) do
          status, headers, body = @app.call(env)
          span.set_attribute("http.status_code", status)
          [status, headers, body]
        end
      ensure
        span&.finish
      end
    end
  end
end
