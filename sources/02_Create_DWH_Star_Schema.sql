/* ================================================
   RETAIL DATA WAREHOUSE
   SCD TYPE 2 - DIMPRODUCT
   SQL SERVER + SSIS
   ================================================ */

USE master;
GO

IF DB_ID(N'RetailDWH') IS NULL
    CREATE DATABASE RetailDWH;
GO

USE RetailDWH;
GO

/* ================================================
   1. CREATE SCHEMAS
   ================================================ */

IF SCHEMA_ID('stg') IS NULL
    EXEC('CREATE SCHEMA stg');

IF SCHEMA_ID('dim') IS NULL
    EXEC('CREATE SCHEMA dim');

IF SCHEMA_ID('fact') IS NULL
    EXEC('CREATE SCHEMA fact');

IF SCHEMA_ID('etl') IS NULL
    EXEC('CREATE SCHEMA etl');
GO


/* ================================================
   2. DROP EXISTING TABLES
   WARNING: DELETES EXISTING DWH DATA
   ================================================ */

DROP TABLE IF EXISTS fact.FactSales;

DROP TABLE IF EXISTS dim.DimDate;
DROP TABLE IF EXISTS dim.DimProduct;
DROP TABLE IF EXISTS dim.DimCustomer;
DROP TABLE IF EXISTS dim.DimStore;

DROP TABLE IF EXISTS stg.OrderLines;
DROP TABLE IF EXISTS stg.Orders;
DROP TABLE IF EXISTS stg.Customers;
DROP TABLE IF EXISTS stg.Stores;
DROP TABLE IF EXISTS stg.ProductCatalog;

DROP TABLE IF EXISTS etl.Watermarks;
GO


/* ================================================
   3. STAGING TABLES
   ================================================ */

CREATE TABLE stg.Customers
(
    CustomerID INT PRIMARY KEY,
    CustomerName NVARCHAR(100),
    City NVARCHAR(50),
    Region NVARCHAR(50),
    Email NVARCHAR(120),
    LastModifiedAt DATETIME2(3)
);

CREATE TABLE stg.Stores
(
    StoreID INT PRIMARY KEY,
    StoreName NVARCHAR(100),
    City NVARCHAR(50),
    Region NVARCHAR(50),
    LastModifiedAt DATETIME2(3)
);

CREATE TABLE stg.Orders
(
    OrderID INT PRIMARY KEY,
    CustomerID INT,
    StoreID INT,
    OrderDate DATETIME2(0),
    OrderStatus VARCHAR(20),
    LastModifiedAt DATETIME2(3)
);

CREATE TABLE stg.OrderLines
(
    OrderLineID INT PRIMARY KEY,
    OrderID INT,
    ProductID INT,
    Quantity INT,
    UnitPrice DECIMAL(12,2),
    DiscountAmount DECIMAL(12,2),
    LastModifiedAt DATETIME2(3)
);

/* Excel Source */

CREATE TABLE stg.ProductCatalog
(
    ProductID INT NOT NULL,
    SKU NVARCHAR(30) NOT NULL,
    ProductName NVARCHAR(100) NOT NULL,
    Category NVARCHAR(60) NOT NULL,
    Brand NVARCHAR(60) NOT NULL,
    UnitCost DECIMAL(12,2) NOT NULL,
    IsActive CHAR(1) NOT NULL,
    LastModifiedAt DATETIME2(3) NOT NULL
);
GO


/* ================================================
   4. DIMENSION TABLES
   ================================================ */

/* Date Dimension */

CREATE TABLE dim.DimDate
(
    DateKey INT NOT NULL PRIMARY KEY,
    FullDate DATE NOT NULL UNIQUE,
    DayNumber INT NOT NULL,
    MonthNumber INT NOT NULL,
    MonthName NVARCHAR(20) NOT NULL,
    QuarterNumber INT NOT NULL,
    YearNumber INT NOT NULL
);


/* Customer Dimension - SCD Type 1 */

CREATE TABLE dim.DimCustomer
(
    CustomerKey INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT NOT NULL UNIQUE,
    CustomerName NVARCHAR(100) NOT NULL,
    City NVARCHAR(50) NOT NULL,
    Region NVARCHAR(50) NOT NULL,
    Email NVARCHAR(120) NULL
);


/* Store Dimension - SCD Type 1 */

CREATE TABLE dim.DimStore
(
    StoreKey INT IDENTITY(1,1) PRIMARY KEY,
    StoreID INT NOT NULL UNIQUE,
    StoreName NVARCHAR(100) NOT NULL,
    City NVARCHAR(50) NOT NULL,
    Region NVARCHAR(50) NOT NULL
);


/* ================================================
   PRODUCT DIMENSION - SCD TYPE 2
   ================================================ */

CREATE TABLE dim.DimProduct
(
    ProductKey INT IDENTITY(1,1) PRIMARY KEY,

    ProductID INT NOT NULL,
    SKU NVARCHAR(30) NOT NULL,
    ProductName NVARCHAR(100) NOT NULL,
    Category NVARCHAR(60) NOT NULL,
    Brand NVARCHAR(60) NOT NULL,
    UnitCost DECIMAL(12,2) NOT NULL,

    -- SCD Type 2 History Columns
    StartDate DATETIME2(3) NOT NULL,
    EndDate DATETIME2(3) NOT NULL,

    CONSTRAINT CK_DimProduct_DateRange
        CHECK (StartDate < EndDate)
);
GO



/* ================================================
   5. FACT TABLE
   ================================================ */

CREATE TABLE fact.FactSales
(
    SalesKey BIGINT IDENTITY(1,1)
        NOT NULL PRIMARY KEY,

    SourceOrderLineID INT NOT NULL UNIQUE,

    -- Degenerate Dimension
    OrderID INT NOT NULL,

    -- Dimension Foreign Keys
    DateKey INT NOT NULL,
    CustomerKey INT NOT NULL,
    StoreKey INT NOT NULL,
    ProductKey INT NOT NULL,

    -- Measures
    Quantity INT NOT NULL,
    UnitPrice DECIMAL(12,2) NOT NULL,

    GrossSales DECIMAL(18,2) NOT NULL,
    DiscountAmount DECIMAL(18,2) NOT NULL,
    NetSales DECIMAL(18,2) NOT NULL,

    LoadedAt DATETIME2(3)
        NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT FK_Fact_Date
        FOREIGN KEY (DateKey)
        REFERENCES dim.DimDate(DateKey),

    CONSTRAINT FK_Fact_Customer
        FOREIGN KEY (CustomerKey)
        REFERENCES dim.DimCustomer(CustomerKey),

    CONSTRAINT FK_Fact_Store
        FOREIGN KEY (StoreKey)
        REFERENCES dim.DimStore(StoreKey),

    CONSTRAINT FK_Fact_Product
        FOREIGN KEY (ProductKey)
        REFERENCES dim.DimProduct(ProductKey)
);
GO

CREATE INDEX IX_FactSales_Date
ON fact.FactSales(DateKey)
INCLUDE(NetSales);
GO


/* ================================================
   6. ETL CONTROL TABLES
   ================================================ */

/* Incremental Loading */

CREATE TABLE etl.Watermarks
(
    TableName SYSNAME NOT NULL PRIMARY KEY,
    LastSuccessfulWatermark DATETIME2(3) NOT NULL
);







/* ================================================
   7. VERIFY EMPTY DATA WAREHOUSE
   ================================================ */

SELECT
    'DimDate' AS TableName,
    COUNT(*) AS TotalRows
FROM dim.DimDate

UNION ALL

SELECT 'DimCustomer', COUNT(*)
FROM dim.DimCustomer

UNION ALL

SELECT 'DimProduct', COUNT(*)
FROM dim.DimProduct

UNION ALL

SELECT 'DimStore', COUNT(*)
FROM dim.DimStore

UNION ALL

SELECT 'FactSales', COUNT(*)
FROM fact.FactSales;
GO