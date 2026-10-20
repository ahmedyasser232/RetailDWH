# RetailDWH — Retail Data Warehouse

## Project Overview

A Retail Data Warehouse project built using Microsoft SQL Server to integrate retail data from multiple sources, implement dimensional modeling, manage Slowly Changing Dimensions (SCD), and prepare sales data for business intelligence and analytics.

## 1. Fact Table Grain

The grain of `fact.FactSales` is one row per order line. Each row represents a single product line within a customer order, supporting sales analysis by date, customer, store, and product.

Only orders with `OrderStatus = 'Completed'` are included.

- **GrossSales:** `Quantity × UnitPrice`
- **NetSales:** `GrossSales − DiscountAmount`

## 2. Keys and Relationships

- **Surrogate Keys:** `SalesKey`, `DateKey`, `CustomerKey`, `StoreKey`, and `ProductKey` identify records in the data warehouse.
- **Business Keys:** `ProductID`, `CustomerID`, and `StoreID` originate from the source system.
- **Product History:** `ProductID` identifies the business product, while `ProductKey` identifies a specific version of that product in the warehouse.
- **Degenerate Dimension:** `OrderID` is stored directly in `FactSales`.
- **Relationships:** Each dimension has a one-to-many relationship with `FactSales`.

## 3. Slowly Changing Dimensions (SCD)

- **DimCustomer — Type 1:** Updates existing attributes without preserving historical values.
- **DimStore — Type 1:** Retains the latest attribute values.
- **DimProduct — Type 2:** Preserves historical product versions by closing the previous record's validity period and inserting a new version with a new `ProductKey`.

The business key `ProductID` remains consistent across product versions. During fact loading, the appropriate product version is resolved using the order date and the product's `StartDate` and `EndDate`.

Since the source does not provide a historical product start date, the initial effective-date policy must be documented explicitly.

## 4. ETL Process and SSIS Control Flow

The proposed ETL workflow integrates data from the Retail OLTP database and an external product catalog.

### Control Flow

1. **Source Extraction:** Read data from the OLTP database and product catalog file.
2. **Staging:** Load source data into five staging tables under the `stg` schema.
3. **Dimension Loading:** Populate `DimDate`, `DimCustomer`, `DimStore`, and `DimProduct`.
4. **Data Validation:** Validate completed orders, product matches, effective dates, and missing product records.
5. **Fact Loading:** Load eligible order lines, resolve surrogate keys, and calculate sales measures.
6. **Final Validation:** Check row counts, duplicate source order-line IDs, foreign-key integrity, and rejected records.

### Simplified ETL Flow

`Source Extraction → Staging → Dimension Loading → Data Validation → Fact Loading → Final Validation`

Precedence constraints ensure that each stage completes before its dependent stage begins. Error handling should identify and report rejected records rather than silently discarding them.

### Data Quality Example

The sample record `OrderLineID = 50470`, with `ProductID = 9999`, must be rejected and logged or assigned to a documented Unknown Product member according to the selected policy. The source data should not be modified to create a fake product record.

## 5. Implementation Notes

This document describes the warehouse design and proposed SSIS workflow. The existence of this documentation does not imply that an SSIS package has been implemented or tested.

## Technologies

- Microsoft SQL Server
- SQL (DDL, DML, and dimensional modeling)
- ETL design
- SQL Server Integration Services (SSIS)
- Slowly Changing Dimensions (SCD Type 1 and Type 2)
- Data Quality and Validation