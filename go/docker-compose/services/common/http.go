package common

import (
	"encoding/json"
	"net/http"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
)

// WriteJSON serializes v as a JSON response with the given status code.
func WriteJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

// WriteError writes a JSON {"error": msg} body with the given status code.
func WriteError(w http.ResponseWriter, status int, msg string) {
	WriteJSON(w, status, map[string]string{"error": msg})
}

// Instrument wraps a handler with OpenTelemetry HTTP server spans + metrics.
func Instrument(h http.Handler) http.Handler {
	return otelhttp.NewHandler(h, "http.server")
}

// HTTPClient returns an OTel-instrumented client that propagates trace context
// on outbound calls (e.g. checkout -> shipping).
func HTTPClient() *http.Client {
	return &http.Client{Transport: otelhttp.NewTransport(http.DefaultTransport)}
}
