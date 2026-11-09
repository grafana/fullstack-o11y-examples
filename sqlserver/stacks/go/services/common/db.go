package common

import (
	"database/sql"
	"fmt"
	"net"
	"net/url"
	"os"
	"strconv"

	"github.com/XSAM/otelsql"
	"github.com/google/sqlcommenter/go/core"
	scsql "github.com/google/sqlcommenter/go/database/sql"
	"go.opentelemetry.io/otel/attribute"

	_ "github.com/microsoft/go-mssqldb"
)

func commenterOptions() core.CommenterOptions {
	return core.CommenterOptions{Config: core.CommenterConfig{
		EnableDBDriver: true, EnableTraceparent: true,
	}}
}

func openInstrumented(driver, dsn, database string, port int) (*sql.DB, error) {
	wrapped, err := otelsql.Register(driver,
		otelsql.WithAttributes(
			attribute.String("db.system", "mssql"),
			attribute.String("db.name", database),
			attribute.String("server.address", os.Getenv("MSSQL_HOST")),
			attribute.Int("server.port", port),
			attribute.String("net.peer.name", os.Getenv("MSSQL_HOST")),
			attribute.Int("net.peer.port", port)),
		otelsql.WithSpanOptions(otelsql.SpanOptions{OmitConnResetSession: true}),
	)
	if err != nil {
		return nil, err
	}
	return scsql.Open(wrapped, dsn, commenterOptions())
}

func OpenBookstore() (*sql.DB, error) { return openMSSQL("MSSQL_BOOKSTORE_DB") }
func OpenShipping() (*sql.DB, error)  { return openMSSQL("MSSQL_SHIPPING_DB") }

func openMSSQL(databaseEnv string) (*sql.DB, error) {
	database := os.Getenv(databaseEnv)
	if database == "" {
		return nil, fmt.Errorf("%s is required", databaseEnv)
	}
	port, err := strconv.Atoi(EnvOr("MSSQL_PORT", "1433"))
	if err != nil || port < 1 || port > 65535 {
		return nil, fmt.Errorf("MSSQL_PORT must be between 1 and 65535")
	}
	dsn := url.URL{
		Scheme: "sqlserver",
		User:   url.UserPassword(os.Getenv("MSSQL_USER"), os.Getenv("MSSQL_PASSWORD")),
		Host:   net.JoinHostPort(os.Getenv("MSSQL_HOST"), EnvOr("MSSQL_PORT", "1433")),
	}
	query := url.Values{}
	query.Set("database", database)
	query.Set("encrypt", "true")
	query.Set("certificate", "/etc/ssl/certs/rds-ca-bundle.pem")
	query.Set("TrustServerCertificate", EnvOr("MSSQL_TRUST_SERVER_CERTIFICATE", "false"))
	dsn.RawQuery = query.Encode()
	return openInstrumented("sqlserver", dsn.String(), database, port)
}

func EnvOr(key, def string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return def
}

func Port(def string) string { return EnvOr("SERVICE_PORT", def) }
