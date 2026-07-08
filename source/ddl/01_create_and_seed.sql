-- Retail Analytics POC — source schema + dummy data (Phase 1)
-- Target: database `testdb`, schema `retail`. Idempotent (drops & recreates schema).
-- Model per design/ARCHITECTURE.md §4. Every table carries updated_at for incremental sync.

DROP SCHEMA IF EXISTS retail CASCADE;
CREATE SCHEMA retail;
SET search_path TO retail;

-- ---------- tables ----------
CREATE TABLE customers (
    customer_id  SERIAL PRIMARY KEY,
    first_name   TEXT NOT NULL,
    last_name    TEXT NOT NULL,
    email        TEXT NOT NULL UNIQUE,
    phone        TEXT,
    city         TEXT,
    country      TEXT,
    signup_date  DATE NOT NULL,
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE products (
    product_id    SERIAL PRIMARY KEY,
    product_name  TEXT NOT NULL,
    category      TEXT,
    brand         TEXT,
    price         NUMERIC(10,2) NOT NULL CHECK (price >= 0),
    in_stock      BOOLEAN NOT NULL DEFAULT true,
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE orders (
    order_id      SERIAL PRIMARY KEY,
    customer_id   INT NOT NULL REFERENCES customers(customer_id),
    order_date    DATE NOT NULL,
    status        TEXT NOT NULL,
    total_amount  NUMERIC(12,2) NOT NULL DEFAULT 0,
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE order_items (
    order_item_id SERIAL PRIMARY KEY,
    order_id      INT NOT NULL REFERENCES orders(order_id),
    product_id    INT NOT NULL REFERENCES products(product_id),
    quantity      INT NOT NULL CHECK (quantity > 0),
    unit_price    NUMERIC(10,2) NOT NULL DEFAULT 0
);

CREATE TABLE payments (
    payment_id     SERIAL PRIMARY KEY,
    order_id       INT NOT NULL REFERENCES orders(order_id),
    payment_method TEXT NOT NULL,
    amount         NUMERIC(12,2) NOT NULL DEFAULT 0,
    payment_status TEXT NOT NULL,
    payment_date   DATE,
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- indexes that support incremental (cursor) extraction
CREATE INDEX idx_customers_updated ON customers(updated_at);
CREATE INDEX idx_products_updated  ON products(updated_at);
CREATE INDEX idx_orders_updated    ON orders(updated_at);
CREATE INDEX idx_payments_updated  ON payments(updated_at);
CREATE INDEX idx_order_items_order ON order_items(order_id);

-- ---------- dummy data ----------
-- 200 customers
INSERT INTO customers (first_name, last_name, email, phone, city, country, signup_date)
SELECT
    (ARRAY['James','Mary','John','Patricia','Robert','Jennifer','Michael','Linda','David','Sarah','Emma','Liam','Olivia','Noah'])[1+floor(random()*14)],
    (ARRAY['Smith','Johnson','Williams','Brown','Jones','Garcia','Miller','Davis','Rodriguez','Martinez'])[1+floor(random()*10)],
    'user' || g || '@example.com',
    '+1-555-' || lpad((floor(random()*10000))::int::text, 4, '0'),
    (ARRAY['New York','London','Toronto','Berlin','Paris','Sydney','Dhaka','Tokyo'])[1+floor(random()*8)],
    (ARRAY['USA','UK','Canada','Germany','France','Australia','Bangladesh','Japan'])[1+floor(random()*8)],
    current_date - (floor(random()*730))::int
FROM generate_series(1,200) g;

-- 60 products (placeholder; Phase-1 loader can later refresh from a public API)
INSERT INTO products (product_name, category, brand, price, in_stock)
SELECT
    (ARRAY['Wireless Mouse','Keyboard','Monitor','Laptop Stand','USB Cable','Headphones','Webcam','Desk Lamp','Backpack','Water Bottle','T-Shirt','Sneakers','Coffee Mug','Notebook','Phone Case'])[1+floor(random()*15)] || ' #' || g,
    (ARRAY['Electronics','Accessories','Apparel','Home','Office'])[1+floor(random()*5)],
    (ARRAY['Acme','Globex','Umbrella','Initech','Soylent','Hooli'])[1+floor(random()*6)],
    round((5 + random()*495)::numeric, 2),
    random() < 0.9
FROM generate_series(1,60) g;

-- 500 orders
INSERT INTO orders (customer_id, order_date, status)
SELECT
    1 + floor(random()*200)::int,
    current_date - (floor(random()*365))::int,
    (ARRAY['completed','completed','completed','pending','cancelled','returned'])[1+floor(random()*6)]
FROM generate_series(1,500) g;

-- 1..4 line items per order
INSERT INTO order_items (order_id, product_id, quantity)
SELECT o.order_id,
       1 + floor(random()*60)::int,
       1 + floor(random()*5)::int
FROM orders o
CROSS JOIN LATERAL generate_series(1, (1 + floor(random()*4))::int) gs;

-- price the line items from the product catalog
UPDATE order_items oi
SET unit_price = p.price
FROM products p
WHERE p.product_id = oi.product_id;

-- roll the order totals up from the line items
UPDATE orders o
SET total_amount = s.tot
FROM (SELECT order_id, sum(quantity * unit_price) AS tot
      FROM order_items GROUP BY order_id) s
WHERE s.order_id = o.order_id;

-- one payment per order, amount matches the order, status follows order status
INSERT INTO payments (order_id, payment_method, amount, payment_status, payment_date)
SELECT o.order_id,
       (ARRAY['card','paypal','bank_transfer','cash'])[1+floor(random()*4)],
       o.total_amount,
       CASE o.status
            WHEN 'completed' THEN 'paid'
            WHEN 'pending'   THEN 'pending'
            ELSE 'refunded'
       END,
       o.order_date + (floor(random()*3))::int
FROM orders o;
