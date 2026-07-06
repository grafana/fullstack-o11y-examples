import React, { createContext, useContext, useMemo, useState } from "react";

// Shopping cart shared across routes. Keyed by book_id -> { book, qty }.
const CartContext = createContext(null);

export function CartProvider({ children }) {
  const [items, setItems] = useState({});

  const add = (book) =>
    setItems((c) => ({
      ...c,
      [book.book_id]: { book, qty: (c[book.book_id]?.qty || 0) + 1 },
    }));

  const setQty = (bookId, qty) =>
    setItems((c) => {
      if (qty <= 0) {
        const { [bookId]: _removed, ...rest } = c;
        return rest;
      }
      return { ...c, [bookId]: { ...c[bookId], qty } };
    });

  const clear = () => setItems({});

  const lines = useMemo(() => Object.values(items), [items]);
  const total = useMemo(
    () => lines.reduce((sum, l) => sum + l.book.price * l.qty, 0),
    [lines]
  );
  const count = lines.reduce((n, l) => n + l.qty, 0);

  return (
    <CartContext.Provider value={{ lines, total, count, add, setQty, clear }}>
      {children}
    </CartContext.Provider>
  );
}

export const useCart = () => useContext(CartContext);
