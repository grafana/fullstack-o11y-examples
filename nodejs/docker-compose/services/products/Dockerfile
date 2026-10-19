# Build context is ./services so the shared `common/` module is available.
FROM node:24-slim@sha256:a5f4366e834695d5f363b920c104953a535d3a9864d1bdf74566a0ebe01daee5
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
