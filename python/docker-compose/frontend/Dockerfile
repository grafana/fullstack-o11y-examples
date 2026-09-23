# ─── Build stage ──────────────────────────────────────────────────────────────
FROM node:24-alpine@sha256:ebfe2f90462722a7a4de65e91990e97fe0d401c70e0e762c5b53302f905ec1c1 AS build
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
# Session Replay opt-in (see faro.js) — also inlined at build time.
ARG VITE_SESSION_REPLAY
ENV VITE_SESSION_REPLAY=$VITE_SESSION_REPLAY
RUN npm run build

# ─── Serve stage ────────────────────────────────────────────────────────────────
FROM nginx:alpine@sha256:4a73073bd557c65b759505da037898b61f1be6cbcc3c2c3aeac22d2a470c1752
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
