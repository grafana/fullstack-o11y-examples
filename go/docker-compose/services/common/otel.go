// Package common holds the shared OpenTelemetry + SQLCommenter + HTTP plumbing
// used by the products, checkout, and shipping services.
package common

import (
	"context"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/propagation"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
)

// InitTelemetry installs global trace + metric providers that export OTLP/gRPC
// to the collector named by OTEL_EXPORTER_OTLP_ENDPOINT (Grafana Alloy). The
// returned function flushes and shuts them down. The W3C TraceContext
// propagator lets incoming (Faro) and cross-service trace context flow through.
func InitTelemetry(ctx context.Context, serviceName string) (func(context.Context) error, error) {
	res, err := resource.New(ctx,
		resource.WithAttributes(attribute.String("service.name", serviceName)))
	if err != nil {
		return nil, err
	}

	traceExp, err := otlptracegrpc.New(ctx)
	if err != nil {
		return nil, err
	}
	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(traceExp),
		sdktrace.WithResource(res),
	)
	otel.SetTracerProvider(tp)
	otel.SetTextMapPropagator(propagation.TraceContext{})

	metricExp, err := otlpmetricgrpc.New(ctx)
	if err != nil {
		return nil, err
	}
	mp := sdkmetric.NewMeterProvider(
		sdkmetric.WithReader(sdkmetric.NewPeriodicReader(metricExp)),
		sdkmetric.WithResource(res),
	)
	otel.SetMeterProvider(mp)

	return func(c context.Context) error {
		_ = tp.Shutdown(c)
		return mp.Shutdown(c)
	}, nil
}
