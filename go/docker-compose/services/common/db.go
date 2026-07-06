package common

import (
	"database/sql"
	"fmt"
	"os"

	"github.com/XSAM/otelsql"
	"github.com/google/sqlcommenter/go/core"
	scsql "github.com/google/sqlcommenter/go/database/sql"
	"go.opentelemetry.io/otel/attribute"

	_ "github.com/go-sql-driver/mysql"
	_ "github.com/lib/pq"
)

// commenterOptions enables SQLCommenter to append the DB driver name and the
// active W3C traceparent to every statement issued via QueryContext/ExecContext,
// which is what powers trace<->SQL correlation in Grafana Cloud.
func commenterOptions() core.CommenterOptions {
	return core.CommenterOptions{
		Config: core.CommenterConfig{
			EnableDBDriver:    true,
			EnableTraceparent: true,
		},
	}
}

// openInstrumented wraps the driver with otelsql — which creates a child span per
// query/exec carrying the SQL text as the db.statement attribute — and then opens
// it through the SQLCommenter wrapper so each statement also gets the active
// traceparent appended as a SQL comment.
func openInstrumented(driver, dsn, system string) (*sql.DB, error) {
	wrapped, err := otelsql.Register(driver,
		otelsql.WithAttributes(attribute.String("db.system", system)),
		otelsql.WithSpanOptions(otelsql.SpanOptions{OmitConnResetSession: true}),
	)
	if err != nil {
		return nil, err
	}
	return scsql.Open(wrapped, dsn, commenterOptions())
}

// OpenMySQL opens the bookstore MySQL database with DB spans + SQLCommenter enabled.
func OpenMySQL() (*sql.DB, error) {
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?parseTime=true",
		os.Getenv("MYSQL_USER"), os.Getenv("MYSQL_PASSWORD"),
		os.Getenv("MYSQL_HOST"), EnvOr("MYSQL_PORT", "3306"), os.Getenv("MYSQL_DATABASE"))
	return openInstrumented("mysql", dsn, "mysql")
}

// OpenPostgres opens the shipping PostgreSQL database with DB spans + SQLCommenter enabled.
func OpenPostgres() (*sql.DB, error) {
	dsn := fmt.Sprintf("postgres://%s:%s@%s:%s/%s?sslmode=disable",
		os.Getenv("POSTGRES_USER"), os.Getenv("POSTGRES_PASSWORD"),
		os.Getenv("POSTGRES_HOST"), EnvOr("POSTGRES_PORT", "5432"), os.Getenv("POSTGRES_DB"))
	return openInstrumented("postgres", dsn, "postgresql")
}

// EnvOr returns the value of key, or def when the variable is unset/empty.
func EnvOr(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

// Port returns the SERVICE_PORT env value or the provided default.
func Port(def string) string { return EnvOr("SERVICE_PORT", def) }
