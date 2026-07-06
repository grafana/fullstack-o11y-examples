"""Products service — serves the book catalog from MySQL (books_inventory)."""
import os

from flask import Flask, jsonify
from flask_cors import CORS
from sqlalchemy import create_engine, text

from common.otel_setup import configure_telemetry, instrument_flask, instrument_sqlalchemy

configure_telemetry("products-service")

app = Flask(__name__)
CORS(app)


def make_engine():
    url = (
        f"mysql+pymysql://{os.environ['MYSQL_USER']}:{os.environ['MYSQL_PASSWORD']}"
        f"@{os.environ['MYSQL_HOST']}:{os.environ.get('MYSQL_PORT', '3306')}"
        f"/{os.environ['MYSQL_DATABASE']}"
    )
    return create_engine(url, pool_pre_ping=True)


engine = make_engine()
instrument_flask(app)
instrument_sqlalchemy(engine)

CATALOG_SQL = text(
    "SELECT book_id, title, author, isbn, genre, price, stock_quantity "
    "FROM books_inventory ORDER BY title"
)
BOOK_SQL = text(
    "SELECT book_id, title, author, isbn, genre, price, stock_quantity "
    "FROM books_inventory WHERE book_id = :book_id"
)


@app.get("/health")
def health():
    return jsonify(status="ok")


@app.get("/api/products")
def list_products():
    with engine.connect() as conn:
        rows = conn.execute(CATALOG_SQL).mappings().all()
    return jsonify([dict(r) | {"price": float(r["price"])} for r in rows])


@app.get("/api/products/<int:book_id>")
def get_product(book_id):
    with engine.connect() as conn:
        row = conn.execute(BOOK_SQL, {"book_id": book_id}).mappings().first()
    if row is None:
        return jsonify(error="book not found"), 404
    return jsonify(dict(row) | {"price": float(row["price"])})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("SERVICE_PORT", 8001)))
