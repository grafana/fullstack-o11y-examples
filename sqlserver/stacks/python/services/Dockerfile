# Build context is ./services so the shared `common/` package is available.
FROM python:3.15-slim@sha256:65a65fc7b30b06cb6df4930fd4650697cb23f4c2698ab81fc87e4b031bc36928
ARG SERVICE
WORKDIR /app
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1

COPY common ./common
ENV FREETDSCONF=/app/common/freetds.conf
COPY ${SERVICE} ./${SERVICE}
RUN pip install --no-cache-dir -r ${SERVICE}/requirements.txt

ADD --chmod=0644 https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem /etc/ssl/certs/rds-ca-bundle.pem
ENV APP_MODULE=${SERVICE}.app:app
CMD ["sh", "-c", "exec gunicorn -w 2 -b 0.0.0.0:${SERVICE_PORT:-8001} \"$APP_MODULE\""]
