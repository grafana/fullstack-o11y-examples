# Build context is ./services so the shared `common/` module is available.
FROM node:26-slim@sha256:abe7e5a82b61a8ef67b315b85497c9e65173387ccf2f4a029248184b8e020be5
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
