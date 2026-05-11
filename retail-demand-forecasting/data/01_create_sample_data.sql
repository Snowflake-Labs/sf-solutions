----------------------------------------------------------------------
-- Retail Demand Forecasting & Inventory Optimization
-- Step 1: Create synthetic sales history data
----------------------------------------------------------------------

USE ROLE SYSADMIN;
CREATE DATABASE IF NOT EXISTS SF_SOLUTIONS;
CREATE SCHEMA IF NOT EXISTS SF_SOLUTIONS.RETAIL_DEMAND_FORECAST_RAW;
CREATE SCHEMA IF NOT EXISTS SF_SOLUTIONS.RETAIL_DEMAND_FORECAST_ANALYTICS;
CREATE SCHEMA IF NOT EXISTS SF_SOLUTIONS.RETAIL_DEMAND_FORECAST_ML;

USE SCHEMA SF_SOLUTIONS.RETAIL_DEMAND_FORECAST_RAW;

----------------------------------------------------------------------
-- Stores dimension
----------------------------------------------------------------------
CREATE OR REPLACE TABLE STORES (
    STORE_ID VARCHAR(10),
    STORE_NAME VARCHAR(100),
    CITY VARCHAR(50),
    STATE VARCHAR(50),
    REGION VARCHAR(20),
    STORE_TYPE VARCHAR(20),
    OPEN_DATE DATE
);

INSERT INTO STORES VALUES
('S001', 'Downtown Flagship', 'New York', 'NY', 'Northeast', 'Flagship', '2018-03-15'),
('S002', 'Midtown Express', 'New York', 'NY', 'Northeast', 'Express', '2019-06-01'),
('S003', 'Chicago Loop', 'Chicago', 'IL', 'Midwest', 'Standard', '2017-11-20'),
('S004', 'LA Beverly Hills', 'Los Angeles', 'CA', 'West', 'Flagship', '2016-08-10'),
('S005', 'SF Mission District', 'San Francisco', 'CA', 'West', 'Standard', '2020-01-15'),
('S006', 'Austin South Congress', 'Austin', 'TX', 'South', 'Standard', '2019-09-01'),
('S007', 'Miami Beach', 'Miami', 'FL', 'South', 'Express', '2021-03-01'),
('S008', 'Seattle Pike Place', 'Seattle', 'WA', 'West', 'Standard', '2018-07-20');

----------------------------------------------------------------------
-- Products dimension
----------------------------------------------------------------------
CREATE OR REPLACE TABLE PRODUCTS (
    PRODUCT_ID VARCHAR(10),
    PRODUCT_NAME VARCHAR(100),
    CATEGORY VARCHAR(50),
    SUBCATEGORY VARCHAR(50),
    UNIT_COST DECIMAL(10,2),
    UNIT_PRICE DECIMAL(10,2),
    SHELF_LIFE_DAYS INT,
    REORDER_POINT INT,
    REORDER_QTY INT
);

INSERT INTO PRODUCTS VALUES
('P001', 'Organic Whole Milk 1L', 'Dairy', 'Milk', 2.10, 4.99, 10, 50, 200),
('P002', 'Sourdough Bread Loaf', 'Bakery', 'Bread', 1.80, 5.49, 5, 30, 100),
('P003', 'Free Range Eggs 12pk', 'Dairy', 'Eggs', 2.50, 6.99, 21, 40, 150),
('P004', 'Avocado (each)', 'Produce', 'Fruit', 0.80, 2.49, 7, 80, 300),
('P005', 'Chicken Breast 500g', 'Meat', 'Poultry', 3.20, 8.99, 5, 25, 100),
('P006', 'Atlantic Salmon Fillet 200g', 'Seafood', 'Fish', 4.50, 12.99, 3, 15, 60),
('P007', 'Greek Yogurt 500g', 'Dairy', 'Yogurt', 1.60, 4.49, 14, 60, 200),
('P008', 'Sparkling Water 12pk', 'Beverages', 'Water', 3.00, 7.99, 365, 100, 400),
('P009', 'Premium Coffee Beans 500g', 'Beverages', 'Coffee', 6.00, 14.99, 180, 30, 120),
('P010', 'Seasonal Fruit Box', 'Produce', 'Fruit', 5.00, 15.99, 5, 20, 80),
('P011', 'Plant-Based Burger 4pk', 'Meat Alternatives', 'Frozen', 3.50, 9.99, 90, 35, 140),
('P012', 'Artisan Cheese Selection', 'Dairy', 'Cheese', 4.00, 11.99, 30, 20, 80);

----------------------------------------------------------------------
-- Daily sales transactions (2 years of history)
-- Uses a generator to create realistic patterns with:
--   - Day-of-week seasonality (weekends higher)
--   - Monthly seasonality (holidays, summer peaks)
--   - Store-level volume differences
--   - Product-level demand patterns
--   - Random noise + trend
----------------------------------------------------------------------
CREATE OR REPLACE TABLE DAILY_SALES AS
WITH date_spine AS (
    SELECT DATEADD(DAY, SEQ4(), '2023-01-01')::DATE AS SALE_DATE
    FROM TABLE(GENERATOR(ROWCOUNT => 850))
    WHERE SALE_DATE <= '2025-04-30'
),
store_product AS (
    SELECT S.STORE_ID, P.PRODUCT_ID, P.CATEGORY, P.UNIT_PRICE, P.UNIT_COST,
           CASE S.STORE_TYPE
               WHEN 'Flagship' THEN 2.0
               WHEN 'Standard' THEN 1.0
               WHEN 'Express' THEN 0.6
           END AS STORE_VOLUME_FACTOR,
           CASE P.CATEGORY
               WHEN 'Dairy' THEN 80
               WHEN 'Bakery' THEN 50
               WHEN 'Produce' THEN 70
               WHEN 'Meat' THEN 30
               WHEN 'Seafood' THEN 20
               WHEN 'Beverages' THEN 60
               WHEN 'Meat Alternatives' THEN 25
           END AS BASE_DAILY_UNITS
    FROM STORES S
    CROSS JOIN PRODUCTS P
),
sales_raw AS (
    SELECT
        d.SALE_DATE,
        sp.STORE_ID,
        sp.PRODUCT_ID,
        sp.CATEGORY,
        sp.UNIT_PRICE,
        sp.UNIT_COST,
        GREATEST(0, ROUND(
            sp.BASE_DAILY_UNITS * sp.STORE_VOLUME_FACTOR
            -- Day-of-week effect (weekends +30-50%)
            * (CASE DAYOFWEEK(d.SALE_DATE)
                WHEN 0 THEN 1.4  -- Sunday
                WHEN 6 THEN 1.5  -- Saturday
                WHEN 5 THEN 1.2  -- Friday
                ELSE 1.0
               END)
            -- Monthly seasonality
            * (CASE MONTH(d.SALE_DATE)
                WHEN 1 THEN 0.85  -- Post-holiday dip
                WHEN 2 THEN 0.90
                WHEN 3 THEN 0.95
                WHEN 4 THEN 1.00
                WHEN 5 THEN 1.05
                WHEN 6 THEN 1.15  -- Summer ramp
                WHEN 7 THEN 1.20  -- Peak summer
                WHEN 8 THEN 1.15
                WHEN 9 THEN 1.00
                WHEN 10 THEN 1.05
                WHEN 11 THEN 1.25  -- Thanksgiving
                WHEN 12 THEN 1.40  -- Holiday season
               END)
            -- Year-over-year growth trend (5% annual)
            * (1.0 + 0.05 * DATEDIFF(YEAR, '2023-01-01', d.SALE_DATE))
            -- Random noise (-15% to +15%)
            * (1.0 + (RANDOM() % 30 - 15) / 100.0)
        )) AS UNITS_SOLD
    FROM date_spine d
    CROSS JOIN store_product sp
)
SELECT
    SALE_DATE,
    STORE_ID,
    PRODUCT_ID,
    CATEGORY,
    UNITS_SOLD,
    ROUND(UNITS_SOLD * UNIT_PRICE, 2) AS REVENUE,
    ROUND(UNITS_SOLD * UNIT_COST, 2) AS COST,
    ROUND(UNITS_SOLD * (UNIT_PRICE - UNIT_COST), 2) AS GROSS_PROFIT
FROM sales_raw
WHERE UNITS_SOLD > 0
ORDER BY SALE_DATE, STORE_ID, PRODUCT_ID;

----------------------------------------------------------------------
-- Current inventory snapshot
----------------------------------------------------------------------
CREATE OR REPLACE TABLE INVENTORY_SNAPSHOT AS
SELECT
    CURRENT_DATE() AS SNAPSHOT_DATE,
    S.STORE_ID,
    P.PRODUCT_ID,
    P.PRODUCT_NAME,
    P.REORDER_POINT,
    P.REORDER_QTY,
    P.SHELF_LIFE_DAYS,
    -- Simulate current stock levels (some intentionally low)
    CASE
        WHEN UNIFORM(1, 10, RANDOM()) <= 3 THEN UNIFORM(5, P.REORDER_POINT - 1, RANDOM())  -- 30% below reorder point
        ELSE UNIFORM(P.REORDER_POINT, P.REORDER_POINT * 3, RANDOM())
    END AS CURRENT_STOCK,
    DATEADD(DAY, -UNIFORM(0, GREATEST(1, P.SHELF_LIFE_DAYS - 2), RANDOM()), DATEADD(DAY, P.SHELF_LIFE_DAYS, CURRENT_DATE())) AS EARLIEST_EXPIRY_DATE
FROM STORES S
CROSS JOIN PRODUCTS P;

----------------------------------------------------------------------
-- Verify data
----------------------------------------------------------------------
SELECT 'STORES' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM STORES
UNION ALL
SELECT 'PRODUCTS', COUNT(*) FROM PRODUCTS
UNION ALL
SELECT 'DAILY_SALES', COUNT(*) FROM DAILY_SALES
UNION ALL
SELECT 'INVENTORY_SNAPSHOT', COUNT(*) FROM INVENTORY_SNAPSHOT;
