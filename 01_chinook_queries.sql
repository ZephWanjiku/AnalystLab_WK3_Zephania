/* =========================================================================
   ANALYSTLAB AFRICA - DATA ANALYTICS INTERNSHIP (BATCH B)
   WEEK 3: SQL & DATA QUERYING
   DATASET 1: Chinook Database (Digital Music Store)
   SQL Server (T-SQL) - Run in SSMS

   Schema reference (key tables):
   Customer(CustomerId, FirstName, LastName, Country, ...)
   Invoice(InvoiceId, CustomerId, InvoiceDate, BillingCountry, Total)
   InvoiceLine(InvoiceLineId, InvoiceId, TrackId, UnitPrice, Quantity)
   Track(TrackId, Name, AlbumId, GenreId, Milliseconds, UnitPrice)
   Album(AlbumId, Title, ArtistId)
   Artist(ArtistId, Name)
   Genre(GenreId, Name)
   Employee(EmployeeId, FirstName, LastName, Title, ReportsTo)
   ========================================================================= */

USE Chinook;
GO

/* =========================================================================
   SECTION 1: CORE SQL QUERIES
   ========================================================================= */

-- 1.1 SELECT / WHERE / ORDER BY
-- Business question: Which tracks are priced above $0.99, sorted by price?
SELECT
    Name        AS TrackName,
    UnitPrice,
    Milliseconds / 1000.0 / 60 AS DurationMinutes
FROM Track
WHERE UnitPrice > 0.99
ORDER BY UnitPrice DESC;


-- 1.2 GROUP BY / HAVING / Aggregate functions (SUM, AVG, COUNT)
-- Business question: Which genres generate more than $400 in total revenue?
SELECT
    g.Name              AS Genre,
    COUNT(il.InvoiceLineId) AS UnitsSold,
    SUM(il.UnitPrice * il.Quantity) AS TotalRevenue,
    AVG(il.UnitPrice)   AS AvgUnitPrice
FROM InvoiceLine il
INNER JOIN Track t  ON il.TrackId = t.TrackId
INNER JOIN Genre g  ON t.GenreId  = g.GenreId
GROUP BY g.Name
HAVING SUM(il.UnitPrice * il.Quantity) > 400
ORDER BY TotalRevenue DESC;


/* =========================================================================
   SECTION 2: ADVANCED SQL CONCEPTS
   ========================================================================= */

-- 2.1 INNER JOIN
-- Business question: Show every invoice with the customer who placed it
SELECT
    c.CustomerId,
    c.FirstName + ' ' + c.LastName AS CustomerName,
    i.InvoiceId,
    i.InvoiceDate,
    i.Total
FROM Customer c
INNER JOIN Invoice i ON c.CustomerId = i.CustomerId
ORDER BY i.Total DESC;


-- 2.2 LEFT JOIN
-- Business question: Are there any customers who have never placed an order?
SELECT
    c.CustomerId,
    c.FirstName + ' ' + c.LastName AS CustomerName,
    i.InvoiceId
FROM Customer c
LEFT JOIN Invoice i ON c.CustomerId = i.CustomerId
WHERE i.InvoiceId IS NULL;


-- 2.3 RIGHT JOIN
-- Business question: List every genre and the tracks under it,
-- including genres that currently have no tracks assigned
SELECT
    g.Name AS Genre,
    t.Name AS TrackName
FROM Track t
RIGHT JOIN Genre g ON t.GenreId = g.GenreId
ORDER BY g.Name;


-- 2.4 Subquery
-- Business question: Which customers have spent more than the average
-- total spend across all customers?
SELECT
    c.CustomerId,
    c.FirstName + ' ' + c.LastName AS CustomerName,
    c.Country,
    SUM(i.Total) AS TotalSpent
FROM Customer c
INNER JOIN Invoice i ON c.CustomerId = i.CustomerId
GROUP BY c.CustomerId, c.FirstName, c.LastName, c.Country
HAVING SUM(i.Total) > (
    SELECT AVG(CustomerTotal)
    FROM (
        SELECT SUM(Total) AS CustomerTotal
        FROM Invoice
        GROUP BY CustomerId
    ) AS PerCustomerTotals
)
ORDER BY TotalSpent DESC;


-- 2.5 Window Functions - RANK() with PARTITION BY
-- Business question: Rank customers by total spend within their own country
SELECT
    c.Country,
    c.FirstName + ' ' + c.LastName AS CustomerName,
    SUM(i.Total) AS TotalSpent,
    RANK() OVER (PARTITION BY c.Country ORDER BY SUM(i.Total) DESC) AS RankInCountry
FROM Customer c
INNER JOIN Invoice i ON c.CustomerId = i.CustomerId
GROUP BY c.Country, c.CustomerId, c.FirstName, c.LastName
ORDER BY c.Country, RankInCountry;


-- 2.6 Window Functions - ROW_NUMBER() with PARTITION BY
-- Business question: What is the best-selling track in each genre?
SELECT *
FROM (
    SELECT
        g.Name AS Genre,
        t.Name AS TrackName,
        SUM(il.Quantity) AS UnitsSold,
        ROW_NUMBER() OVER (PARTITION BY g.Name ORDER BY SUM(il.Quantity) DESC) AS rn
    FROM InvoiceLine il
    INNER JOIN Track t ON il.TrackId = t.TrackId
    INNER JOIN Genre g ON t.GenreId = g.GenreId
    GROUP BY g.Name, t.Name
) AS RankedTracks
WHERE rn = 1
ORDER BY UnitsSold DESC;


/* =========================================================================
   SECTION 3: BUSINESS PROBLEM SOLVING
   ========================================================================= */

-- 3.1 Top-performing customers (Top 10 by revenue)
SELECT TOP 10
    c.CustomerId,
    c.FirstName + ' ' + c.LastName AS CustomerName,
    c.Country,
    SUM(i.Total) AS TotalSpent,
    COUNT(i.InvoiceId) AS NumberOfOrders
FROM Customer c
INNER JOIN Invoice i ON c.CustomerId = i.CustomerId
GROUP BY c.CustomerId, c.FirstName, c.LastName, c.Country
ORDER BY TotalSpent DESC;


-- 3.2 Top-performing products (Top 10 tracks by revenue)
SELECT TOP 10
    t.Name AS TrackName,
    ar.Name AS Artist,
    SUM(il.UnitPrice * il.Quantity) AS Revenue,
    SUM(il.Quantity) AS UnitsSold
FROM InvoiceLine il
INNER JOIN Track t   ON il.TrackId = t.TrackId
INNER JOIN Album al  ON t.AlbumId = al.AlbumId
INNER JOIN Artist ar ON al.ArtistId = ar.ArtistId
GROUP BY t.Name, ar.Name
ORDER BY Revenue DESC;


-- 3.3 Revenue trends over time (yearly and monthly)
SELECT
    YEAR(InvoiceDate)  AS SalesYear,
    MONTH(InvoiceDate) AS SalesMonth,
    SUM(Total)         AS MonthlyRevenue,
    COUNT(InvoiceId)   AS NumberOfInvoices
FROM Invoice
GROUP BY YEAR(InvoiceDate), MONTH(InvoiceDate)
ORDER BY SalesYear, SalesMonth;


-- 3.4 Customer purchasing behavior: order frequency & average order value
SELECT
    c.CustomerId,
    c.FirstName + ' ' + c.LastName AS CustomerName,
    COUNT(i.InvoiceId)              AS NumberOfOrders,
    AVG(i.Total)                    AS AvgOrderValue,
    MIN(i.InvoiceDate)               AS FirstPurchase,
    MAX(i.InvoiceDate)               AS LastPurchase
FROM Customer c
INNER JOIN Invoice i ON c.CustomerId = i.CustomerId
GROUP BY c.CustomerId, c.FirstName, c.LastName
ORDER BY NumberOfOrders DESC;


-- 3.5 Country-level performance (where is revenue coming from?)
SELECT
    BillingCountry,
    COUNT(InvoiceId) AS NumberOfOrders,
    SUM(Total)       AS TotalRevenue,
    AVG(Total)       AS AvgOrderValue
FROM Invoice
GROUP BY BillingCountry
ORDER BY TotalRevenue DESC;


/* =========================================================================
   SECTION 4: QUERY OPTIMIZATION (INDEXING)
   ========================================================================= */

-- These columns are used heavily in JOIN and GROUP BY clauses above.
-- Adding indexes on foreign keys speeds up join performance significantly
-- on larger datasets.

-- Speeds up Invoice <-> Customer joins
CREATE NONCLUSTERED INDEX IX_Invoice_CustomerId
    ON Invoice(CustomerId);

-- Speeds up InvoiceLine <-> Track joins
CREATE NONCLUSTERED INDEX IX_InvoiceLine_TrackId
    ON InvoiceLine(TrackId);

-- Speeds up Track <-> Genre joins
CREATE NONCLUSTERED INDEX IX_Track_GenreId
    ON Track(GenreId);

-- Speeds up filtering/grouping by date in revenue trend queries
CREATE NONCLUSTERED INDEX IX_Invoice_InvoiceDate
    ON Invoice(InvoiceDate);
