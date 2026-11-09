"""Products service — serves the book catalog from SQL Server (books_inventory)."""
import os

from common.otel_setup import (
    configure_telemetry,
    instrument_flask,
    instrument_sqlalchemy,
)
from flask import Flask, jsonify
from flask_cors import CORS
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL

configure_telemetry("products-service")

app = Flask(__name__)
CORS(app)


def make_engine(database_env):
    url = URL.create(
        "mssql+pymssql",
        username=os.environ["MSSQL_USER"],
        password=os.environ["MSSQL_PASSWORD"],
        host=os.environ["MSSQL_HOST"],
        port=int(os.environ.get("MSSQL_PORT", "1433")),
        database=os.environ[database_env],
    )
    return create_engine(
        url,
        connect_args={"encryption": "require", "tds_version": "7.4"},
        pool_pre_ping=True,
    )


engine = make_engine("MSSQL_BOOKSTORE_DB")
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
    app.run(host="0.0.0.0", port=int(os.environ.get("SERVICE_PORT", "8001")))
