# Build context is ./services so the shared `common/` package is available.
FROM python:3.14-slim@sha256:f57c4c23b985d95deea5bc5249e2f9c8a512b4cc9d5d3fd31900cbd2f5f0a604
WORKDIR /app
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1

COPY common ./common
COPY checkout ./checkout
RUN pip install --no-cache-dir -r checkout/requirements.txt

EXPOSE 8002
# No --preload: each worker configures its own OTLP exporter after fork.
CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:8002", "checkout.app:app"]
