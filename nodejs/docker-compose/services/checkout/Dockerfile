# Build context is ./services so the shared `common/` module is available.
FROM node:24-slim@sha256:ba849c60be29959425b8734d57b8b4b7d56f98edd9504c9af091d5281095a71e
WORKDIR /app
ENV NODE_ENV=production
ENV OTEL_SERVICE_NAME=checkout-service

COPY package.json ./
RUN npm install --omit=dev

COPY common ./common
COPY checkout ./checkout

EXPOSE 8002
# Load the OTel + SQLCommenter bootstrap before requiring express/mysql2/http.
CMD ["node", "-r", "./common/otel.js", "checkout/index.js"]
