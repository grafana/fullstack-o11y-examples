// Shipping service — chooses a warehouse per order and records it in PostgreSQL.
//
// Books ship from the West Coast (California) warehouse for western customers and
// from the East Coast (New York) warehouse otherwise.
'use strict';

const express = require('express');
const { Pool } = require('pg');
const { listen } = require('../common/listen');

const app = express();
app.use(express.json());
const port = parseInt(process.env.SERVICE_PORT || '8003', 10);
const WEST_STATES = new Set(['CA', 'WA', 'OR', 'NV', 'AZ', 'CO', 'UT', 'NM', 'ID', 'MT', 'WY']);

const pool = new Pool({
  host: process.env.POSTGRES_HOST,
  port: parseInt(process.env.POSTGRES_PORT || '5432', 10),
  user: process.env.POSTGRES_USER,
  password: process.env.POSTGRES_PASSWORD,
  database: process.env.POSTGRES_DB,
});

const INSERT_SHIPMENT_SQL =
  'INSERT INTO shipments ' +
  '(order_id, warehouse_id, customer_name, shipping_address, city, state, zip, status) ' +
  "VALUES ($1, $2, $3, $4, $5, $6, $7, 'processing') " +
  'ON CONFLICT (order_id) DO UPDATE SET warehouse_id = EXCLUDED.warehouse_id ' +
  'RETURNING shipment_id';
const SHIPMENT_SQL =
  'SELECT s.shipment_id, s.order_id, s.status, s.shipped_date, ' +
  's.customer_name, s.shipping_address, s.city, s.state, s.zip, ' +
  'w.name AS warehouse_name, w.city AS warehouse_city, w.state AS warehouse_state ' +
  'FROM shipments s JOIN warehouses w ON w.warehouse_id = s.warehouse_id ' +
  'WHERE s.order_id = $1';

function pickWarehouse(state) {
  return WEST_STATES.has((state || '').toUpperCase()) ? 1 : 2;
}

app.get('/health', (_req, res) => res.json({ status: 'ok' }));

app.post('/api/shipments', async (req, res, next) => {
  try {
    const b = req.body || {};
    if (b.order_id === undefined || b.order_id === null) {
      return res.status(400).json({ error: 'order_id is required' });
    }
    const warehouseId = pickWarehouse(b.state);
    const params = [
      b.order_id, warehouseId, b.customer_name || '', b.shipping_address || '',
      b.city || '', b.state || '', b.zip || '',
    ];
    const { rows } = await pool.query(INSERT_SHIPMENT_SQL, params);
    res.status(201).json({ shipment_id: rows[0].shipment_id, order_id: b.order_id, warehouse_id: warehouseId });
  } catch (err) {
    next(err);
  }
});

app.get('/api/shipping/:orderId', async (req, res, next) => {
  try {
    const { rows } = await pool.query(SHIPMENT_SQL, [parseInt(req.params.orderId, 10)]);
    if (rows.length === 0) return res.status(404).json({ error: 'shipment not found' });
    const row = rows[0];
    res.json({ ...row, shipped_date: String(row.shipped_date) });
  } catch (err) {
    next(err);
  }
});

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'internal error' });
});

listen(app, port, 'shipping');
