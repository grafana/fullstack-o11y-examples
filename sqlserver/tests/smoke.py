"""Exercise the shared storefront API; creates one order and shipment."""
import argparse
import json
from urllib.request import Request, urlopen


def request(base, path, body=None):
    data = None if body is None else json.dumps(body).encode()
    req = Request(base.rstrip("/") + path, data=data,
                  headers={"Content-Type": "application/json"})
    with urlopen(req, timeout=30) as response:
        return json.load(response)


def smoke(base):
    catalog = request(base, "/api/products")
    assert catalog and catalog[0]["book_id"], "Missing catalog"
    book = request(base, f'/api/products/{catalog[0]["book_id"]}')
    assert book["book_id"] == catalog[0]["book_id"]
    checkout = request(base, "/api/checkout", {
        "customer_id": 1, "items": [{"book_id": book["book_id"], "quantity": 1}]})
    assert checkout["orders"], "Checkout did not return orders"
    order_id = checkout["orders"][0]["order_id"]
    order = request(base, f"/api/orders/{order_id}")
    assert order["order_id"] == order_id
    shipment = request(base, f"/api/shipping/{order_id}")
    assert shipment["order_id"] == order_id
    assert shipment["warehouse_id"] if "warehouse_id" in shipment else shipment["warehouse_name"]
    print("Catalog, checkout, order lookup, and shipment lookup passed")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default="http://localhost:8080")
    smoke(parser.parse_args().url)
