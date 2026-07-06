// Faro must be the first import so it captures errors from app startup.
import "./faro.js";

import React from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import { FaroErrorBoundary } from "@grafana/faro-react";
import { AuthProvider } from "./auth.jsx";
import { CartProvider } from "./cart.jsx";
import App from "./App.jsx";
import "./styles.css";

createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <FaroErrorBoundary>
      <BrowserRouter>
        <AuthProvider>
          <CartProvider>
            <App />
          </CartProvider>
        </AuthProvider>
      </BrowserRouter>
    </FaroErrorBoundary>
  </React.StrictMode>
);
