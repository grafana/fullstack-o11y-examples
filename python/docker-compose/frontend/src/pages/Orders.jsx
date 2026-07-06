import React, { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { getOrders, getShipping } from "../api.js";
import { useAuth } from "../auth.jsx";

export default function Orders() {
  const { customer } = useAuth();
  const [orders, setOrders] = useState(null);
  // order_id -> shipment (warehouse info); null until the shipments are loaded.
  const [shipments, setShipments] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    let cancelled = false;
    getOrders(customer.id)
      .then((rows) => {
        if (cancelled) return;
        setOrders(rows);
        // Enrich each order with its warehouse from the shipments table in
        // PostgreSQL (via the shipping service). Orders come from MySQL; this page
        // composes the two datastores. Fetch one shipment per unique order_id.
        const ids = [...new Set(rows.map((o) => o.order_id))];
        return Promise.all(
          ids.map((id) => getShipping(id).then((s) => [id, s]).catch(() => [id, null])),
        ).then((entries) => {
          if (!cancelled) setShipments(Object.fromEntries(entries));
        });
      })
      .catch((e) => {
        if (!cancelled) setError(e.message);
      });
    return () => {
      cancelled = true;
    };
  }, [customer.id]);

  if (error) return <section><h2>My Orders</h2><p className="error">{error}</p></section>;
  if (orders === null) return <section><h2>My Orders</h2><p>Loading…</p></section>;

  const warehouse = (orderId) => {
    if (shipments === null) return "…";
    const s = shipments[orderId];
    return s ? `${s.warehouse_name} — ${s.warehouse_city}, ${s.warehouse_state}` : "—";
  };

  return (
    <section>
      <h2>My Orders</h2>
      {orders.length === 0 ? (
        <p className="muted">No past orders yet. <Link to="/books">Browse the catalog →</Link></p>
      ) : (
        <table className="orders-table">
          <thead>
            <tr><th>Order</th><th>Book</th><th>Qty</th><th>Total</th><th>Status</th><th>Warehouse</th><th>Date</th></tr>
          </thead>
          <tbody>
            {orders.map((o) => (
              <tr key={o.order_id}>
                <td>#{o.order_id}</td>
                <td>{o.title}</td>
                <td>{o.quantity}</td>
                <td>${Number(o.order_total).toFixed(2)}</td>
                <td><span className={`badge badge-${o.order_status}`}>{o.order_status}</span></td>
                <td>{warehouse(o.order_id)}</td>
                <td>{String(o.order_date).slice(0, 10)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </section>
  );
}
