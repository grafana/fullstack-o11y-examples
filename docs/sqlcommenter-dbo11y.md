# SQLCommenter → Grafana Cloud Database Observability linkage

This doc explains **what SQLCommenter instrumentation code is needed, and where**, so
that application spans carrying `db.statement` / `db.query.text` attributes can be
linked to query samples in **Grafana Cloud Database Observability (DBo11y)**. Every
code reference below points at the working implementation in this repo.

## How the linkage works

Correlation between an APM trace and a DBo11y query sample requires **both halves**:

```
 App service (OTel SDK)                          Database server
 ┌──────────────────────────────┐               ┌─────────────────────────────┐
 │ DB client span                │               │ SELECT ... FROM books       │
 │   db.system = mysql           │   SQL text    │ /*traceparent='00-<trace_id>│
 │   db.statement = SELECT ...   │ ────────────▶ │  -<span_id>-01'*/           │
 │   trace_id = abc123…          │  + comment    │ (pg_stat_statements /       │
 └──────────────────────────────┘               │  performance_schema)        │
              │ OTLP                             └──────────────┬──────────────┘
              ▼                                                 │ query_samples
 ┌──────────────────────────────┐               ┌───────────────▼─────────────┐
 │ Grafana Alloy                 │               │ Alloy database_observability│
 │ otelcol.receiver.otlp → cloud │               │ (redaction disabled) → cloud│
 └──────────────────────────────┘               └─────────────────────────────┘
```

1. **Client side (span):** an OTel DB-client instrumentation creates a span per query
   with the SQL text as `db.statement` (older semconv) or `db.query.text` (new semconv).
2. **Client side (comment):** SQLCommenter appends `/*traceparent='00-<trace_id>-<span_id>-<flags>'*/`
   to the SQL string *before it is sent to the database*, so the same trace context
   travels inside the SQL text itself.
3. **Server side:** Alloy's `database_observability.mysql` / `database_observability.postgres`
   components collect query samples from `performance_schema` / `pg_stat_statements`.
   With query redaction disabled, the sample retains the comment — and therefore the
   `traceparent` — letting DBo11y join the query sample back to the trace (and to the
   exact span when the injected `span_id` is the DB-client span's). Grafana's exact
   matching keys on the trace ID **and** the span ID; in this repo every injector appends
   the comment *before* the DB-client span is created, so the `span_id` is the enclosing
   span's and correlation is **trace-level** for all languages — see the span-ID caveat below.

Without SQLCommenter, DBo11y still shows queries, but there is no deterministic
span ↔ query-sample link: `db.statement` alone matches a *normalized* statement, not
a specific execution in a specific trace.

## What you need, per language

Two ingredients on the app side, always in this order of concern:
a **DB-client span producer** (gives you `db.statement`) and a **SQLCommenter
injector** (gives the database the `traceparent`). Some ecosystems bundle both.

| Language | DB spans (`db.statement`) from | SQLCommenter injection | One library or two? |
|----------|-------------------------------|------------------------|---------------------|
| Python   | `opentelemetry-instrumentation-sqlalchemy` | same instrumentor, `enable_commenter=True` | one |
| Node.js  | `@opentelemetry/instrumentation-mysql2` / `-pg` | same instrumentations, `addSqlCommenterCommentToQueries: true` | one |
| Go       | `XSAM/otelsql` driver wrapper | `google/sqlcommenter` `database/sql` wrapper layered on top | two, composed |
| Java     | OTel Java agent (auto-instruments JDBC) | **hand-rolled helper** — the agent does not inject SQLCommenter | agent + helper |
| Ruby     | `opentelemetry-instrumentation-mysql2` / `-pg` | **hand-rolled Sequel extension** | gems + extension |

### Python (Flask + SQLAlchemy)

Where: [otel_setup.py](../python/docker-compose/services/common/otel_setup.py) —
`instrument_sqlalchemy()`. The SQLAlchemy instrumentor produces the DB spans *and*
injects the comment; `opentelemetry_values: True` is the switch that adds `traceparent`:

```python
SQLAlchemyInstrumentor().instrument(
    engine=engine,
    enable_commenter=True,
    commenter_options={
        "db_driver": True,
        "db_framework": True,
        "opentelemetry_values": True,   # ← injects traceparent into the SQL comment
    },
)
```

Dependency ([base-requirements.txt](../python/docker-compose/services/common/base-requirements.txt)):
`opentelemetry-instrumentation-sqlalchemy==0.48b0`. No separate sqlcommenter package —
it is built into the instrumentor. Call `instrument_sqlalchemy(engine)` once per
engine, right after `create_engine()`.

### Node.js (Express + mysql2/pg)

Where: [otel.js](../nodejs/docker-compose/services/common/otel.js). The mysql2 and pg
instrumentations produce the DB spans and take a built-in SQLCommenter option:

```js
new MySQL2Instrumentation({ addSqlCommenterCommentToQueries: true }),
new PgInstrumentation({ addSqlCommenterCommentToQueries: true }),
```

Dependencies ([package.json](../nodejs/docker-compose/services/package.json)):
`@opentelemetry/instrumentation-mysql2 ^0.45.0`, `@opentelemetry/instrumentation-pg ^0.51.0`.

**Load order matters:** the SDK must patch `mysql2`/`pg` before any service code
requires them — this repo preloads it with `node -r ./common/otel.js`
(see the service [Dockerfile](../nodejs/docker-compose/services/checkout/Dockerfile)).

### Go (net/http + database/sql)

Where: [db.go](../go/docker-compose/services/common/db.go). Two libraries are composed:
`XSAM/otelsql` wraps the driver to emit DB spans; Google's SQLCommenter `database/sql`
wrapper (`scsql`) layers comment injection on top of the wrapped driver:

```go
// 1. otelsql: DB client spans with db.statement
wrapped, err := otelsql.Register(driver,
    otelsql.WithAttributes(attribute.String("db.system", system)),
    otelsql.WithSpanOptions(otelsql.SpanOptions{OmitConnResetSession: true}),
)

// 2. sqlcommenter: traceparent comment on every statement
db, err := scsql.Open(wrapped, dsn, core.CommenterOptions{
    Config: core.CommenterConfig{
        EnableDBDriver:    true,
        EnableTraceparent: true,   // ← the linkage switch
    },
})
```

Dependencies ([go.mod](../go/docker-compose/services/go.mod)): `github.com/XSAM/otelsql v0.38.0`,
`github.com/google/sqlcommenter/go/core v0.1.2`,
`github.com/google/sqlcommenter/go/database/sql v0.1.1`. The same pattern serves both
MySQL (`go-sql-driver/mysql`) and Postgres (`lib/pq`).

**Order matters:** otelsql is registered first and the connection is opened *through* the
sqlcommenter wrapper, so sqlcommenter is the **outer** layer. It appends the comment before
the inner `otelsql` DB-client span is created, so the `traceparent` carries the *enclosing*
span's context (trace-level correlation — see the span-ID caveat below), not the DB-client
span's. Capturing the DB-client span's own ID would require the sqlcommenter layer to run
inside the otelsql span.

### Java (Spring Boot + JdbcTemplate)

The OTel Java agent auto-instruments JDBC and emits `db.statement` spans, but it does
**not** inject SQLCommenter comments — so this repo hand-rolls a small helper, one per
service, e.g. [SqlCommenter.java](../java/docker-compose/services/products/src/main/java/com/bookstore/products/SqlCommenter.java):

```java
public static String annotate(String sql) {
    SpanContext ctx = Span.current().getSpanContext();
    if (!ctx.isValid()) { return sql; }
    String flags = ctx.getTraceFlags().asHex();
    String traceparent = "00-" + ctx.getTraceId() + "-" + ctx.getSpanId() + "-" + flags;
    String comment = "traceparent=" + quote(traceparent) + ",db_driver=" + quote("spring-jdbc");
    return sql + " /*" + comment + "*/";
}
```

Every query call site wraps its SQL: `jdbcTemplate.query(SqlCommenter.annotate(SQL), …)` —
see [ProductsController.java](../java/docker-compose/services/products/src/main/java/com/bookstore/products/ProductsController.java),
[CheckoutController.java](../java/docker-compose/services/checkout/src/main/java/com/bookstore/checkout/CheckoutController.java),
[ShippingController.java](../java/docker-compose/services/shipping/src/main/java/com/bookstore/shipping/ShippingController.java).

> **Span-ID caveat — the injectors here carry the enclosing span, so correlation is trace-level (not exact-span).**
> `annotate(...)` is called inline (`jdbcTemplate.query(SqlCommenter.annotate(SQL), …)`)
> *before* the OTel Java agent creates the JDBC/DB-client span, so `Span.current()`
> resolves to the **enclosing** span active at that call site (typically the HTTP/server
> span) and the injected `span_id` is that span's — not the DB-client span's. Because
> Grafana's exact matching keys on trace ID **and** span ID, it cannot pinpoint the exact
> DB-client span on the Java path. Linkage still works: the **trace ID is correct**, so the
> query sample resolves to the right trace, and query-text (normalized-statement) matching
> still associates the sample — you land on the trace rather than exactly on the DB span.
> An exact DB-span match would require injecting the comment once the DB-client span is
> active (e.g. from a JDBC interceptor running inside that span), which this demo does not
> do. **This is not unique to Java:** the Go injector wraps SQLCommenter *outside* the
> `otelsql` layer ([db.go](../go/docker-compose/services/common/db.go)), so it likewise
> appends the comment before the DB-client span exists and carries the enclosing span's ID;
> the Python (SQLAlchemy) path has not been verified. Treat **trace-level correlation as the
> contract for every language here**, and confirm exact span matching empirically (step 4)
> before relying on it.

Needed pieces:
- `io.opentelemetry:opentelemetry-api` (compile-time, for `Span.current()`) — [pom.xml](../java/docker-compose/services/products/pom.xml)
- the agent attached at runtime: `-javaagent:/otel/opentelemetry-javaagent.jar`
  ([Dockerfile](../java/docker-compose/services/products/Dockerfile), agent v2.9.0)

Values must be URL-encoded and single-quoted per the
[SQLCommenter spec](https://google.github.io/sqlcommenter/spec/) (`quote()` in the helper).

The agent also sanitizes `db.statement` by default, redacting the comment's
values to `?` in the span. For this demo only, the Java services set
`OTEL_INSTRUMENTATION_COMMON_DB_STATEMENT_SANITIZER_ENABLED=false` so the full
SQLCommenter comment is visible when inspecting a trace. This is not required
for DBo11y correlation; see [Gotchas](#gotchas) for the behavior and risk.

### Ruby (Sinatra + Sequel)

DB spans come from the OTel `mysql2`/`pg` instrumentation gems, enabled in
[otel.rb](../ruby/docker-compose/services/common/otel.rb):

```ruby
c.use "OpenTelemetry::Instrumentation::Mysql2"
c.use "OpenTelemetry::Instrumentation::PG"
```

Comment injection is a hand-rolled Sequel extension,
[sqlcommenter.rb](../ruby/docker-compose/services/common/sqlcommenter.rb), which
overrides `execute`/`execute_dui`/`execute_insert` to append the traceparent:

```ruby
def self.tags
  ctx = ::OpenTelemetry::Trace.current_span.context
  return nil unless ctx.valid?
  flags = format("%02x", ctx.trace_flags.sampled? ? 1 : 0)
  traceparent = "00-#{ctx.hex_trace_id}-#{ctx.hex_span_id}-#{flags}"
  [serialize("traceparent", traceparent)].join(",")
end
```

It is registered as `Sequel::Database.register_extension(:sqlcommenter, …)` and enabled
per connection with `db.extension(:sqlcommenter)` in
[db.rb](../ruby/docker-compose/services/common/db.rb). Gems
([Gemfile](../ruby/docker-compose/services/Gemfile)):
`opentelemetry-instrumentation-mysql2 ~> 0.34`, `opentelemetry-instrumentation-pg ~> 0.36`,
`sequel ~> 5.89`. Require the client gems *before* Sequel loads them so the OTel
patches apply (done at the top of `otel.rb`).

## The server/collector half (required — SQLCommenter alone is not enough)

### Alloy `database_observability` components

Per language, in [config.alloy](../go/docker-compose/alloy/config.alloy)
(docker-compose) and the matching `k8s/alloy/configmap.yaml`:

```alloy
database_observability.mysql "bookstore_mysql" {
  enable_collectors = ["query_details", "schema_details", "query_samples", "explain_plans"]
  query_samples {
    disable_query_redaction = true   // ← keeps the SQL comment (traceparent) in samples
    collect_interval        = "10s"
  }
  ...
}

database_observability.postgres "bookstore_postgres" {
  enable_collectors = ["query_details", "query_samples", "schema_details", "explain_plans", "logs"]
  query_samples {
    disable_query_redaction = true
    collect_interval        = "10s"
  }
  ...
}
```

`disable_query_redaction = true` is essential for linkage: with redaction on
(the default), comments are stripped from query samples and the `traceparent` is lost.
Only disable it if your SQL text is safe to ship (no literals with PII — use bind
parameters, as all five apps here do). Telemetry must also carry
`job = "integrations/db-o11y"` (the relabel rules in the same file) for the DBo11y
app to pick it up.

### Database server settings

The comment can only be observed if the server records full statement text:

- **MySQL** — performance schema statement consumers/instruments on
  ([configmap-tuning.yaml](../go/k8s/mysql/configmap-tuning.yaml)):
  `performance-schema-consumer-events-statements-*=ON`,
  `performance-schema-instrument='statement/%=ON'`. Note the SQL-text length limit
  can truncate the tail of long statements — where the comment lives.
- **PostgreSQL** — `shared_preload_libraries='pg_stat_statements'` and
  `pg_stat_statements.track=all`
  ([configmap-config.yaml](../go/k8s/postgres/configmap-config.yaml)).

## Verifying the linkage

1. Drive traffic (browse → cart → checkout in the storefront).
2. Confirm the comment reaches the DB, e.g. MySQL:
   `SELECT sql_text FROM performance_schema.events_statements_history_long WHERE sql_text LIKE '%traceparent%' LIMIT 5;`
3. In Grafana Cloud → **Databases** (DBo11y app): open a query's samples and check the
   SQL text includes `/*traceparent='00-…'*/`.
4. In Explore/Traces, open the matching trace ID: the DB client span's
   `db.statement` / `db.query.text` shows the same statement. Expect the comment's `span_id`
   to equal the **enclosing** span rather than the DB-client span (confirmed for Java and Go;
   Python unverified), so verify linkage by trace ID + statement text — not by an exact
   span-ID match (see the span-ID caveat above).

## Gotchas

- **Prepared statements (server-side)** can bypass comment injection in some drivers —
  all injectors here append to the SQL string before prepare, which works, but verify
  with step 2 above if you change drivers.
- **Statement truncation** on the DB server (MySQL `performance_schema` text limits)
  can cut off the trailing comment for very long queries.
- **New OTel semconv** emits `db.query.text` instead of `db.statement`
  (opt-in via `OTEL_SEMCONV_STABILITY_OPT_IN=database`). The linkage works identically —
  DBo11y correlates on the traceparent in the SQL text, not on the attribute name.
- **Java agent sanitization**: the OTel Java agent sanitizes `db.statement` by default,
  rewriting quoted literals — including SQLCommenter values — to `?`, so the span shows
  `/*traceparent=?,db_driver=?*/`. This does not break correlation: matching uses the
  `traceparent` captured from the database query sample (trace-level here, per
  the span-ID caveat above), while query-text matching compares normalized statements.
  This repo disables sanitization in both Java
  deployment modes only so the demo's trace view shows the complete comment; see
  [docker-compose.yml](../java/docker-compose/docker-compose.yml) and the
  [`bookstore-config` ConfigMap](../java/k8s/00-namespace-config.yaml). Disabling the
  sanitizer applies to every statement and can expose SQL literals in trace data, so it
  should not be copied into a production configuration without a data-safety review.
