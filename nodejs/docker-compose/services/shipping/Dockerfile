# Build context is ./services so the shared `common/` module is available.
FROM node:26-slim@sha256:e6bedef217677b276c591795e169840edd9096dbf13f29df8ef8d1856b8820bc
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
