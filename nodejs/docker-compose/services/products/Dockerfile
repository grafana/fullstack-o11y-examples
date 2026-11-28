# Build context is ./services so the shared `common/` module is available.
FROM node:24-slim@sha256:873f586f3794f52281bd039bf02c048a0be08fde619338f9941bad1eb6b34530
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
