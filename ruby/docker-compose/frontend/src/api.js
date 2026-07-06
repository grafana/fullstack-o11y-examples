// Thin API client. All calls are same-origin (/api/*) and proxied by nginx (or
// the Vite dev server) to the products / checkout / shipping backend services.

async function asJson(resp) {
  if (!resp.ok) {
    const detail = await resp.text().catch(() => "");
    throw new Error(`${resp.status} ${resp.statusText} ${detail}`.trim());
  }
  return resp.json();
}

export function getProducts() {
  return fetch("/api/products").then(asJson);
}

export function getOrders(customerId) {
  return fetch(`/api/orders?customer_id=${encodeURIComponent(customerId)}`).then(asJson);
}

export function postCheckout(customerId, items) {
  return fetch("/api/checkout", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ customer_id: customerId, items }),
  }).then(asJson);
}

export function getShipping(orderId) {
  return fetch(`/api/shipping/${orderId}`).then(asJson);
}
