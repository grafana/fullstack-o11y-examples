// Checkout service — mock payment, writes orders to MySQL, requests fulfillment.
//
// On checkout it computes the cart total, records one order row per cart line in
// MySQL, simulates a payment, and calls the shipping service to create a shipment
// for each order. The outbound HTTP call is made through Node's `http` module,
// which `@opentelemetry/instrumentation-http` patches to inject the W3C
// traceparent — so a single checkout produces one distributed trace spanning
// checkout -> MySQL and shipping -> Postgres.
'use strict';

const express = require('express');
const mysql = require('mysql2/promise');
const { postJson } = require('./shipping_client');

const app = express();
app.use(express.json());
const port = parseInt(process.env.SERVICE_PORT || '8002', 10);
const SHIPPING_URL = process.env.SHIPPING_URL || 'http://shipping:8003';

const pool = mysql.createPool({
  host: process.env.MYSQL_HOST,
  port: parseInt(process.env.MYSQL_PORT || '3306', 10),
  user: process.env.MYSQL_USER,
  password: process.env.MYSQL_PASSWORD,
  database: process.env.MYSQL_DATABASE,
  waitForConnections: true,
  connectionLimit: 10,
});

const BOOK_SQL = 'SELECT price FROM books_inventory WHERE book_id = ?';
const CUSTOMER_SQL =
  'SELECT customer_id, first_name, last_name, shipping_address, city, state, zip ' +
  'FROM customers WHERE customer_id = ?';
const INSERT_ORDER_SQL =
  'INSERT INTO orders (customer_id, book_id, quantity, order_total, order_status, order_date) ' +
  "VALUES (?, ?, ?, ?, 'paid', NOW())";
const ORDER_SQL =
  'SELECT order_id, customer_id, book_id, quantity, order_total, order_status, order_date ' +
  'FROM orders WHERE order_id = ?';
const ORDERS_BY_CUSTOMER_SQL =
  'SELECT o.order_id, o.book_id, b.title, o.quantity, o.order_total, o.order_status, o.order_date ' +
  'FROM orders o JOIN books_inventory b ON b.book_id = o.book_id ' +
  'WHERE o.customer_id = ? ORDER BY o.order_date DESC, o.order_id DESC';

async function recordOrder(conn, customerId, bookId, quantity) {
  const [rows] = await conn.query(BOOK_SQL, [bookId]);
  const total = Number(rows[0].price) * quantity;
  const [result] = await conn.query(INSERT_ORDER_SQL, [customerId, bookId, quantity, total]);
  return { orderId: result.insertId, total };
}

function requestShipment(orderId, customer) {
  return postJson(`${SHIPPING_URL}/api/shipments`, {
    order_id: orderId,
    customer_name: `${customer.first_name} ${customer.last_name}`,
    shipping_address: customer.shipping_address,
    city: customer.city,
    state: customer.state,
    zip: customer.zip,
  });
}

app.get('/health', (_req, res) => res.json({ status: 'ok' }));

async function persistOrders(customerId, items) {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const orders = [];
    let grandTotal = 0;
    for (const item of items) {
      const { orderId, total } = await recordOrder(conn, customerId, item.book_id, item.quantity || 1);
      grandTotal += total;
      orders.push({ order_id: orderId, book_id: item.book_id, total });
    }
    await conn.commit();
    return { orders, grandTotal };
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    conn.release();
  }
}

app.post('/api/checkout', async (req, res, next) => {
  try {
    const { customer_id: customerId, items } = req.body || {};
    if (!customerId || !Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ error: 'customer_id and items are required' });
    }
    const [custRows] = await pool.query(CUSTOMER_SQL, [customerId]);
    if (custRows.length === 0) return res.status(404).json({ error: 'customer not found' });
    const customer = custRows[0];

    const { orders, grandTotal } = await persistOrders(customerId, items);
    // Mock payment: always approved.
    const shipments = [];
    for (const o of orders) shipments.push(await requestShipment(o.order_id, customer));

    res.status(201).json({
      status: 'confirmed',
      payment: 'approved',
      orders,
      shipments,
      grand_total: Math.round(grandTotal * 100) / 100,
    });
  } catch (err) {
    next(err);
  }
});

app.get('/api/orders', async (req, res, next) => {
  try {
    const customerId = parseInt(req.query.customer_id, 10);
    if (!customerId) return res.status(400).json({ error: 'customer_id query parameter is required' });
    const [rows] = await pool.query(ORDERS_BY_CUSTOMER_SQL, [customerId]);
    res.json(rows.map((r) => ({ ...r, order_total: Number(r.order_total), order_date: String(r.order_date) })));
  } catch (err) {
    next(err);
  }
});

app.get('/api/orders/:id', async (req, res, next) => {
  try {
    const [rows] = await pool.query(ORDER_SQL, [parseInt(req.params.id, 10)]);
    if (rows.length === 0) return res.status(404).json({ error: 'order not found' });
    const row = rows[0];
    res.json({ ...row, order_total: Number(row.order_total), order_date: String(row.order_date) });
  } catch (err) {
    next(err);
  }
});

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'internal error' });
});

app.listen(port, '0.0.0.0', () => console.log(`checkout listening on ${port}`));
