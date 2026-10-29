# Build context is ./services so the shared `common/` package is available.
FROM python:3.14-slim@sha256:cd89c30eda26ee911a4611b18680086e0ea42e6f5f8cbe653d07fa7958c9cec8
WORKDIR /app
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1

COPY common ./common
COPY checkout ./checkout
RUN pip install --no-cache-dir -r checkout/requirements.txt

EXPOSE 8002
# No --preload: each worker configures its own OTLP exporter after fork.
CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:8002", "checkout.app:app"]
