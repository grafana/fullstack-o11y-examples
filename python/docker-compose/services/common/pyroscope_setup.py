"""Optional Pyroscope continuous profiling for the bookstore services.

Starts the Pyroscope sampling CPU profiler (``pyroscope-io``, a py-spy-derived
sampler running in-process) pushing profiles to Grafana Alloy. Profiling is
strictly opt-in: when ``PYROSCOPE_SERVER_ADDRESS`` is unset or empty this module
logs one line and does nothing, so other consumers of the same images that don't
configure profiling (e.g. python/k8s) are unaffected.
"""
import logging
import os

logger = logging.getLogger(__name__)


def configure_profiling(service_name: str) -> bool:
    """Start the Pyroscope sampler; returns True only when profiling is enabled."""
    server_address = os.environ.get("PYROSCOPE_SERVER_ADDRESS", "")
    if not server_address:
        logger.info("PYROSCOPE_SERVER_ADDRESS not set; continuous profiling disabled")
        return False

    # Imported lazily so disabled runs never load the native sampler extension.
    import pyroscope

    # application_name must match the OTel service name so profiles and traces
    # correlate on service_name in Grafana Cloud.
    pyroscope.configure(
        application_name=os.environ.get("PYROSCOPE_APPLICATION_NAME", service_name),
        server_address=server_address,
        tags={"service_namespace": "bookstore"},
    )
    return True
