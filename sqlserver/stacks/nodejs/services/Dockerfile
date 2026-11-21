# Build context is ./services so the shared `common/` module is available.
FROM node:24-slim@sha256:dc26ae92c9fb15cf6b1d63e20f0944b2efe0f115b20e00be48fb23fceb061c54
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
