# Build context is ./services so the shared `common/` package is available.
FROM python:3.15-slim@sha256:65a65fc7b30b06cb6df4930fd4650697cb23f4c2698ab81fc87e4b031bc36928
WORKDIR /app
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1

COPY common ./common
COPY shipping ./shipping
RUN pip install --no-cache-dir -r shipping/requirements.txt

EXPOSE 8003
# No --preload: each worker configures its own OTLP exporter after fork.
CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:8003", "shipping.app:app"]
