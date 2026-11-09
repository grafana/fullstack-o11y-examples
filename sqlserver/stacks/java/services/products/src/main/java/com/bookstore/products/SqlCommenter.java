package com.bookstore.products;

import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.SpanContext;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;

/**
 * Appends a Google SQLCommenter comment carrying the active W3C traceparent to
 * every SQL statement, e.g.
 * {@code SELECT ... /*traceparent='00-<traceId>-<spanId>-01'*}{@code /}.
 *
 * <p>The OpenTelemetry Java agent auto-instruments Spring MVC and JDBC and makes
 * the active span available via {@link Span#current()}. We read its
 * {@link SpanContext} and format the traceparent so Grafana can correlate the
 * emitted DB span with the SQL text observed at the database.
 */
public final class SqlCommenter {

    private SqlCommenter() {
    }

    /** Returns {@code sql} with a SQLCommenter comment appended, if a span is recording. */
    public static String annotate(String sql) {
        SpanContext ctx = Span.current().getSpanContext();
        if (!ctx.isValid()) {
            return sql;
        }
        String flags = ctx.getTraceFlags().asHex();
        String traceparent = "00-" + ctx.getTraceId() + "-" + ctx.getSpanId() + "-" + flags;
        String comment = "traceparent=" + quote(traceparent) + ",db_driver=" + quote("spring-jdbc");
        return sql + " /*" + comment + "*/";
    }

    /** URL-encodes a value and wraps it in single quotes per the SQLCommenter spec. */
    private static String quote(String value) {
        return "'" + URLEncoder.encode(value, StandardCharsets.UTF_8) + "'";
    }
}
