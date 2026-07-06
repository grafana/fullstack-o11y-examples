"""Checkout service — mock payment, writes orders to MySQL, requests fulfillment.

On checkout it computes the cart total, records one order row per cart line in
MySQL, simulates a payment, and calls the shipping service to create a shipment
for each order. The outbound call propagates trace context, so a single checkout
produces one distributed trace spanning checkout -> MySQL and shipping -> Postgres.
"""
import os

import requests
from flask import Flask, jsonify, request
from flask_cors import CORS
from sqlalchemy import create_engine, text

from common.otel_setup import configure_telemetry, instrument_flask, instrument_sqlalchemy

configure_telemetry("checkout-service")

app = Flask(__name__)
CORS(app)
SHIPPING_URL = os.environ.get("SHIPPING_URL", "http://shipping:8003")


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

BOOK_SQL = text("SELECT price FROM books_inventory WHERE book_id = :book_id")
CUSTOMER_SQL = text(
    "SELECT customer_id, first_name, last_name, shipping_address, city, state, zip "
    "FROM customers WHERE customer_id = :customer_id"
)
INSERT_ORDER_SQL = text(
    "INSERT INTO orders (customer_id, book_id, quantity, order_total, order_status, order_date) "
    "VALUES (:customer_id, :book_id, :quantity, :order_total, 'paid', NOW())"
)
ORDER_SQL = text(
    "SELECT order_id, customer_id, book_id, quantity, order_total, order_status, order_date "
    "FROM orders WHERE order_id = :order_id"
)
ORDERS_BY_CUSTOMER_SQL = text(
    "SELECT o.order_id, o.book_id, b.title, o.quantity, o.order_total, o.order_status, o.order_date "
    "FROM orders o JOIN books_inventory b ON b.book_id = o.book_id "
    "WHERE o.customer_id = :customer_id ORDER BY o.order_date DESC, o.order_id DESC"
)


def _record_order(conn, customer_id, book_id, quantity):
    price = conn.execute(BOOK_SQL, {"book_id": book_id}).scalar_one()
    total = float(price) * quantity
    result = conn.execute(INSERT_ORDER_SQL, {
        "customer_id": customer_id, "book_id": book_id,
        "quantity": quantity, "order_total": total,
    })
    return result.lastrowid, total


def _request_shipment(order_id, customer):
    payload = {
        "order_id": order_id,
        "customer_name": f"{customer['first_name']} {customer['last_name']}",
        "shipping_address": customer["shipping_address"],
        "city": customer["city"], "state": customer["state"], "zip": customer["zip"],
    }
    resp = requests.post(f"{SHIPPING_URL}/api/shipments", json=payload, timeout=5)
    resp.raise_for_status()
    return resp.json()


@app.get("/health")
def health():
    return jsonify(status="ok")


@app.post("/api/checkout")
def checkout():
    body = request.get_json(force=True) or {}
    customer_id = body.get("customer_id")
    items = body.get("items", [])
    if not customer_id or not items:
        return jsonify(error="customer_id and items are required"), 400

    with engine.begin() as conn:
        customer = conn.execute(CUSTOMER_SQL, {"customer_id": customer_id}).mappings().first()
        if customer is None:
            return jsonify(error="customer not found"), 404
        orders, grand_total = [], 0.0
        for item in items:
            order_id, total = _record_order(conn, customer_id, item["book_id"], item.get("quantity", 1))
            grand_total += total
            orders.append({"order_id": order_id, "book_id": item["book_id"], "total": total})

    # Mock payment: always approved.
    shipments = [_request_shipment(o["order_id"], customer) for o in orders]
    return jsonify(
        status="confirmed", payment="approved",
        orders=orders, shipments=shipments, grand_total=round(grand_total, 2),
    ), 201


@app.get("/api/orders")
def list_orders():
    customer_id = request.args.get("customer_id", type=int)
    if not customer_id:
        return jsonify(error="customer_id query parameter is required"), 400
    with engine.connect() as conn:
        rows = conn.execute(ORDERS_BY_CUSTOMER_SQL, {"customer_id": customer_id}).mappings().all()
    return jsonify([
        dict(r) | {"order_total": float(r["order_total"]), "order_date": str(r["order_date"])}
        for r in rows
    ])


@app.get("/api/orders/<int:order_id>")
def get_order(order_id):
    with engine.connect() as conn:
        row = conn.execute(ORDER_SQL, {"order_id": order_id}).mappings().first()
    if row is None:
        return jsonify(error="order not found"), 404
    return jsonify(dict(row) | {"order_total": float(row["order_total"]), "order_date": str(row["order_date"])})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("SERVICE_PORT", 8002)))
