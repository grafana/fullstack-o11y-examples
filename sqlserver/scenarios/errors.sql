-- Error scenarios for the bookstore and shipping databases. Every statement fails
-- at execution time, so no rows are changed. Failed inserts can still use up
-- identity values, so expect gaps in books_inventory.book_id and orders.order_id.
-- None of the errors is a divide by zero.
--
-- Run as bookstore_app in SQLCMD mode, which keeps going after each error:
--   sqlcmd -S <rds-endpoint>,1433 -U bookstore_app -C -i sqlserver/scenarios/errors.sql
-- Each statement is preceded by the error number it should raise. Error 2628 is
-- reported as 8152 on SQL Server versions before 2019.

:ON ERROR IGNORE

USE [bookstore];
GO

-- 2627: UNIQUE constraint on isbn
INSERT INTO dbo.books_inventory (title, author, isbn, genre, price, stock_quantity)
SELECT TOP 1 'Duplicate ISBN', author, isbn, genre, price, 0 FROM dbo.books_inventory;
GO

-- 547: FOREIGN KEY fk_orders_customer (no such customer)
INSERT INTO dbo.orders (customer_id, book_id, quantity, order_total, order_status, order_date)
SELECT 2147483647, TOP_BOOK.book_id, 1, 9.99, 'paid', SYSDATETIME()
FROM (SELECT TOP 1 book_id FROM dbo.books_inventory) AS TOP_BOOK;
GO

-- 547: CHECK constraint ck_orders_status
INSERT INTO dbo.orders (customer_id, book_id, quantity, order_total, order_status, order_date)
SELECT TOP 1 c.customer_id, b.book_id, 1, 9.99, 'refunded', SYSDATETIME()
FROM dbo.customers c CROSS JOIN dbo.books_inventory b;
GO

-- 515: NOT NULL on title
INSERT INTO dbo.books_inventory (title, author, isbn, genre, price, stock_quantity)
VALUES (NULL, 'Nobody', 'ERR-NOT-NULL', 'Fiction', 9.99, 1);
GO

-- 2628: string or binary data would be truncated (title is VARCHAR(255))
INSERT INTO dbo.books_inventory (title, author, isbn, genre, price, stock_quantity)
VALUES (REPLICATE('X', 300), 'Nobody', 'ERR-TRUNCATE', 'Fiction', 9.99, 1);
GO

-- 8115: arithmetic overflow (price is DECIMAL(8,2))
INSERT INTO dbo.books_inventory (title, author, isbn, genre, price, stock_quantity)
VALUES ('Overflow', 'Nobody', 'ERR-OVERFLOW', 'Fiction', 99999999, 1);
GO

-- 245: conversion failed (string to int)
SELECT CAST('abc' AS INT) AS not_a_number;
GO

-- 241: conversion failed (invalid date)
SELECT CAST('2024-02-30' AS DATE) AS not_a_date;
GO

-- 262: CREATE TABLE permission denied (bookstore_app only has read/write)
CREATE TABLE dbo.scenario_denied (id INT);
GO

-- 50001: custom error raised with THROW
THROW 50001, 'Scenario error: inventory sync failed', 1;
GO

USE [shipping];
GO

-- 2627: UNIQUE constraint on shipments.order_id
INSERT INTO dbo.shipments (order_id, warehouse_id, customer_name, shipping_address, city, state, zip)
SELECT TOP 1 order_id, warehouse_id, customer_name, shipping_address, city, state, zip FROM dbo.shipments;
GO
