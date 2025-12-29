/* =========================================================
   FOOD ORDER SYSTEM – SCHEMA + DATA
   Target DB: SQL Server 2022
   ========================================================= */

------------------------------------------------------------
-- 1. DATABASE
------------------------------------------------------------
IF DB_ID('food_order_db') IS NULL
    CREATE DATABASE food_order_db;
GO

USE food_order_db;
GO

------------------------------------------------------------
-- 2. DROP EXISTING TABLES (SAFE RE-RUN)
------------------------------------------------------------
IF OBJECT_ID('payment') IS NOT NULL DROP TABLE payment;
IF OBJECT_ID('order_item') IS NOT NULL DROP TABLE order_item;
IF OBJECT_ID('food_order') IS NOT NULL DROP TABLE food_order;
IF OBJECT_ID('food_item') IS NOT NULL DROP TABLE food_item;
IF OBJECT_ID('address') IS NOT NULL DROP TABLE address;
IF OBJECT_ID('customer') IS NOT NULL DROP TABLE customer;
GO

------------------------------------------------------------
-- 3. TABLES
------------------------------------------------------------

-- CUSTOMER
CREATE TABLE customer (
    id BIGINT IDENTITY PRIMARY KEY,
    name NVARCHAR(100) NOT NULL,
    email NVARCHAR(150) NOT NULL UNIQUE,
    created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    version BIGINT NOT NULL DEFAULT 0
);

-- ADDRESS
CREATE TABLE address (
    id BIGINT IDENTITY PRIMARY KEY,
    customer_id BIGINT NOT NULL,
    city NVARCHAR(100),
    country NVARCHAR(100),
    CONSTRAINT fk_address_customer
        FOREIGN KEY (customer_id) REFERENCES customer(id)
);

-- FOOD ITEM
CREATE TABLE food_item (
    id BIGINT IDENTITY PRIMARY KEY,
    name NVARCHAR(150) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    category NVARCHAR(50),
    version BIGINT NOT NULL DEFAULT 0
);

-- FOOD ORDER
CREATE TABLE food_order (
    id BIGINT IDENTITY PRIMARY KEY,
    customer_id BIGINT NOT NULL,
    order_time DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    status NVARCHAR(30),
    total_amount DECIMAL(12,2),
    version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT fk_order_customer
        FOREIGN KEY (customer_id) REFERENCES customer(id)
);

-- ORDER ITEM
CREATE TABLE order_item (
    id BIGINT IDENTITY PRIMARY KEY,
    order_id BIGINT NOT NULL,
    food_item_id BIGINT NOT NULL,
    quantity INT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    CONSTRAINT fk_item_order
        FOREIGN KEY (order_id) REFERENCES food_order(id),
    CONSTRAINT fk_item_food
        FOREIGN KEY (food_item_id) REFERENCES food_item(id)
);

-- PAYMENT
CREATE TABLE payment (
    id BIGINT IDENTITY PRIMARY KEY,
    order_id BIGINT NOT NULL,
    payment_mode NVARCHAR(50),
    payment_status NVARCHAR(30),
    paid_at DATETIME2,
    CONSTRAINT fk_payment_order
        FOREIGN KEY (order_id) REFERENCES food_order(id)
);
GO

------------------------------------------------------------
-- 4. INDEXES (PAGINATION / SORTING)
------------------------------------------------------------
CREATE INDEX idx_customer_created_at ON customer(created_at);
CREATE INDEX idx_order_customer_id ON food_order(customer_id);
CREATE INDEX idx_order_order_time ON food_order(order_time);
CREATE INDEX idx_order_status ON food_order(status);
CREATE INDEX idx_food_item_category ON food_item(category);
GO

------------------------------------------------------------
-- 5. DATA GENERATION
------------------------------------------------------------

-- Helper numbers table (1–300)
WITH nums AS (
    SELECT TOP (300) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.objects
)
SELECT * INTO #numbers FROM nums;

-- CUSTOMERS (300)
INSERT INTO customer (name, email)
SELECT 
    CONCAT('Customer-', n),
    CONCAT('customer', n, '@mail.com')
FROM #numbers;

-- ADDRESSES (300)
INSERT INTO address (customer_id, city, country)
SELECT 
    id,
    CONCAT('City-', id),
    'UK'
FROM customer;

-- FOOD ITEMS (300)
INSERT INTO food_item (name, price, category)
SELECT 
    CONCAT('Food-', n),
    (ABS(CHECKSUM(NEWID())) % 2000) / 100.0 + 5,
    CASE 
        WHEN n % 3 = 0 THEN 'VEG'
        WHEN n % 3 = 1 THEN 'NON_VEG'
        ELSE 'DRINK'
    END
FROM #numbers;

-- FOOD ORDERS (300)
INSERT INTO food_order (customer_id, status, total_amount)
SELECT 
    c.id,
    CASE 
        WHEN c.id % 3 = 0 THEN 'CREATED'
        WHEN c.id % 3 = 1 THEN 'PAID'
        ELSE 'DELIVERED'
    END,
    (ABS(CHECKSUM(NEWID())) % 5000) / 100.0 + 20
FROM customer c;

-- ORDER ITEMS (900+)
INSERT INTO order_item (order_id, food_item_id, quantity, price)
SELECT 
    o.id,
    f.id,
    (ABS(CHECKSUM(NEWID())) % 3) + 1,
    f.price
FROM food_order o
CROSS APPLY (
    SELECT TOP 3 * FROM food_item ORDER BY NEWID()
) f;

-- PAYMENTS (300)
INSERT INTO payment (order_id, payment_mode, payment_status, paid_at)
SELECT 
    id,
    CASE 
        WHEN id % 2 = 0 THEN 'CARD'
        ELSE 'UPI'
    END,
    'SUCCESS',
    DATEADD(MINUTE, -id, SYSDATETIME())
FROM food_order;

-- CLEANUP
DROP TABLE #numbers;
GO

------------------------------------------------------------
-- 6. QUICK SANITY CHECK
------------------------------------------------------------
SELECT 'customer' AS table_name, COUNT(*) AS records FROM customer
UNION ALL
SELECT 'address', COUNT(*) FROM address
UNION ALL
SELECT 'food_item', COUNT(*) FROM food_item
UNION ALL
SELECT 'food_order', COUNT(*) FROM food_order
UNION ALL
SELECT 'order_item', COUNT(*) FROM order_item
UNION ALL
SELECT 'payment', COUNT(*) FROM payment;
GO

