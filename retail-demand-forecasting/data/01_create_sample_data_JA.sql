----------------------------------------------------------------------
-- 小売 需要予測・在庫最適化
-- Step 1: サンプルデータ作成（日本市場版）
----------------------------------------------------------------------

USE ROLE SYSADMIN;
CREATE DATABASE IF NOT EXISTS SF_SOLUTIONS;
CREATE SCHEMA IF NOT EXISTS SF_SOLUTIONS.RETAIL_DEMAND_FORECAST_RAW;
CREATE SCHEMA IF NOT EXISTS SF_SOLUTIONS.RETAIL_DEMAND_FORECAST_ANALYTICS;
CREATE SCHEMA IF NOT EXISTS SF_SOLUTIONS.RETAIL_DEMAND_FORECAST_ML;

USE SCHEMA SF_SOLUTIONS.RETAIL_DEMAND_FORECAST_RAW;

----------------------------------------------------------------------
-- 店舗マスタ
----------------------------------------------------------------------
CREATE OR REPLACE TABLE STORES (
    STORE_ID INT,
    STORE_NAME VARCHAR(200),
    REGION VARCHAR(50),
    PREFECTURE VARCHAR(50),
    STORE_SIZE VARCHAR(20),
    OPENING_DATE DATE
);

INSERT INTO STORES VALUES
(1, '渋谷センター店', '関東', '東京都', '大型', '2018-04-01'),
(2, '横浜みなとみらい店', '関東', '神奈川県', '大型', '2019-07-15'),
(3, '梅田駅前店', '関西', '大阪府', '中型', '2020-01-10'),
(4, '名古屋栄店', '中部', '愛知県', '中型', '2019-11-01'),
(5, '福岡天神店', '九州', '福岡県', '小型', '2021-03-20');

----------------------------------------------------------------------
-- 商品マスタ
----------------------------------------------------------------------
CREATE OR REPLACE TABLE PRODUCTS (
    PRODUCT_ID INT,
    PRODUCT_NAME VARCHAR(200),
    CATEGORY VARCHAR(100),
    SUBCATEGORY VARCHAR(100),
    UNIT_PRICE DECIMAL(10,2),
    COST_PRICE DECIMAL(10,2),
    SUPPLIER VARCHAR(200),
    LEAD_TIME_DAYS INT
);

INSERT INTO PRODUCTS VALUES
(1, 'オーガニック牛乳 1L', '飲料', '乳製品', 298, 180, '北海道ファーム', 2),
(2, 'プレミアムコーヒー豆 200g', '飲料', 'コーヒー', 980, 550, 'ブラジル珈琲商社', 7),
(3, '国産鶏もも肉 300g', '精肉', '鶏肉', 498, 320, '九州ブロイラー', 1),
(4, '有機バナナ 1房', '青果', 'フルーツ', 198, 100, 'フィリピン青果', 3),
(5, '全粒粉食パン 6枚切', 'パン', '食パン', 248, 140, '石窯ベーカリー', 1),
(6, '特選醤油 500ml', '調味料', '醤油', 398, 220, '老舗醸造', 5),
(7, '冷凍餃子 12個入', '冷凍食品', '中華', 358, 200, '宇都宮食品', 3),
(8, 'ヨーグルト 400g', '飲料', '乳製品', 178, 95, '北海道ファーム', 2),
(9, 'カップ麺 しょうゆ味', '即席麺', 'カップ麺', 198, 110, '大手食品メーカー', 4),
(10, 'ミネラルウォーター 2L', '飲料', '水', 98, 40, '南アルプス水源', 2),
(11, 'ポテトチップス うすしお', 'スナック', 'ポテト系', 158, 85, '湖池屋食品', 3),
(12, '豆腐 絹ごし 300g', '日配品', '豆腐', 88, 45, '京都豆腐店', 1),
(13, 'トマト缶 400g', '缶詰', '野菜缶', 128, 65, 'イタリア食品', 10),
(14, 'バター 200g', '飲料', '乳製品', 448, 300, '北海道ファーム', 3),
(15, '卵 10個入パック', '日配品', '卵', 268, 180, '地鶏農園', 1);

----------------------------------------------------------------------
-- 販売履歴（2年分）
-- パターン:
--   - 曜日効果（週末 +30%）
--   - 季節性（夏: 飲料↑、冬: 冷凍食品↑）
--   - 店舗規模による販売量差
--   - 年次成長 +5%
--   - ランダムノイズ
----------------------------------------------------------------------
CREATE OR REPLACE TABLE SALES_HISTORY AS
WITH date_range AS (
    SELECT DATEADD('day', SEQ4(), '2023-01-01')::DATE AS SALE_DATE
    FROM TABLE(GENERATOR(ROWCOUNT => 850))
    WHERE DATEADD('day', SEQ4(), '2023-01-01')::DATE <= '2025-04-30'
),
base_sales AS (
    SELECT
        d.SALE_DATE,
        p.PRODUCT_ID,
        s.STORE_ID,
        GREATEST(1, ROUND(
            (CASE s.STORE_SIZE WHEN '大型' THEN 50 WHEN '中型' THEN 30 ELSE 15 END)
            * (CASE p.CATEGORY
                WHEN '飲料' THEN 1.5
                WHEN '日配品' THEN 1.3
                WHEN '精肉' THEN 1.0
                ELSE 0.8 END)
            * (CASE WHEN DAYOFWEEK(d.SALE_DATE) IN (0, 6) THEN 1.3 ELSE 1.0 END)
            * (CASE
                WHEN MONTH(d.SALE_DATE) IN (7, 8) AND p.CATEGORY = '飲料' THEN 1.8
                WHEN MONTH(d.SALE_DATE) IN (12, 1) AND p.CATEGORY = '冷凍食品' THEN 1.5
                WHEN MONTH(d.SALE_DATE) IN (3, 4) AND p.CATEGORY = 'スナック' THEN 1.2
                ELSE 1.0 END)
            * (0.7 + UNIFORM(0::FLOAT, 0.6::FLOAT, RANDOM()))
            * (1.0 + 0.05 * DATEDIFF(YEAR, '2023-01-01', d.SALE_DATE))
        )) AS QUANTITY_SOLD,
        p.UNIT_PRICE,
        p.COST_PRICE
    FROM date_range d
    CROSS JOIN PRODUCTS p
    CROSS JOIN STORES s
)
SELECT
    ROW_NUMBER() OVER (ORDER BY SALE_DATE, STORE_ID, PRODUCT_ID) AS TRANSACTION_ID,
    SALE_DATE,
    STORE_ID,
    PRODUCT_ID,
    QUANTITY_SOLD,
    ROUND(QUANTITY_SOLD * UNIT_PRICE, 0) AS REVENUE,
    ROUND(QUANTITY_SOLD * COST_PRICE, 0) AS COST,
    ROUND(QUANTITY_SOLD * (UNIT_PRICE - COST_PRICE), 0) AS GROSS_PROFIT
FROM base_sales;

----------------------------------------------------------------------
-- 在庫スナップショット
----------------------------------------------------------------------
CREATE OR REPLACE TABLE INVENTORY AS
SELECT
    s.STORE_ID,
    p.PRODUCT_ID,
    p.PRODUCT_NAME,
    CASE
        WHEN UNIFORM(1, 10, RANDOM()) <= 3 THEN UNIFORM(3, 15, RANDOM())
        ELSE UNIFORM(20, 100, RANDOM())
    END AS CURRENT_STOCK,
    CASE s.STORE_SIZE WHEN '大型' THEN 30 WHEN '中型' THEN 20 ELSE 10 END AS REORDER_POINT,
    CASE s.STORE_SIZE WHEN '大型' THEN 200 WHEN '中型' THEN 120 ELSE 60 END AS MAX_STOCK,
    p.LEAD_TIME_DAYS,
    DATEADD('day', -UNIFORM(0, 5, RANDOM()), CURRENT_DATE()) AS LAST_REPLENISHED
FROM STORES s
CROSS JOIN PRODUCTS p;

----------------------------------------------------------------------
-- データ確認
----------------------------------------------------------------------
SELECT 'STORES' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM STORES
UNION ALL
SELECT 'PRODUCTS', COUNT(*) FROM PRODUCTS
UNION ALL
SELECT 'SALES_HISTORY', COUNT(*) FROM SALES_HISTORY
UNION ALL
SELECT 'INVENTORY', COUNT(*) FROM INVENTORY;
