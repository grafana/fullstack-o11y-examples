import React from "react";
import { NavLink, Outlet, useNavigate } from "react-router-dom";
import { useAuth } from "../auth.jsx";
import { useCart } from "../cart.jsx";

export default function Layout() {
  const { customer, logout } = useAuth();
  const { count } = useCart();
  const navigate = useNavigate();

  const handleLogout = () => {
    logout();
    navigate("/login");
  };

  return (
    <div className="app">
      <header className="header">
        <h1>📚 The Observable Bookstore</h1>
        <nav className="nav">
          <NavLink to="/books">Browse</NavLink>
          <NavLink to="/cart">Cart 🛒 {count}</NavLink>
          <NavLink to="/orders">My Orders</NavLink>
        </nav>
        <span className="user">
          {customer.name}
          <button className="btn" onClick={handleLogout}>Log out</button>
        </span>
      </header>
      <main className="content">
        <Outlet />
      </main>
    </div>
  );
}
