# Build context is ./services so the shared `common/` module is available.
FROM node:24-slim@sha256:0e0ff40c39bc087845bfb27465a0df4ea419520094bc35842ff83dd8cbe6f9b6
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
