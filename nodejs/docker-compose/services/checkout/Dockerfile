# Build context is ./services so the shared `common/` module is available.
FROM node:22-slim
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
