CREATE DATABASE d2c_simulator;
USE d2c_simulator;

CREATE TABLE transactions (
    Invoice VARCHAR(20),
    StockCode VARCHAR(20),
    Description VARCHAR(255),
    Quantity INT,
    InvoiceDate DATETIME,
    Price DECIMAL(10,2),
    CustomerID INT,
    Country VARCHAR(100),
    SourcePeriod VARCHAR(20),
    Revenue DECIMAL(12,2)
);

SELECT COUNT(*) FROM transactions;

TRUNCATE TABLE transactions;

SHOW VARIABLES LIKE 'secure_file_priv';

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/online_retail_cleaned.csv'
INTO TABLE transactions
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(Invoice, StockCode, Description, Quantity, InvoiceDate, Price, CustomerID, Country, SourcePeriod, Revenue);

SELECT COUNT(*) FROM transactions;

SELECT * FROM transactions LIMIT 10;

SELECT MIN(InvoiceDate), MAX(InvoiceDate) FROM transactions;

SELECT SUM(Revenue) FROM transactions;

SELECT COUNT(DISTINCT CustomerID) FROM transactions;


-- ============================================
-- METRIC 1: Monthly Revenue Trend
-- WHY: Shows overall business seasonality and growth pattern, 
-- and gives us a baseline to compare simulated scenarios against
-- ============================================

SELECT 
    DATE_FORMAT(InvoiceDate, '%Y-%m') AS Month,
    SUM(Revenue) AS MonthlyRevenue,
    COUNT(DISTINCT Invoice) AS OrderCount,
    COUNT(DISTINCT CustomerID) AS ActiveCustomers
FROM transactions
GROUP BY DATE_FORMAT(InvoiceDate, '%Y-%m')
ORDER BY Month;

-- ============================================
-- METRIC 2: Average Order Value (AOV)
-- WHY: AOV is one of the core levers in the growth model 
-- (Revenue = Customers × Frequency × AOV). We need the real 
-- monthly AOV to calibrate the simulator's baseline.
-- ============================================\

SELECT 
    DATE_FORMAT(InvoiceDate, '%Y-%m') AS Month,
    SUM(Revenue) / COUNT(DISTINCT Invoice) AS AOV
FROM transactions
GROUP BY DATE_FORMAT(InvoiceDate, '%Y-%m')
ORDER BY Month;

-- ============================================
-- METRIC 3: Purchase Frequency (Orders per Active Customer)
-- WHY: This is the third lever in the growth model 
-- (Revenue = Customers × Frequency × AOV). It tells us, on 
-- average, how many separate orders each active customer 
-- places per month — a key input for the simulator baseline.
-- ============================================
SELECT 
    DATE_FORMAT(InvoiceDate, '%Y-%m') AS Month,
    COUNT(DISTINCT Invoice) / COUNT(DISTINCT CustomerID) AS AvgOrdersPerCustomer
FROM transactions
GROUP BY DATE_FORMAT(InvoiceDate, '%Y-%m')
ORDER BY Month;

-- ============================================
-- METRIC 4: Monthly Customer Retention Rate
-- WHY: Retention is a critical growth lever — it's usually 
-- cheaper to keep an existing customer than acquire a new one.
-- This measures what % of customers active in one month also 
-- purchased in the following month, which will calibrate the 
-- "churn/retention" slider in the simulator.
-- ============================================

-- Step A: Get distinct (CustomerID, Month) pairs — one row per 
-- customer per month they were active
WITH customer_months AS (
    SELECT DISTINCT 
        CustomerID,
        DATE_FORMAT(InvoiceDate, '%Y-%m-01') AS ActivityMonth
    FROM transactions
),

-- Step B: For each customer-month, find their NEXT month
customer_next_month AS (
    SELECT 
        CustomerID,
        ActivityMonth,
        DATE_ADD(ActivityMonth, INTERVAL 1 MONTH) AS NextExpectedMonth
    FROM customer_months
)

-- Step C: Check if that customer actually appears in the next month
SELECT 
    cnm.ActivityMonth,
    COUNT(DISTINCT cnm.CustomerID) AS CustomersThisMonth,
    COUNT(DISTINCT cm2.CustomerID) AS RetainedNextMonth,
    ROUND(COUNT(DISTINCT cm2.CustomerID) / COUNT(DISTINCT cnm.CustomerID) * 100, 2) AS RetentionRatePct
FROM customer_next_month cnm
LEFT JOIN customer_months cm2 
    ON cnm.CustomerID = cm2.CustomerID 
    AND cnm.NextExpectedMonth = cm2.ActivityMonth
GROUP BY cnm.ActivityMonth
ORDER BY cnm.ActivityMonth;

-- ============================================
-- METRIC 5: New Customers Acquired Per Month
-- WHY: The growth model needs to know how many brand-new 
-- customers this business historically gained each month, 
-- so the simulator can project the customer base forward 
-- realistically (Next Month's Customers = Retained + New).
-- ============================================
WITH first_purchase AS (
    SELECT 
        CustomerID,
        MIN(DATE_FORMAT(InvoiceDate, '%Y-%m-01')) AS FirstPurchaseMonth
    FROM transactions
    GROUP BY CustomerID
)
SELECT 
    FirstPurchaseMonth,
    COUNT(DISTINCT CustomerID) AS NewCustomers
FROM first_purchase
GROUP BY FirstPurchaseMonth
ORDER BY FirstPurchaseMonth;

-- ============================================
-- METRIC 6: Customer Inflow Breakdown (New vs Returning vs Retained)
-- WHY: The first growth model collapsed because it only counted
-- brand-new customers as inflow. This query measures how many
-- customers each month were new, returning after a gap, or
-- retained from the previous month, so the model can be recalibrated.
-- ============================================
WITH customer_months AS (
    SELECT DISTINCT
        CustomerID,
        DATE_FORMAT(InvoiceDate, '%Y-%m-01') AS ActivityMonth
    FROM transactions
),
with_previous AS (
    SELECT
        CustomerID,
        ActivityMonth,
        LAG(ActivityMonth) OVER (
            PARTITION BY CustomerID ORDER BY ActivityMonth
        ) AS PreviousActiveMonth
    FROM customer_months
)
SELECT
    ActivityMonth,
    COUNT(*) AS ActiveCustomers,
    SUM(CASE WHEN PreviousActiveMonth IS NULL THEN 1 ELSE 0 END) AS NewCustomers,
    SUM(CASE WHEN PreviousActiveMonth IS NOT NULL
              AND TIMESTAMPDIFF(MONTH, PreviousActiveMonth, ActivityMonth) = 1
             THEN 1 ELSE 0 END) AS RetainedCustomers,
    SUM(CASE WHEN PreviousActiveMonth IS NOT NULL
              AND TIMESTAMPDIFF(MONTH, PreviousActiveMonth, ActivityMonth) > 1
             THEN 1 ELSE 0 END) AS ReturningCustomers
FROM with_previous
GROUP BY ActivityMonth
ORDER BY ActivityMonth;