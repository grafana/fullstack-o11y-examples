# Build context is ./services so the shared `common/` module is available.
FROM node:26-slim@sha256:e4db4c914bf8ad241bd24804fc25d272d89bad97e68cdc8a1414862790a02c39
WORKDIR /app
ENV NODE_ENV=production
ENV OTEL_SERVICE_NAME=shipping-service

COPY package.json ./
RUN npm install --omit=dev

COPY common ./common
COPY shipping ./shipping

EXPOSE 8003
# Load the OTel + SQLCommenter bootstrap before requiring express/pg.
CMD ["node", "-r", "./common/otel.js", "shipping/index.js"]
