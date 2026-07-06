-- MySQL init: bookstore database
-- Runs automatically against the MYSQL_DATABASE (bookstore) on first container start.
-- Seeds: 20 books, 10 customers, 100 orders (10 per customer).

SET NAMES utf8mb4;

-- ─── Schema ──────────────────────────────────────────────────────────────────
CREATE TABLE books_inventory (
  book_id        INT AUTO_INCREMENT PRIMARY KEY,
  title          VARCHAR(255) NOT NULL,
  author         VARCHAR(255) NOT NULL,
  isbn           VARCHAR(20)  NOT NULL UNIQUE,
  genre          VARCHAR(64)  NOT NULL,
  price          DECIMAL(8,2) NOT NULL,
  stock_quantity INT          NOT NULL DEFAULT 0
);

CREATE TABLE customers (
  customer_id      INT AUTO_INCREMENT PRIMARY KEY,
  first_name       VARCHAR(64)  NOT NULL,
  last_name        VARCHAR(64)  NOT NULL,
  email            VARCHAR(255) NOT NULL UNIQUE,
  shipping_address VARCHAR(255) NOT NULL,
  city             VARCHAR(64)  NOT NULL,
  state            VARCHAR(32)  NOT NULL,
  zip              VARCHAR(16)  NOT NULL
);

CREATE TABLE orders (
  order_id     INT AUTO_INCREMENT PRIMARY KEY,
  customer_id  INT NOT NULL,
  book_id      INT NOT NULL,
  quantity     INT NOT NULL,
  order_total  DECIMAL(10,2) NOT NULL,
  order_status ENUM('pending','paid','shipped','delivered') NOT NULL DEFAULT 'pending',
  order_date   DATETIME NOT NULL,
  CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
  CONSTRAINT fk_orders_book     FOREIGN KEY (book_id)     REFERENCES books_inventory(book_id)
);

CREATE INDEX idx_orders_customer ON orders(customer_id);

-- ─── Seed: 20 books ────────────────────────────────────────────────────────────
INSERT INTO books_inventory (title, author, isbn, genre, price, stock_quantity) VALUES
  ('The Midnight Library',      'Matt Haig',             '9780525559474', 'Fiction',    14.99, 120),
  ('Project Hail Mary',         'Andy Weir',             '9780593135204', 'Sci-Fi',     18.99,  85),
  ('Educated',                  'Tara Westover',         '9780399590504', 'Memoir',     13.50,  60),
  ('The Silent Patient',        'Alex Michaelides',      '9781250301697', 'Thriller',   12.99,  95),
  ('Atomic Habits',             'James Clear',           '9780735211292', 'Self-Help',  16.20, 200),
  ('Where the Crawdads Sing',   'Delia Owens',           '9780735219090', 'Fiction',    15.00,  75),
  ('Dune',                      'Frank Herbert',         '9780441013593', 'Sci-Fi',     11.99, 150),
  ('The Hobbit',                'J.R.R. Tolkien',        '9780547928227', 'Fantasy',    10.99, 300),
  ('Sapiens',                   'Yuval Noah Harari',     '9780062316097', 'History',    20.00, 110),
  ('The Great Gatsby',          'F. Scott Fitzgerald',   '9780743273565', 'Classic',     9.99, 180),
  ('1984',                      'George Orwell',         '9780451524935', 'Dystopian',   8.99, 220),
  ('Becoming',                  'Michelle Obama',        '9781524763138', 'Memoir',     17.99,  90),
  ('The Alchemist',             'Paulo Coelho',          '9780061122415', 'Fiction',    12.49, 130),
  ('Circe',                     'Madeline Miller',       '9780316556347', 'Fantasy',    14.75,  65),
  ('The Martian',               'Andy Weir',             '9780553418026', 'Sci-Fi',     13.99, 100),
  ('Normal People',             'Sally Rooney',          '9781984822185', 'Fiction',    11.50,  70),
  ('The Name of the Wind',      'Patrick Rothfuss',      '9780756404741', 'Fantasy',    15.99,  55),
  ('Thinking, Fast and Slow',   'Daniel Kahneman',       '9780374533557', 'Psychology', 18.00,  80),
  ('The Book Thief',            'Markus Zusak',          '9780375842207', 'Historical', 12.00,  95),
  ('A Little Life',             'Hanya Yanagihara',      '9780385539258', 'Fiction',    19.50,  40);

-- ─── Seed: 10 customers ──────────────────────────────────────────────────────
-- customer_id 1-5 are western (ship from CA); 6-10 eastern (ship from NY).
INSERT INTO customers (first_name, last_name, email, shipping_address, city, state, zip) VALUES
  ('Alice',  'Johnson',  'alice.johnson@example.com',  '123 Maple St',     'Los Angeles',   'CA', '90012'),
  ('Bob',    'Smith',    'bob.smith@example.com',      '456 Oak Ave',      'San Francisco', 'CA', '94103'),
  ('Carol',  'Williams', 'carol.williams@example.com', '789 Pine Rd',      'Seattle',       'WA', '98101'),
  ('David',  'Brown',    'david.brown@example.com',    '321 Elm St',       'Denver',        'CO', '80202'),
  ('Emma',   'Davis',    'emma.davis@example.com',     '654 Cedar Ln',     'Phoenix',       'AZ', '85004'),
  ('Frank',  'Miller',   'frank.miller@example.com',   '987 Birch Blvd',   'New York',      'NY', '10001'),
  ('Grace',  'Wilson',   'grace.wilson@example.com',   '147 Spruce Ct',    'Boston',        'MA', '02108'),
  ('Henry',  'Moore',    'henry.moore@example.com',    '258 Willow Way',   'Miami',         'FL', '33130'),
  ('Ivy',    'Taylor',   'ivy.taylor@example.com',     '369 Aspen Dr',     'Chicago',       'IL', '60601'),
  ('Jack',   'Anderson', 'jack.anderson@example.com',  '741 Poplar Pl',    'Atlanta',       'GA', '30303');

-- ─── Seed: 100 orders (10 per customer) ──────────────────────────────────────
DELIMITER $$
CREATE PROCEDURE seed_orders()
BEGIN
  DECLARE c INT DEFAULT 1;
  DECLARE o INT DEFAULT 1;
  WHILE c <= 10 DO
    SET o = 1;
    WHILE o <= 10 DO
      INSERT INTO orders (customer_id, book_id, quantity, order_total, order_status, order_date)
      SELECT c,
             b.book_id,
             1 + ((c + o) MOD 3)                       AS qty,
             (1 + ((c + o) MOD 3)) * b.price           AS total,
             ELT(1 + ((c + o) MOD 4), 'pending','paid','shipped','delivered'),
             DATE_SUB(NOW(), INTERVAL ((c * o) MOD 60) DAY)
      FROM books_inventory b
      WHERE b.book_id = 1 + ((c * 7 + o * 3) MOD 20);
      SET o = o + 1;
    END WHILE;
    SET c = c + 1;
  END WHILE;
END$$
DELIMITER ;

CALL seed_orders();
DROP PROCEDURE seed_orders;
