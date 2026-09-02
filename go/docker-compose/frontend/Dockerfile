# ─── Build stage ──────────────────────────────────────────────────────────────
FROM node:24-alpine@sha256:e67514e5d0f6c46656005e1b693b2ec9d52e80b641307de684d4a015ba7a4eaf AS build
WORKDIR /app
COPY package.json ./
RUN npm install
COPY . .
# Vite inlines this at build time, so it must be present before `npm run build`.
# The Faro app key is the final path segment of the collector URL.
ARG VITE_FARO_ENDPOINT
ENV VITE_FARO_ENDPOINT=$VITE_FARO_ENDPOINT
# Deployment environment for Faro app.environment (deployment_environment / asserts_env).
ARG VITE_ASSERTS_ENV
ENV VITE_ASSERTS_ENV=$VITE_ASSERTS_ENV
RUN npm run build

# ─── Serve stage ────────────────────────────────────────────────────────────────
FROM nginx:alpine@sha256:4a73073bd557c65b759505da037898b61f1be6cbcc3c2c3aeac22d2a470c1752
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
