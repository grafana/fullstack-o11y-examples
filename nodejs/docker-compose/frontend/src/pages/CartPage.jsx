import React, { useState } from "react";
import { Link } from "react-router-dom";
import { useCart } from "../cart.jsx";
import { useAuth } from "../auth.jsx";
import { postCheckout } from "../api.js";
import Cart from "../components/Cart.jsx";

export default function CartPage() {
  const { lines, total, setQty, clear } = useCart();
  const { customer } = useAuth();
  const [status, setStatus] = useState("idle"); // idle | placing | done | error
  const [result, setResult] = useState(null);
  const [error, setError] = useState(null);

  const placeOrder = async () => {
    setStatus("placing");
    setError(null);
    const items = lines.map((l) => ({ book_id: l.book.book_id, quantity: l.qty }));
    try {
      const res = await postCheckout(customer.id, items);
      setResult(res);
      clear();
      setStatus("done");
    } catch (e) {
      setError(e.message);
      setStatus("error");
    }
  };

  if (status === "done" && result) {
    return <Confirmation result={result} onReset={() => setStatus("idle")} />;
  }

  return (
    <section className="cart-page">
      <h2>Your Cart</h2>
      <Cart lines={lines} total={total} onSetQty={setQty} />
      <p className="muted">Shipping to {customer.name} — {customer.city}, {customer.state}</p>
      <button
        className="btn btn-primary"
        disabled={lines.length === 0 || status === "placing"}
        onClick={placeOrder}
      >
        {status === "placing" ? "Processing payment…" : `Pay $${total.toFixed(2)}`}
      </button>
      {status === "error" && <p className="error">Checkout failed: {error}</p>}
    </section>
  );
}

function Confirmation({ result, onReset }) {
  return (
    <section className="confirmation">
      <h2>✅ Order confirmed</h2>
      <p>Payment <strong>{result.payment}</strong> — total ${result.grand_total.toFixed(2)}.</p>
      <ul className="confirm-list">
        {result.shipments.map((s) => (
          <li key={s.order_id}>
            Order #{s.order_id} → warehouse {s.warehouse_id === 1 ? "California" : "New York"}
          </li>
        ))}
      </ul>
      <div className="row">
        <Link className="btn" to="/books" onClick={onReset}>Keep shopping</Link>
        <Link className="btn btn-primary" to="/orders">View my orders</Link>
      </div>
    </section>
  );
}
