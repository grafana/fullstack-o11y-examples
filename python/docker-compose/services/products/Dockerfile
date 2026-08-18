# Build context is ./services so the shared `common/` package is available.
FROM python:3.14-slim@sha256:ce40764625a4ff50df3548277632e7f96c4e77fe75fa848aae9885476e7df5a4
WORKDIR /app
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1

COPY common ./common
COPY products ./products
RUN pip install --no-cache-dir -r products/requirements.txt

EXPOSE 8001
# No --preload: each worker configures its own OTLP exporter after fork.
CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:8001", "products.app:app"]
