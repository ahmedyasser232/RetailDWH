/*
============================================================
Retail Data Warehouse – Implementation Summary
============================================================
1. Source Database Creation:
   Created the RetailOLTP database and its source tables
   using the provided SQL creation script.

2. Source Data Insertion:
   Inserted the sample retail transaction data into
   RetailOLTP using the provided insertion script.

3. Data Warehouse Creation:
   Created the RetailDWH database using the Star Schema
   creation script, including the staging, dimension,
   fact, and ETL schemas and their tables.

4. Product Catalog Source:
   Used ProductCatalog_Batch1.xlsx as the product source
   file in SSIS to load product data into staging.

5. SSIS Staging Load Strategy:
   Configured the SSIS staging packages to overwrite the
   existing staging data on each execution (Full Refresh),
   ensuring that staging tables contain the latest data
   from their respective sources.
============================================================
*/
/*
Expected first-load staging counts
Customers  : 30
Stores     : 6
Orders     : 180
OrderLines : 470
Products   : 24
*/
-- Verify Customers row count
SELECT COUNT(*) AS Customers_Count
FROM RetailDWH.stg.Customers;

-- Verify Stores row count
SELECT COUNT(*) AS Stores_Count
FROM RetailDWH.stg.Stores;

-- Verify Orders row count
SELECT COUNT(*) AS Orders_Count
FROM RetailDWH.stg.Orders;

-- Verify OrderLines row count
SELECT COUNT(*) AS OrderLines_Count
FROM RetailDWH.stg.OrderLines;

-- Verify Products row count
SELECT COUNT(*) AS Products_Count
FROM RetailDWH.stg.ProductCatalog;

/*
============================================================
Dimension Tables – Creation and Loading Summary
============================================================

The dimension tables were loaded using SSIS, with SCD Type 1
for Customers and Stores, SCD Type 2 for Products, and a
Lookup-based incremental load for DimDate to prevent duplicates.

The dimensions were validated to ensure data consistency
and prepare the warehouse for FactSales loading.
============================================================
*/
SELECT 'DimCustomers' AS TableName, COUNT(*) AS TotalRows
FROM RetailDWH.dim.DimCustomer

UNION ALL

SELECT 'DimStores', COUNT(*)
FROM RetailDWH.dim.DimStore

UNION ALL

SELECT 'DimProduct', COUNT(*)
FROM RetailDWH.dim.DimProduct

UNION ALL

SELECT 'DimDate', COUNT(*)
FROM RetailDWH.dim.DimDate;
/*Existing Fact Lookup: Match OrderLineID with fact.FactSales.SourceOrderLineID to prevent duplicate inserts; redirect only no-match rows to the destination.
OLE DB Destination: Load validated records into fact.FactSales, mapping source columns to the corresponding fact-table columns.
*/
--Verification SQL - counts and business rules
USE RetailDWH;
SELECT COUNT(*) AS FactRows FROM fact.FactSales;
SELECT COUNT(*) AS MissingLineIDs
FROM fact.FactSales WHERE SourceOrderLineID IS NULL;
SELECT SourceOrderLineID, COUNT(*) AS Cnt
FROM fact.FactSales
GROUP BY SourceOrderLineID HAVING COUNT(*) > 1;
SELECT COUNT(*) AS InvalidAmounts
FROM fact.FactSales
WHERE ABS(NetSales - (GrossSales - DiscountAmount)) > 0.01;
--FactRow = 430  & MissingLineIDs = 0
--Compare to completed source order lines
SELECT COUNT(*) AS CompletedSourceLines
FROM RetailDWH.stg.OrderLines AS l
JOIN RetailDWH.stg.Orders AS o ON o.OrderID = l.OrderID
WHERE o.OrderStatus = 'Completed'
--CompletedSourceLines	= 431
