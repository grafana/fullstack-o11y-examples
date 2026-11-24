# Build context is ./services so the shared `common/` module is available.
FROM node:26-slim@sha256:abe7e5a82b61a8ef67b315b85497c9e65173387ccf2f4a029248184b8e020be5
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
