# Build context is ./services so the shared `common/` module is available.
FROM node:26-slim@sha256:e6bedef217677b276c591795e169840edd9096dbf13f29df8ef8d1856b8820bc
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
