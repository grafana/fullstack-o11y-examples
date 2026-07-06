import React from "react";

export default function Cart({ lines, total, onSetQty }) {
  return (
    <section className="cart">
      <h2>Your Cart</h2>
      {lines.length === 0 ? (
        <p className="muted">Your cart is empty.</p>
      ) : (
        <ul className="cart-list">
          {lines.map(({ book, qty }) => (
            <li key={book.book_id} className="cart-item">
              <span className="cart-item-title">{book.title}</span>
              <span className="cart-controls">
                <button className="qty" onClick={() => onSetQty(book.book_id, qty - 1)}>−</button>
                <span className="qty-value">{qty}</span>
                <button className="qty" onClick={() => onSetQty(book.book_id, qty + 1)}>+</button>
              </span>
              <span className="cart-item-price">${(book.price * qty).toFixed(2)}</span>
            </li>
          ))}
        </ul>
      )}
      <p className="cart-total">Total: <strong>${total.toFixed(2)}</strong></p>
    </section>
  );
}
