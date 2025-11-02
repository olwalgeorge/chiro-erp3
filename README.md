# ChiroERP - Enterprise Resource Planning System

A modern, cloud-native ERP system built with Quarkus and Kotlin, following Domain-Driven Design principles and hexagonal architecture.

## Architecture Overview

ChiroERP consolidates 30+ original microservices into **7 consolidated services** organized by business domain:

| Service                        | Port | Domains                                                                                                 | Database Schema                   |
| ------------------------------ | ---- | ------------------------------------------------------------------------------------------------------- | --------------------------------- |
| **Core Platform**              | 8081 | security, organization, audit, configuration, notification, integration                                 | `core_schema`                     |
| **Administration**             | 8082 | hr, logistics-transportation, analytics-intelligence, project-management                                | `administration_schema`           |
| **Customer Relationship**      | 8083 | crm, client, provider, subscription, promotion                                                          | `customerrelationship_schema`     |
| **Operations Service**         | 8084 | field-service, scheduling, records, repair-rma                                                          | `operationsservice_schema`        |
| **Commerce**                   | 8085 | ecommerce, portal, communication, pos                                                                   | `commerce_schema`                 |
| **Financial Management**       | 8086 | general-ledger, accounts-payable, accounts-receivable, asset-accounting, tax-engine, expense-management | `financialmanagement_schema`      |
| **Supply Chain Manufacturing** | 8087 | production, quality, inventory, product-costing, procurement                                            | `supplychainmanufacturing_schema` |

### Technology Stack

-   **Framework:** Quarkus (Supersonic Subatomic Java Framework)
-   **Language:** Kotlin
-   **Database:** PostgreSQL 15 (single database, schema-per-service)
-   **Messaging:** Apache Kafka (KRaft mode)
-   **Caching:** Redis 7
-   **Storage:** MinIO (S3-compatible)
-   **Security:** Keycloak (OAuth2/OIDC)
-   **Monitoring:** Prometheus + Grafana

Learn more about Quarkus: <https://quarkus.io/>

## Running the application in dev mode

You can run your application in dev mode that enables live coding using:

```shell script
./gradlew quarkusDev
```

> **_NOTE:_** Quarkus now ships with a Dev UI, which is available in dev mode only at <http://localhost:8080/q/dev/>.

## Packaging and running the application

The application can be packaged using:

```shell script
./gradlew build
```

It produces the `quarkus-run.jar` file in the `build/quarkus-app/` directory.
Be aware that it's not an _über-jar_ as the dependencies are copied into the `build/quarkus-app/lib/` directory.

The application is now runnable using `java -jar build/quarkus-app/quarkus-run.jar`.

If you want to build an _über-jar_, execute the following command:

```shell script
./gradlew build -Dquarkus.package.jar.type=uber-jar
```

The application, packaged as an _über-jar_, is now runnable using `java -jar build/*-runner.jar`.

## Quick Start with Docker Compose

### 1. Create Service Structure

```powershell
.\scripts\create-complete-structure.ps1
```

### 2. Start All Services

```powershell
.\scripts\start-microservices.ps1
```

This will:

-   Start infrastructure services (PostgreSQL, Redis, Kafka, MinIO, Keycloak)
-   Build and start all 7 microservices
-   Start monitoring stack (Prometheus, Grafana)

### 3. Verify Deployment

```powershell
.\scripts\test-health-checks.ps1
```

### Access Points

-   **Services:** http://localhost:8081-8087
-   **Keycloak:** http://localhost:8180/admin (admin/admin)
-   **MinIO Console:** http://localhost:9001 (minioadmin/minioadmin)
-   **Grafana:** http://localhost:3000 (admin/admin)
-   **Prometheus:** http://localhost:9090

## Development

### Run Single Service in Dev Mode

```shell script
cd services/core-platform
../../gradlew quarkusDev
```

### Build All Services

```shell script
./gradlew clean build
```

### Run Tests

```shell script
./gradlew test
```

## Documentation

-   📘 [Consolidated Deployment Guide](docs/CONSOLIDATED-DEPLOYMENT-GUIDE.md)
-   🏗️ [Architecture Summary](docs/architecture/ARCHITECTURE-SUMMARY.md)
-   🎯 [Bounded Contexts](docs/architecture/BOUNDED-CONTEXTS.md)
-   📊 [Domain Models Index](docs/SERVICE-DOMAIN-MODELS-INDEX.md)
-   🔐 [Security Framework](docs/architecture/DOMAIN-MODELS-COMPLETE.md)
-   🧪 [Testing Guide](docs/TESTING-GUIDE.md)

## System Requirements

### Minimum

-   **CPUs:** 12.75 cores
-   **Memory:** 12 GB RAM
-   **Disk:** 50 GB available space
-   **Docker:** 20.10+
-   **Docker Compose:** 2.0+

### Recommended

-   **CPUs:** 16+ cores
-   **Memory:** 16+ GB RAM
-   **Disk:** 100 GB SSD

## Project Structure

```
chiro-erp/
├── services/              # 7 consolidated microservices
│   ├── core-platform/
│   ├── administration/
│   ├── customer-relationship/
│   ├── operations-service/
│   ├── commerce/
│   ├── financial-management/
│   └── supply-chain-manufacturing/
├── docs/                  # Architecture and domain documentation
├── scripts/               # Deployment and testing scripts
├── monitoring/            # Prometheus configuration
├── docker-compose.yml     # Orchestration configuration
└── settings.gradle        # Multi-module Gradle configuration
```

## Contributing

1. Follow Domain-Driven Design principles
2. Maintain hexagonal architecture (ports & adapters)
3. Write tests for all business logic
4. Update documentation for architectural changes
5. Use ktlint for Kotlin code formatting

```shell script
./ktlint.ps1  # Windows
./ktlint.sh   # Linux/Mac
```

## License

Copyright © 2024 ChiroERP. All rights reserved.
