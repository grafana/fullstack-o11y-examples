# Build context is ./services so the shared `common/` module is available.
FROM node:24-slim@sha256:dc26ae92c9fb15cf6b1d63e20f0944b2efe0f115b20e00be48fb23fceb061c54
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
