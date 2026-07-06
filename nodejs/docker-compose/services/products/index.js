// Products service — serves the book catalog from MySQL (books_inventory).
'use strict';

const express = require('express');
const mysql = require('mysql2/promise');

const app = express();
const port = parseInt(process.env.SERVICE_PORT || '8001', 10);

const pool = mysql.createPool({
  host: process.env.MYSQL_HOST,
  port: parseInt(process.env.MYSQL_PORT || '3306', 10),
  user: process.env.MYSQL_USER,
  password: process.env.MYSQL_PASSWORD,
  database: process.env.MYSQL_DATABASE,
  waitForConnections: true,
  connectionLimit: 10,
});

const CATALOG_SQL =
  'SELECT book_id, title, author, isbn, genre, price, stock_quantity ' +
  'FROM books_inventory ORDER BY title';
const BOOK_SQL =
  'SELECT book_id, title, author, isbn, genre, price, stock_quantity ' +
  'FROM books_inventory WHERE book_id = ?';

function toBook(row) {
  return { ...row, price: Number(row.price) };
}

app.get('/health', (_req, res) => res.json({ status: 'ok' }));

app.get('/api/products', async (_req, res, next) => {
  try {
    const [rows] = await pool.query(CATALOG_SQL);
    res.json(rows.map(toBook));
  } catch (err) {
    next(err);
  }
});

app.get('/api/products/:id', async (req, res, next) => {
  try {
    const [rows] = await pool.query(BOOK_SQL, [parseInt(req.params.id, 10)]);
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

app.listen(port, '0.0.0.0', () => console.log(`products listening on ${port}`));
