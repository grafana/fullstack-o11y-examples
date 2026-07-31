# ─── Build stage ──────────────────────────────────────────────────────────────
FROM node:20-alpine AS build
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
FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
