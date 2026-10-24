# Build context is ./services so the shared `common/` module is available.
FROM node:24-slim@sha256:55fb5f5a527ea2c5c4a95f963e48ef90aa38c7b346054fdc8ee9957a2b55d205
WORKDIR /app
ENV NODE_ENV=production
ENV OTEL_SERVICE_NAME=products-service

COPY package.json ./
RUN npm install --omit=dev

COPY common ./common
COPY products ./products

EXPOSE 8001
# Load the OTel + SQLCommenter bootstrap before requiring express/mysql2.
CMD ["node", "-r", "./common/otel.js", "products/index.js"]
