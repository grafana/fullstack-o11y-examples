import React from "react";
import { Route, Navigate } from "react-router-dom";
import { FaroRoutes } from "@grafana/faro-react";
import ProtectedRoute from "./components/ProtectedRoute.jsx";
import Layout from "./components/Layout.jsx";
import Login from "./pages/Login.jsx";
import Books from "./pages/Books.jsx";
import CartPage from "./pages/CartPage.jsx";
import Orders from "./pages/Orders.jsx";

export default function App() {
  return (
    <FaroRoutes>
      <Route path="/login" element={<Login />} />
      <Route element={<ProtectedRoute />}>
        <Route element={<Layout />}>
          <Route path="/books" element={<Books />} />
          <Route path="/cart" element={<CartPage />} />
          <Route path="/orders" element={<Orders />} />
        </Route>
      </Route>
      <Route path="*" element={<Navigate to="/books" replace />} />
    </FaroRoutes>
  );
}
