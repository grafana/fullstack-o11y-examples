# Build context is ./services so the shared `common/` module is available.
FROM node:24-slim@sha256:ba849c60be29959425b8734d57b8b4b7d56f98edd9504c9af091d5281095a71e
ARG SERVICE
WORKDIR /app
ENV NODE_ENV=production
ENV OTEL_SERVICE_NAME=${SERVICE}-service

COPY package.json ./
RUN npm install --omit=dev

COPY common ./common
COPY ${SERVICE} ./${SERVICE}

ADD --chmod=0644 https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem /etc/ssl/certs/rds-ca-bundle.pem
ENV APP_ENTRY=${SERVICE}/index.js
CMD ["sh", "-c", "exec node -r ./common/otel.js \"$APP_ENTRY\""]
