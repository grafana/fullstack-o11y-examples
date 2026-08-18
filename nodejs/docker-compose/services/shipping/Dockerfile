# Build context is ./services so the shared `common/` module is available.
FROM node:24-slim@sha256:3638d9a6fe4030bd716be989438248074489337ba3275657f93595428be4fc03
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
