# Continuous profiling (Pyroscope) bootstrap for the bookstore services.
#
# Opt-in via PYROSCOPE_SERVER_ADDRESS (set in docker-compose.yml, pointing at
# Alloy's pyroscope.receive_http on :9999). When unset, this is a no-op so other
# consumers of the same images (e.g. ruby/k8s) are unaffected. The pyroscope gem
# runs an in-process rbspy-based CPU sampler (native Rust extension, precompiled
# for linux) and pushes pprof profiles to the configured server.
module Common
  module Profiling
    # Start the Pyroscope agent, keyed by PYROSCOPE_APPLICATION_NAME (must match
    # the OTel service name so profiles correlate with traces on service_name).
    def self.configure(service_name)
      server = ENV["PYROSCOPE_SERVER_ADDRESS"].to_s
      if server.empty?
        warn "profiling: PYROSCOPE_SERVER_ADDRESS not set, Pyroscope disabled"
        return
      end
      require "pyroscope"
      Pyroscope.configure do |c|
        c.application_name = ENV.fetch("PYROSCOPE_APPLICATION_NAME", service_name)
        c.server_address   = server
        c.tags             = { "service_namespace" => "bookstore" }
      end
    end

    # Span profiles: label profiles recorded during local root spans with the
    # span's id (profile_id label) and stamp the span with pyroscope.profile.id,
    # powering the traces-to-profiles link in Grafana Cloud. Registered on the
    # tracer provider after Common::Otel.configure has installed the SDK; a
    # no-op whenever the Pyroscope agent itself is disabled.
    def self.add_span_processor(service_name)
      return if ENV["PYROSCOPE_SERVER_ADDRESS"].to_s.empty?

      require "pyroscope/otel"
      app_name = ENV.fetch("PYROSCOPE_APPLICATION_NAME", service_name)
      processor = Pyroscope::Otel::SpanProcessor.new("#{app_name}.cpu", ENV["PYROSCOPE_SERVER_ADDRESS"])
      # The push target (Alloy) has no query UI, so skip the profile-URL attribute.
      processor.add_url = false
      ::OpenTelemetry.tracer_provider.add_span_processor(processor)
    end
  end
end
