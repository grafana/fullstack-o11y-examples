# Build context is ./services so the shared `common/` package is available.
FROM python:3.14-slim@sha256:9aaa474097d094040649f2162a627c0049b408f52138d980916788d80f04802f
WORKDIR /app
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1

COPY common ./common
COPY checkout ./checkout
RUN pip install --no-cache-dir -r checkout/requirements.txt

EXPOSE 8002
# No --preload: each worker configures its own OTLP exporter after fork.
CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:8002", "checkout.app:app"]
