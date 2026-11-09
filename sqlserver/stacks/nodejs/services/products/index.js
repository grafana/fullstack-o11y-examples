// Products service — serves the book catalog from SQL Server (books_inventory).
'use strict';

const express = require('express');
const { query } = require('../common/sqlserver');
const { listen } = require('../common/listen');

const app = express();
const port = parseInt(process.env.SERVICE_PORT || '8001', 10);

const CATALOG_SQL =
  'SELECT book_id, title, author, isbn, genre, price, stock_quantity ' +
  'FROM books_inventory ORDER BY title';
const BOOK_SQL =
  'SELECT book_id, title, author, isbn, genre, price, stock_quantity ' +
  'FROM books_inventory WHERE book_id = @p1';

function toBook(row) {
  return { ...row, price: Number(row.price) };
}

app.get('/health', (_req, res) => res.json({ status: 'ok' }));

app.get('/api/products', async (_req, res, next) => {
  try {
    const { recordset: rows } = await query(CATALOG_SQL);
    res.json(rows.map(toBook));
  } catch (err) {
    next(err);
  }
});

app.get('/api/products/:id', async (req, res, next) => {
  try {
    const { recordset: rows } = await query(BOOK_SQL, [parseInt(req.params.id, 10)]);
    if (rows.length === 0) return res.status(404).json({ error: 'book not found' });
    res.json(toBook(rows[0]));
  } catch (err) {
    next(err);
  }
});

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'internal error' });
});

listen(app, port, 'products');
