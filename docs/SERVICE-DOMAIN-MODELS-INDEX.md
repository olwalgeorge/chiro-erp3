# Service-Level Domain Models Documentation - Index

This document serves as an index to all service-level domain model documentation files in the Chiro ERP system.

## Overview

Each microservice in the Chiro ERP system has its own dedicated `DOMAIN-MODELS.md` file located in `services/{service-name}/docs/`. These files provide service-specific overviews, core aggregate samples, integration patterns, and API endpoints.

For **complete and detailed domain models**, see the comprehensive documentation in `docs/architecture/`.

---

## Service Documentation Files

### 1. Financial Management Service

**Path:** `services/financial-management/docs/DOMAIN-MODELS.md`

**Schema:** `finance_schema`

**Core Domains:**

-   General Ledger (GL)
-   Accounts Payable (AP)
-   Accounts Receivable (AR)
-   Fixed Assets
-   Cash Management
-   Tax Engine
-   Point of Sale (POS)

**Key Aggregates:** `GeneralLedger`, `JournalEntry`, `Invoice`, `Payment`, `FixedAsset`, `TaxCalculation`, `POSTransaction`

**Detailed Reference:** `docs/architecture/DOMAIN-MODELS-FINANCIAL.md`

---

### 2. Supply Chain & Manufacturing Service

**Path:** `services/supply-chain-manufacturing/docs/DOMAIN-MODELS.md`

**Schema:** `supply_chain_schema`

**Core Domains:**

-   Material Master Data
-   Inventory Management
-   Procurement
-   Production Planning
-   Bill of Materials (BOM)
-   Quality Management

**Key Aggregates:** `Material`, `InventoryItem`, `PurchaseOrder`, `ProductionOrder`, `BillOfMaterials`, `QualityInspection`

**Detailed Reference:** `docs/architecture/DOMAIN-MODELS-SUPPLY-CHAIN.md`

---

### 3. Customer Relationship Management Service

**Path:** `services/customer-relationship/docs/DOMAIN-MODELS.md`

**Schema:** `crm_schema`

**Core Domains:**

-   Customer Management
-   Sales Order Management
-   Quotation Management
-   Service Ticket Management
-   Contract Management
-   Marketing Campaigns

**Key Aggregates:** `Customer`, `SalesOrder`, `Quotation`, `ServiceTicket`, `Contract`, `MarketingCampaign`

**Detailed Reference:** `docs/architecture/` (CRM domain models)

---

### 4. Logistics & Transportation Service

**Path:** `services/logistics-transportation/docs/DOMAIN-MODELS.md`

**Schema:** `logistics_schema`

**Core Domains:**

-   Warehouse Management (WM)
-   Shipping & Receiving
-   Transportation Management
-   Fleet Management
-   Route Planning & Optimization
-   Carrier Management

**Key Aggregates:** `Warehouse`, `StorageLocation`, `Shipment`, `TransportOrder`, `Vehicle`, `Route`

**Detailed Reference:** `docs/architecture/DOMAIN-MODELS-LOGISTICS.md`

---

### 5. Administration Service (HR)

**Path:** `services/administration/docs/DOMAIN-MODELS.md`

**Schema:** `hr_schema`

**Core Domains:**

-   Employee Management
-   Organizational Management
-   Time & Attendance
-   Payroll Processing
-   Leave Management
-   Performance Management
-   Compensation & Benefits

**Key Aggregates:** `Employee`, `Department`, `Position`, `TimeEntry`, `PayrollPeriod`, `Payslip`, `LeaveRequest`

**Detailed Reference:** `docs/architecture/DOMAIN-MODELS-HR.md`

---

### 6. Operations Service

**Path:** `services/operations-service/docs/DOMAIN-MODELS.md`

**Schema:** `operations_schema`

**Core Domains:**

-   Work Order Management
-   Maintenance Planning & Scheduling
-   Equipment & Asset Management
-   Field Service Management
-   Preventive Maintenance
-   Service Request Management
-   Project Management

**Key Aggregates:** `WorkOrder`, `WorkOrderTask`, `Equipment`, `ServiceRequest`, `Project`

**Detailed Reference:** `docs/architecture/` (PM/PS domain models)

---

### 7. Commerce Service (E-Commerce)

**Path:** `services/commerce/docs/DOMAIN-MODELS.md`

**Schema:** `commerce_schema`

**Core Domains:**

-   Product Catalog Management
-   Online Store Management
-   Shopping Cart & Checkout
-   Order Management (Online)
-   Customer Portal
-   Digital Marketing Integration
-   Promotion & Discount Engine

**Key Aggregates:** `Product`, `Category`, `ShoppingCart`, `CartItem`, `OnlineOrder`, `Promotion`

**Detailed Reference:** SAP Commerce Cloud patterns

---

### 8. Analytics & Intelligence Service

**Path:** `services/analytics-intelligence/docs/DOMAIN-MODELS.md`

**Schema:** `analytics_schema`

**Core Domains:**

-   Business Intelligence & Reporting
-   Data Warehouse Management
-   Real-time Analytics
-   Predictive Analytics
-   KPI & Metrics Management
-   Dashboard Management
-   Data Mining & Insights

**Key Aggregates:** `Dashboard`, `DashboardWidget`, `Report`, `ReportExecution`, `KPI`, `DataSource`

**Detailed Reference:** SAP BW/4HANA and SAP Analytics Cloud patterns

---

## Documentation Hierarchy

### Level 1: Service-Level Documentation (This Directory)

**Purpose:** Quick reference for service developers
**Location:** `services/{service-name}/docs/DOMAIN-MODELS.md`
**Contents:**

-   Service boundaries and responsibilities
-   Core aggregate samples (simplified)
-   Service dependencies (inbound/outbound)
-   Integration patterns (events)
-   API endpoints overview
-   Database schema references

### Level 2: Architecture-Level Documentation

**Purpose:** Comprehensive domain modeling and business logic
**Location:** `docs/architecture/DOMAIN-MODELS-{DOMAIN}.md`
**Contents:**

-   Complete domain models with all fields
-   Business logic and invariants
-   Domain events
-   Value objects and entities
-   Repository patterns
-   Detailed business rules

### Level 3: Implementation Code

**Purpose:** Actual runnable code
**Location:** `services/{service-name}/src/main/kotlin/...`
**Contents:**

-   JPA entities
-   Domain services
-   Application services
-   Repositories
-   REST controllers
-   Event handlers

---

## Cross-Service Integration

### Event-Driven Communication

All services communicate asynchronously via domain events published to Apache Kafka.

**Example Flow:**

1. **Financial Management** publishes `InvoiceCreatedEvent`
2. **Customer Relationship** consumes event → Updates customer account balance
3. **Analytics** consumes event → Updates financial KPIs

### Synchronous REST APIs

Services expose REST APIs for real-time data queries.

**Example:**

-   **Commerce Service** calls **Supply Chain Service** REST API to check product availability

---

## SAP ERP Module Mapping

This ERP system implements the following SAP modules:

| Chiro ERP Service     | SAP Module                     | Description                       |
| --------------------- | ------------------------------ | --------------------------------- |
| Financial Management  | FI (Financial Accounting)      | GL, AP, AR, Asset Accounting, Tax |
| Financial Management  | CO (Controlling)               | Cost Centers, Profit Centers      |
| Supply Chain          | MM (Materials Management)      | Procurement, Inventory            |
| Supply Chain          | PP (Production Planning)       | Manufacturing, BOM, Work Centers  |
| Customer Relationship | SD (Sales & Distribution)      | Sales Orders, Quotations          |
| Logistics             | LE (Logistics Execution)       | Warehouse, Shipping               |
| Logistics             | TM (Transportation Management) | Fleet, Routes, Carriers           |
| Administration        | HCM (Human Capital Management) | HR, Payroll, Time Management      |
| Operations            | PM (Plant Maintenance)         | Work Orders, Equipment            |
| Operations            | PS (Project System)            | Project Management                |
| Commerce              | SAP Commerce Cloud             | E-Commerce, Online Store          |
| Analytics             | BW/4HANA                       | Data Warehouse, BI                |

---

## Database Schema Organization

Each service uses its own dedicated PostgreSQL schema:

```
chiro_erp_db (Database)
├── finance_schema
├── supply_chain_schema
├── crm_schema
├── logistics_schema
├── hr_schema
├── operations_schema
├── commerce_schema
└── analytics_schema
```

**Benefits:**

-   Clear service boundaries
-   Independent schema evolution
-   Simplified access control
-   Better performance isolation

---

## Next Steps for Developers

1. **Starting New Feature:**

    - Read service-level docs (this directory) for quick overview
    - Review architecture docs for complete domain models
    - Check existing implementation code

2. **Integration Between Services:**

    - Identify integration patterns in service-level docs
    - Design domain events for async communication
    - Use REST APIs for synchronous queries

3. **Adding New Domain:**
    - Update architecture-level documentation first
    - Update service-level documentation
    - Implement code following DDD patterns

---

## Maintenance Guidelines

-   **Keep service-level docs synchronized** with architecture docs
-   **Update API endpoint lists** when adding new REST endpoints
-   **Document new integration patterns** when adding event publishing/consumption
-   **Review quarterly** to ensure documentation accuracy

---

**Last Updated:** 2024
**Documentation Owner:** Architecture Team
