# Build context is ./services so the shared `common/` package is available.
FROM python:3.14-slim@sha256:caaf356f40667c496d405780745b9ac25771c189a51dfcc42430d531ea09f8a2
WORKDIR /app
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1

COPY common ./common
COPY checkout ./checkout
RUN pip install --no-cache-dir -r checkout/requirements.txt

EXPOSE 8002
# No --preload: each worker configures its own OTLP exporter after fork.
CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:8002", "checkout.app:app"]
