import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// During `vite dev`, proxy /api to the backend services so the browser talks to
// a single origin (matching the nginx setup used in the built image).
export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      "/api/products": "http://localhost:8001",
      "/api/checkout": "http://localhost:8002",
      "/api/orders": "http://localhost:8002",
      "/api/shipping": "http://localhost:8003",
      "/api/shipments": "http://localhost:8003",
    },
  },
});
