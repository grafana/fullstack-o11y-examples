import React, { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../auth.jsx";
import { CUSTOMERS } from "../customers.js";

export default function Login() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const [customerId, setCustomerId] = useState(CUSTOMERS[0].id);

  const submit = (e) => {
    e.preventDefault();
    const customer = CUSTOMERS.find((c) => c.id === Number(customerId));
    login(customer);
    navigate("/books");
  };

  return (
    <div className="login-page">
      <form className="login-card" onSubmit={submit}>
        <h1>📚 The Observable Bookstore</h1>
        <p className="muted">Sign in to browse the catalog and place orders.</p>
        <label className="field">
          Sign in as
          <select value={customerId} onChange={(e) => setCustomerId(e.target.value)}>
            {CUSTOMERS.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name} — {c.city}, {c.state}
              </option>
            ))}
          </select>
        </label>
        <button className="btn btn-primary" type="submit">Log in</button>
        <p className="muted small">Demo login — no password. Pick a seeded customer.</p>
      </form>
    </div>
  );
}
