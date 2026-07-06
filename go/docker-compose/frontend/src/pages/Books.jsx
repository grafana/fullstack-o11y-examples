import React, { useEffect, useState } from "react";
import { getProducts } from "../api.js";
import { useCart } from "../cart.jsx";
import BookList from "../components/BookList.jsx";

export default function Books() {
  const [products, setProducts] = useState([]);
  const [error, setError] = useState(null);
  const { add } = useCart();

  useEffect(() => {
    getProducts().then(setProducts).catch((e) => setError(e.message));
  }, []);

  return (
    <section>
      <h2>Browse Books</h2>
      {error && <p className="error">Failed to load catalog: {error}</p>}
      <BookList products={products} onAdd={add} />
    </section>
  );
}
