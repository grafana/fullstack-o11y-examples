import React from "react";
import { Navigate, Outlet } from "react-router-dom";
import { useAuth } from "../auth.jsx";

// Gate the storefront behind login: unauthenticated visitors go to /login.
export default function ProtectedRoute() {
  const { customer } = useAuth();
  return customer ? <Outlet /> : <Navigate to="/login" replace />;
}
