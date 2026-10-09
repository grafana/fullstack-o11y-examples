# Build context is ./services so the shared `common/` module is available.
FROM node:24-slim@sha256:d6aa754f16b3197301076f047b5def2f02ea1dbbc2ca920407d46d7ec7f87b20
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
