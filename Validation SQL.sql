USE RetailDWH;
GO

--Suggested validation questions
--1-How many source orders have status Completed?
SELECT COUNT(*)  AS CompletedOrders
from [stg].[orders]
where OrderStatus = 'Completed'
--Result = 161

--2-What is the number of valid order lines after product lookup?
SELECT COUNT(*) AS ValidOrderLines
FROM RetailDWH.stg.OrderLines AS OL
INNER JOIN RetailDWH.stg.Orders AS O
    ON O.OrderID = OL.OrderID
INNER JOIN RetailDWH.dim.DimProduct AS P
    ON P.ProductID = OL.ProductID
   AND O.OrderDate >= P.StartDate
   AND O.OrderDate < P.EndDate
WHERE O.OrderStatus = 'Completed';
--Result = 431

--3-Does COUNT(DISTINCT SourceOrderLineID) equal the fact row count?
select count(distinct SourceOrderLineID) as DistinctOrderLines , count(*) as FactROWS 
FROM RetailDWH.fact.FactSales
--result DistinctOrderLines = 430  FactROWS = 430

--4-Can you calculate monthly revenue by brand and store?
SELECT
    D.FullDate,
    D.MonthNumber,
    P.Brand,
    S.StoreName,
    SUM(F.NetSales) AS MonthlyRevenue
FROM RetailDWH.fact.FactSales AS F
INNER JOIN RetailDWH.dim.DimDate AS D
    ON F.DateKey = D.DateKey
INNER JOIN RetailDWH.dim.DimProduct AS P
    ON F.ProductKey = P.ProductKey
INNER JOIN RetailDWH.dim.DimStores AS S
    ON F.StoreKey = S.StoreKey
GROUP BY
    D.FullDate,
    D.MonthNumber,
    P.Brand,
    S.StoreName
ORDER BY
    D.FullDate,
    D.MonthNumber,
    P.Brand,
    S.StoreName;


--5-The provided sample includes OrderLineID 50470 / ProductID 9999, which does not exist in Batch 1. Describe how it will be handled.
Select
    OL.OrderLineID,
    OL.OrderID,
    OL.ProductID,
    O.OrderStatus
FROM RetailDWH.stg.OrderLines AS OL
INNER JOIN RetailDWH.stg.Orders AS O
    ON O.OrderID = OL.OrderID
LEFT JOIN RetailDWH.dim.DimProduct AS P
    ON P.ProductID = OL.ProductID
WHERE OL.OrderLineID = 50470
  AND P.ProductKey IS NULL;
