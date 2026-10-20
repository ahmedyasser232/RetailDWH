
--Datawarhouse and stg area creation
DROP DATABASE IF EXISTS RetailDWH; 
create database RetailDWH;
GO
use [RetailDWH];
GO

--Create Schemas
Create schema stg ;
Create schema dim;
create schema fact;
GO

--Create Five RetailDWH.stg.Tables



---- Full refresh staging tables from STG.RetailOLTP
--Customers
Truncate table RetailDWH.stg.Customers
insert into RetailDWH.stg.Customers
select * from RetailOLTP.dbo.Customers;
--OrderLines
Truncate table RetailDWH.stg.OrderLines
insert into RetailDWH.stg.OrderLines
select * from RetailOLTP.dbo.OrderLines;
--Orders
Truncate table RetailDWH.stg.Orders
insert into RetailDWH.stg.Orders
select * from RetailOLTP.dbo.Orders;
--Stores
Truncate table RetailDWH.stg.Stores
insert into RetailDWH.stg.Stores
select * from RetailOLTP.dbo.Stores;
--ProductCatalog
-- 5. ProductCatalog (Excel/CSV source)
TRUNCATE TABLE RetailDWH.stg.ProductCatalog;
INSERT INTO RetailDWH.stg.ProductCatalog
SELECT * FROM [dbo].[ProductCatalog_Batch1]
-- added the `StagingRowID` column to uniquely identify each row and distinguish duplicate records during data validation.
alter table [stg].[Customers]
ADD StagingRowID BIGINT IDENTITY(1,1);
alter table [stg].[ProductCatalog]
ADD StagingRowID BIGINT IDENTITY(1,1);
alter table [stg].[OrderLines]
ADD StagingRowID BIGINT IDENTITY(1,1);
alter table [stg].[orders]
ADD StagingRowID BIGINT IDENTITY(1,1);
alter table [stg].[stores]
ADD StagingRowID BIGINT IDENTITY(1,1);

--Create all Four DimTables below and dim.dimdate from dim.dimdate script
--DIM.Dimcustomer SCD1
create table dim.Dimcustomers (
Customerkey int IDENTITY(1,1) PRIMARY KEY,
CustomerID INT UNIQUE,
CustomerName NVARCHAR(100),
City NVARCHAR(50),
Region NVARCHAR(50),
Email NVARCHAR(120))

--dim.DimStores SCD1
CREATE TABLE dim.DimStores(
StoreKey INT IDENTITY(1,1) primary key,
storeid int unique ,
StoreName NVARCHAR(100),
City NVARCHAR(50),
Region NVARCHAR(50))
--dim.DimProduct Define (startdate , enddate  ,	define is current to know current version of record)   To Use SCD2 
create table dim.DimProduct (
ProductKey INT IDENTITY(1,1) primary key ,
ProductID INT not null,
SKU NVARCHAR(30) ,
ProductName NVARCHAR(100),
Category NVARCHAR(60),
Brand NVARCHAR(60),
UnitCost DECIMAL(12,2),
StartDate DATETIME2 NOT NULL,
EndDate DATETIME2 NOT NULL
DEFAULT ('9999-12-31 23:59:59.9999999'),
IsCurrent BIT NOT NULL DEFAULT 1
)

-- insert values to dim.dimtables
--dim.dimcustomers from [RetailOLTP].[dbo].[Customers]
insert into dim.Dimcustomers 
(CustomerID,CustomerName,city,Region,Email)
select CustomerID,CustomerName,city,Region,Email from [RetailOLTP].[dbo].[Customers]
--dim.dimstores from [RetailOLTP].[dbo].[Stores]
insert into dim.DimStores 
(storeid,StoreName,City,Region)
select storeid,StoreName,City,Region from [RetailOLTP].[dbo].[Stores]
--dim.dimproduct from [RetailDWH][dbo].[ProductCatalog_Batch1]
insert  into dim.DimProduct(ProductID,SKU,ProductName,Category,Brand,UnitCost,StartDate)
select ProductID,SKU,ProductName,Category,Brand,UnitCost, CAST('2026-01-01' AS DATETIME2) FROM [RetailDWH].[dbo].[ProductCatalog_Batch1]

--Create Fact.FactTable
Create  table fact.FactSales
(
Saleskey BIGINT IDENTITY(1,1) Primary key,
SourceOrderLineID INT UNIQUE,
Orderid INT,
Datekey INT Foreign key references dim.dimdate(datekey),
CustomerKey INT Foreign KEY REFERENCES dim.dimcustomers(CustomerKey),
Storekey INT Foreign KEY REFERENCES dim.dimstores(Storekey),
ProductKey INT Foreign KEY REFERENCES dim.dimproduct(ProductKey),
Quantity int not null ,
UnitPrice DECIMAL(12,2) not null,
GrossSales as (CAST (QUANTITY * unitprice as decimal(18,2))),
Discountamount Decimal(18,2) NOT NULL ,
NetSales as (Cast((Quantity * unitprice) - Discountamount as decimal(18,2))),
LoadedAt DATETIME2(3) DEFAULT SYSDATETIME()
)
--Insert Value in Fact.FactTable
Insert into RetailDWH.fact.FactSales (SourceOrderLineID,Orderid,Datekey,CustomerKey,Storekey,ProductKey,Quantity,UnitPrice,Discountamount)
select ol.orderlineid,o.orderid,d.DateKey,c.Customerkey,s.storekey,p.ProductKey,ol.Quantity,ol.UnitPrice,ol.DiscountAmount from RetailDWH.stg.OrderLines OL
inner join  RetailDWH.stg.Orders o  on o.OrderID = ol.OrderID
inner join RetailDWH.dim.DimDate d on cast(o.OrderDate as date) = d.fulldate
inner join RetailDWH.dim.Dimcustomers c on c.CustomerID =o.CustomerID
inner join RetailDWH.dim.Dimstores s on s.storeid = o.StoreID
inner join RetailDWH.dim.DimProduct p on p.ProductID = ol.ProductID
and o.orderdate >= p.StartDate and o.OrderDate < p.EndDate
where o.OrderStatus = 'Completed' 





















  

