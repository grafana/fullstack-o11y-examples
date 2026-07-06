import React from "react";

export default function BookList({ products, onAdd }) {
  if (!products.length) {
    return <section className="books"><p>Loading catalog…</p></section>;
  }
  return (
    <section className="books">
      {products.map((book) => (
        <article key={book.book_id} className="book-card">
          <div className="book-cover">{book.title.charAt(0)}</div>
          <h3 className="book-title">{book.title}</h3>
          <p className="book-author">{book.author}</p>
          <p className="book-genre">{book.genre}</p>
          <div className="book-footer">
            <span className="book-price">${book.price.toFixed(2)}</span>
            <button
              className="btn"
              disabled={book.stock_quantity <= 0}
              onClick={() => onAdd(book)}
            >
              {book.stock_quantity > 0 ? "Add to cart" : "Out of stock"}
            </button>
          </div>
        </article>
      ))}
    </section>
  );
}
