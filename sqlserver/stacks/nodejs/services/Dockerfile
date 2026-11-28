# Build context is ./services so the shared `common/` module is available.
FROM node:24-slim@sha256:873f586f3794f52281bd039bf02c048a0be08fde619338f9941bad1eb6b34530
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
