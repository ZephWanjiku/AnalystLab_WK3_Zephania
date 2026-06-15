/* =========================================================================
   ANALYSTLAB AFRICA - DATA ANALYTICS INTERNSHIP (BATCH B)
   WEEK 3: SQL & DATA QUERYING
   DATASET 2: Sample Sales Data (Kaggle - kyanyoga/sample-sales-data)
   SQL Server (T-SQL) - Run in SSMS

   Table: SalesData
   Key columns:
   ORDERNUMBER, QUANTITYORDERED, PRICEEACH, ORDERLINENUMBER, SALES,
   ORDERDATE, STATUS, QTR_ID, MONTH_ID, YEAR_ID, PRODUCTLINE, MSRP,
   PRODUCTCODE, CUSTOMERNAME, PHONE, CITY, STATE, COUNTRY, TERRITORY,
   CONTACTLASTNAME, CONTACTFIRSTNAME, DEALSIZE

   ========================================================================= */

USE SalesDB;
GO

/* =========================================================================
   SECTION 1: CORE SQL QUERIES
   ========================================================================= */

-- 1.1 SELECT / WHERE / ORDER BY



-- 1.2 GROUP BY / HAVING / Aggregate functions (SUM, AVG, COUNT)
-- Business question: Which product lines generate more than $500,000
-- in total sales, and what is their average order value?
SELECT
    PRODUCTLINE,
    COUNT(DISTINCT ORDERNUMBER) AS NumberOfOrders,
    SUM(SALES) AS TotalSales,
    AVG(SALES) AS AvgSaleAmount
FROM SalesData
GROUP BY PRODUCTLINE
HAVING SUM(SALES) > 500000
ORDER BY TotalSales DESC;


/* =========================================================================
   SECTION 2: ADVANCED SQL CONCEPTS

   NOTE: This dataset is a single denormalized table (one row per order
   line), so JOIN examples below use a small reference table created for
   demonstration purposes - this mirrors how you'd join sales data against
   a separate "territory targets" or "lookup" table in a real environment.
   ========================================================================= */

-- Create a small reference table of regional sales targets (for JOIN demos)
IF OBJECT_ID('TerritoryTargets', 'U') IS NOT NULL
    DROP TABLE TerritoryTargets;

CREATE TABLE TerritoryTargets (
    TERRITORY   VARCHAR(50) PRIMARY KEY,
    SalesTarget DECIMAL(12,2)
);

INSERT INTO TerritoryTargets (TERRITORY, SalesTarget) VALUES
    ('EMEA', 1000000),
    ('APAC', 500000),
    ('Japan', 300000);
    -- NOTE: 'NA' (North America) is intentionally left out to demonstrate
    -- LEFT/RIGHT JOIN behaviour with non-matching rows.


-- 2.1 INNER JOIN
-- Business question: For territories with a defined sales target, what is
-- the actual total sales achieved vs the target?
SELECT
    s.TERRITORY,
    SUM(s.SALES) AS ActualSales,
    tt.SalesTarget
FROM SalesData s
INNER JOIN TerritoryTargets tt ON s.TERRITORY = tt.TERRITORY
GROUP BY s.TERRITORY, tt.SalesTarget
ORDER BY ActualSales DESC;


-- 2.2 LEFT JOIN
-- Business question: Show actual sales for ALL territories, including
-- those that don't have a target defined (target will show as NULL)
SELECT
    s.TERRITORY,
    SUM(s.SALES) AS ActualSales,
    tt.SalesTarget
FROM SalesData s
LEFT JOIN TerritoryTargets tt ON s.TERRITORY = tt.TERRITORY
GROUP BY s.TERRITORY, tt.SalesTarget
ORDER BY ActualSales DESC;


-- 2.3 RIGHT JOIN
-- Business question: Show every defined target territory, including any
-- target territory that (hypothetically) has no matching sales records
SELECT
    s.TERRITORY,
    SUM(s.SALES) AS ActualSales,
    tt.TERRITORY AS TargetTerritory,
    tt.SalesTarget
FROM SalesData s
RIGHT JOIN TerritoryTargets tt ON s.TERRITORY = tt.TERRITORY
GROUP BY s.TERRITORY, tt.TERRITORY, tt.SalesTarget
ORDER BY tt.SalesTarget DESC;


-- 2.4 Subquery
-- Business question: Which customers have placed orders with a total
-- value greater than the overall average order value?
SELECT
    CUSTOMERNAME,
    COUNT(DISTINCT ORDERNUMBER) AS NumberOfOrders,
    SUM(SALES) AS TotalSpent
FROM SalesData
GROUP BY CUSTOMERNAME
HAVING SUM(SALES) > (
    SELECT AVG(OrderTotal)
    FROM (
        SELECT SUM(SALES) AS OrderTotal
        FROM SalesData
        GROUP BY ORDERNUMBER
    ) AS PerOrderTotals
)
ORDER BY TotalSpent DESC;


-- 2.5 Window Functions - RANK() with PARTITION BY
-- Business question: Rank customers by total spend within each country
SELECT
    COUNTRY,
    CUSTOMERNAME,
    SUM(SALES) AS TotalSpent,
    RANK() OVER (PARTITION BY COUNTRY ORDER BY SUM(SALES) DESC) AS RankInCountry
FROM SalesData
GROUP BY COUNTRY, CUSTOMERNAME
ORDER BY COUNTRY, RankInCountry;


-- 2.6 Window Functions - ROW_NUMBER() with PARTITION BY
-- Business question: What is the single best month (by sales) for each
-- product line?
SELECT *
FROM (
    SELECT
        PRODUCTLINE,
        YEAR_ID,
        MONTH_ID,
        SUM(SALES) AS MonthlySales,
        ROW_NUMBER() OVER (PARTITION BY PRODUCTLINE ORDER BY SUM(SALES) DESC) AS rn
    FROM SalesData
    GROUP BY PRODUCTLINE, YEAR_ID, MONTH_ID
) AS RankedMonths
WHERE rn = 1
ORDER BY MonthlySales DESC;


/* =========================================================================
   SECTION 3: BUSINESS PROBLEM SOLVING
   ========================================================================= */

-- 3.1 Top-performing customers (Top 10 by total sales)
SELECT TOP 10
    CUSTOMERNAME,
    COUNTRY,
    SUM(SALES) AS TotalSales,
    COUNT(DISTINCT ORDERNUMBER) AS NumberOfOrders
FROM SalesData
GROUP BY CUSTOMERNAME, COUNTRY
ORDER BY TotalSales DESC;


-- 3.2 Top-performing products (by product line)
SELECT
    PRODUCTLINE,
    SUM(QUANTITYORDERED) AS TotalUnitsSold,
    SUM(SALES) AS TotalSales
FROM SalesData
GROUP BY PRODUCTLINE
ORDER BY TotalSales DESC;


-- 3.3 Revenue trends over time (by year and quarter)
SELECT
    YEAR_ID,
    QTR_ID,
    SUM(SALES) AS QuarterlySales,
    COUNT(DISTINCT ORDERNUMBER) AS NumberOfOrders
FROM SalesData
GROUP BY YEAR_ID, QTR_ID
ORDER BY YEAR_ID, QTR_ID;


-- 3.4 Customer purchasing behavior: order frequency & average order value
SELECT
    CUSTOMERNAME,
    COUNT(DISTINCT ORDERNUMBER) AS NumberOfOrders,
    SUM(SALES) AS TotalSpent,
    SUM(SALES) / COUNT(DISTINCT ORDERNUMBER) AS AvgOrderValue
FROM SalesData
GROUP BY CUSTOMERNAME
ORDER BY NumberOfOrders DESC;


-- 3.5 Order status breakdown (operational insight)
SELECT
    STATUS,
    COUNT(DISTINCT ORDERNUMBER) AS NumberOfOrders,
    SUM(SALES) AS TotalSales
FROM SalesData
GROUP BY STATUS
ORDER BY NumberOfOrders DESC;


/* =========================================================================
   SECTION 4: QUERY OPTIMIZATION (INDEXING)
   ========================================================================= */

-- These columns are used heavily in GROUP BY, JOIN and filter conditions
-- above. Adding indexes speeds up these operations on larger datasets.

CREATE NONCLUSTERED INDEX IX_SalesData_Territory
    ON SalesData(TERRITORY);

CREATE NONCLUSTERED INDEX IX_SalesData_ProductLine
    ON SalesData(PRODUCTLINE);

CREATE NONCLUSTERED INDEX IX_SalesData_CustomerName
    ON SalesData(CUSTOMERNAME);

CREATE NONCLUSTERED INDEX IX_SalesData_OrderNumber
    ON SalesData(ORDERNUMBER);

