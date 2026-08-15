# Build context is ./services so the shared `common/` module is available.
FROM node:22-slim@sha256:d649c27dae7ba0137b3cef5dd75baa422c08dc3d9e3fc0c23dfb172dc3cc6436
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
