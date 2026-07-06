# SQLCommenter for Sequel: appends a SQLCommenter comment carrying the active
# W3C traceparent to every SQL statement, enabling trace<->SQL correlation.
#
# The comment is built from the current OpenTelemetry span context
# (OpenTelemetry::Trace.current_span.context -> hex trace_id/span_id), e.g.:
#   SELECT ... /*traceparent='00-<traceid>-<spanid>-01'*/
require "opentelemetry"
require "cgi"

module Common
  # Sequel Database extension. Enable with: db.extension(:sqlcommenter)
  module SQLCommenter
    # SQLCommenter values are URL-encoded then single-quoted (per the spec).
    def self.serialize(key, value)
      "#{CGI.escape(key.to_s)}='#{CGI.escape(value.to_s).gsub("'", "\\\\'")}'"
    end

    # Build the "key='val',..." SQLCommenter body from the active span context.
    def self.tags
      ctx = ::OpenTelemetry::Trace.current_span.context
      return nil unless ctx.valid?

      flags = format("%02x", ctx.trace_flags.sampled? ? 1 : 0)
      traceparent = "00-#{ctx.hex_trace_id}-#{ctx.hex_span_id}-#{flags}"
      [serialize("traceparent", traceparent)].join(",")
    end

    # Append "/*...*/" to a statement, skipping if already commented.
    def append_comment(sql)
      return sql if sql.include?("/*")

      tags = Common::SQLCommenter.tags
      return sql if tags.nil? || tags.empty?

      "#{sql} /*#{tags}*/"
    end

    def execute(sql, opts = {}, &block)
      super(append_comment(sql), opts, &block)
    end

    def execute_dui(sql, opts = {}, &block)
      super(append_comment(sql), opts, &block)
    end

    def execute_insert(sql, opts = {}, &block)
      super(append_comment(sql), opts, &block)
    end
  end
end

Sequel::Database.register_extension(:sqlcommenter, Common::SQLCommenter)
