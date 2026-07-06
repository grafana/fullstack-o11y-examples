"""Shared OpenTelemetry + SQLCommenter bootstrap for the bookstore services.

Configures OTLP export (traces, metrics, logs) to Grafana Alloy and wires
auto-instrumentation for Flask, outbound requests, and SQLAlchemy. SQLAlchemy is
instrumented with ``enable_commenter=True`` so every SQL statement carries
SQLCommenter tags (including the active trace context) — this is what powers
trace<->SQL correlation in Grafana Cloud.
"""
import logging

from opentelemetry import metrics, trace
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import SERVICE_NAME, Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry._logs import set_logger_provider


def configure_telemetry(service_name: str) -> None:
    """Install global trace/metric/log providers exporting OTLP to Alloy."""
    resource = Resource.create({SERVICE_NAME: service_name})

    tracer_provider = TracerProvider(resource=resource)
    tracer_provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
    trace.set_tracer_provider(tracer_provider)

    reader = PeriodicExportingMetricReader(OTLPMetricExporter())
    metrics.set_meter_provider(MeterProvider(resource=resource, metric_readers=[reader]))

    logger_provider = LoggerProvider(resource=resource)
    logger_provider.add_log_record_processor(BatchLogRecordProcessor(OTLPLogExporter()))
    set_logger_provider(logger_provider)
    handler = LoggingHandler(level=logging.INFO, logger_provider=logger_provider)
    logging.getLogger().addHandler(handler)
    logging.getLogger().setLevel(logging.INFO)


def instrument_flask(app) -> None:
    """Auto-instrument a Flask app and its outbound HTTP calls."""
    FlaskInstrumentor().instrument_app(app)
    RequestsInstrumentor().instrument()


def instrument_sqlalchemy(engine) -> None:
    """Instrument a SQLAlchemy engine with SQLCommenter enabled."""
    SQLAlchemyInstrumentor().instrument(
        engine=engine,
        enable_commenter=True,
        commenter_options={
            "db_driver": True,
            "db_framework": True,
            "opentelemetry_values": True,
        },
    )
