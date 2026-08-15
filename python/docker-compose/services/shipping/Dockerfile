# Build context is ./services so the shared `common/` package is available.
FROM python:3.12-slim@sha256:dd29372629eeba2dd003fd9e9d35a5b8236c44727875a0364254b5127af88e65
WORKDIR /app
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1

COPY common ./common
COPY shipping ./shipping
RUN pip install --no-cache-dir -r shipping/requirements.txt

EXPOSE 8003
# No --preload: each worker configures its own OTLP exporter after fork.
CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:8003", "shipping.app:app"]
