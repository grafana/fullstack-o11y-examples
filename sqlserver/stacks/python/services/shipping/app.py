"""Shipping service — chooses a warehouse per order and records it in SQL Server.

Books ship from the West Coast (California) warehouse for western customers and
from the East Coast (New York) warehouse otherwise.
"""
import os

from common.otel_setup import (
    configure_telemetry,
    instrument_flask,
    instrument_sqlalchemy,
)
from flask import Flask, jsonify, request
from flask_cors import CORS
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL

configure_telemetry("shipping-service")

app = Flask(__name__)
CORS(app)
WEST_STATES = {"CA", "WA", "OR", "NV", "AZ", "CO", "UT", "NM", "ID", "MT", "WY"}


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


engine = make_engine("MSSQL_SHIPPING_DB")
instrument_flask(app)
instrument_sqlalchemy(engine)

INSERT_SHIPMENT_SQL = text(
    """
    MERGE dbo.shipments WITH (HOLDLOCK) AS target
    USING (VALUES (:order_id, :warehouse_id, :customer_name, :shipping_address, :city, :state, :zip))
      AS source (order_id, warehouse_id, customer_name, shipping_address, city, state, zip)
    ON target.order_id = source.order_id
    WHEN MATCHED THEN UPDATE SET warehouse_id = source.warehouse_id
    WHEN NOT MATCHED THEN INSERT
      (order_id, warehouse_id, customer_name, shipping_address, city, state, zip, status)
      VALUES (source.order_id, source.warehouse_id, source.customer_name, source.shipping_address,
        source.city, source.state, source.zip, 'processing')
    OUTPUT INSERTED.shipment_id;
    """
)
SHIPMENT_SQL = text(
    "SELECT s.shipment_id, s.order_id, s.status, s.shipped_date, "
    "s.customer_name, s.shipping_address, s.city, s.state, s.zip, "
    "w.name AS warehouse_name, w.city AS warehouse_city, w.state AS warehouse_state "
    "FROM shipments s JOIN warehouses w ON w.warehouse_id = s.warehouse_id "
    "WHERE s.order_id = :order_id"
)


def _pick_warehouse(state: str) -> int:
    return 1 if (state or "").upper() in WEST_STATES else 2


@app.get("/health")
def health():
    return jsonify(status="ok")


@app.post("/api/shipments")
def create_shipment():
    body = request.get_json(force=True) or {}
    warehouse_id = _pick_warehouse(body.get("state", ""))
    params = {
        "order_id": body["order_id"], "warehouse_id": warehouse_id,
        "customer_name": body.get("customer_name", ""),
        "shipping_address": body.get("shipping_address", ""),
        "city": body.get("city", ""), "state": body.get("state", ""),
        "zip": body.get("zip", ""),
    }
    with engine.begin() as conn:
        shipment_id = conn.execute(INSERT_SHIPMENT_SQL, params).scalar_one()
    return jsonify(shipment_id=shipment_id, order_id=params["order_id"], warehouse_id=warehouse_id), 201


@app.get("/api/shipping/<int:order_id>")
def get_shipment(order_id):
    with engine.connect() as conn:
        row = conn.execute(SHIPMENT_SQL, {"order_id": order_id}).mappings().first()
    if row is None:
        return jsonify(error="shipment not found"), 404
    return jsonify(dict(row) | {"shipped_date": str(row["shipped_date"])})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("SERVICE_PORT", "8003")))
