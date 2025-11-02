# Consolidated Services Deployment Configuration

## Overview

This document describes the deployment configuration for the consolidated ChiroERP microservices architecture, which reduces 30+ original services into 7 consolidated services using a domain-driven design approach.

## Service Architecture

### 1. Core Platform Service (Port 8081)

**Domains:** security, organization, audit, configuration, notification, integration
**Database Schema:** `core_schema`
**User:** `core_user`
**Original Services:** service-security-framework, service-organization-master, service-audit-logging, service-configuration-management, service-notification-engine, service-integration-platform

### 2. Administration Service (Port 8082)

**Domains:** hr, logistics-transportation, analytics-intelligence, project-management
**Database Schema:** `administration_schema`
**User:** `administration_user`
**Original Services:** service-hr-management, service-logistics-transportation, service-analytics-intelligence, service-project-management

### 3. Customer Relationship Service (Port 8083)

**Domains:** crm, client, provider, subscription, promotion
**Database Schema:** `customerrelationship_schema`
**User:** `customerrelationship_user`
**Original Services:** service-crm, service-client-management, service-provider-management, service-subscriptions, service-retail-promotions

### 4. Operations Service (Port 8084)

**Domains:** field-service, scheduling, records, repair-rma
**Database Schema:** `operationsservice_schema`
**User:** `operationsservice_user`
**Original Services:** service-field-service-management, service-resource-scheduling, service-records-management, service-repair-rma

### 5. Commerce Service (Port 8085)

**Domains:** ecommerce, portal, communication, pos
**Database Schema:** `commerce_schema`
**User:** `commerce_user`
**Original Services:** service-ecomm-storefront, service-customer-portal, service-communication-portal, service-point-of-sale

### 6. Financial Management Service (Port 8086)

**Domains:** general-ledger, accounts-payable, accounts-receivable, asset-accounting, tax-engine, expense-management
**Database Schema:** `financialmanagement_schema`
**User:** `financialmanagement_user`
**Original Services:** service-accounting-core, service-ap-automation, service-billing-invoicing, service-asset-management, service-tax-compliance, service-expense-reports

### 7. Supply Chain Manufacturing Service (Port 8087)

**Domains:** production, quality, inventory, product-costing, procurement
**Database Schema:** `supplychainmanufacturing_schema`
**User:** `supplychainmanufacturing_user`
**Original Services:** service-mrp-production, service-quality-management, service-inventory-management, service-cost-accounting, service-procurement-management

## Database Configuration

### Single Database Strategy

All services use the same PostgreSQL database (`chiro_erp`) with schema-level separation:

-   **Database Name:** `chiro_erp`
-   **Strategy:** Schema-per-service
-   **Benefits:** Simplified deployment, easier data sharing, reduced operational overhead

### Schema Structure

```
chiro_erp (database)
├── core_schema (Core Platform)
├── administration_schema (Administration)
├── customerrelationship_schema (Customer Relationship)
├── operationsservice_schema (Operations Service)
├── commerce_schema (Commerce)
├── financialmanagement_schema (Financial Management)
└── supplychainmanufacturing_schema (Supply Chain Manufacturing)
```

## Infrastructure Services

### PostgreSQL (Port 5432)

-   **Image:** postgres:15-alpine
-   **Database:** chiro_erp
-   **Init Script:** `/scripts/init-databases.sql`
-   **Resource Limits:** 2 CPUs, 2GB RAM

### Redis (Port 6379)

-   **Image:** redis:7-alpine
-   **Purpose:** Caching, session management
-   **Resource Limits:** 0.5 CPUs, 512MB RAM

### Kafka (Port 9092, 9093)

-   **Image:** confluentinc/cp-kafka:latest
-   **Mode:** KRaft (without Zookeeper dependency)
-   **Purpose:** Event streaming, inter-service communication
-   **Resource Limits:** 1 CPU, 1GB RAM

### MinIO (Ports 9000, 9001)

-   **Image:** minio/minio:latest
-   **Purpose:** Object storage for files and documents
-   **Resource Limits:** 1 CPU, 1GB RAM

### Keycloak (Port 8180)

-   **Image:** quay.io/keycloak/keycloak:23.0
-   **Purpose:** Identity and access management
-   **Database:** Separate keycloak database
-   **Resource Limits:** 1 CPU, 1GB RAM

## Monitoring Services

### Prometheus (Port 9090)

-   **Image:** prom/prometheus:latest
-   **Purpose:** Metrics collection and monitoring
-   **Resource Limits:** 0.5 CPUs, 512MB RAM

### Grafana (Port 3000)

-   **Image:** grafana/grafana:latest
-   **Purpose:** Metrics visualization
-   **Credentials:** admin/admin
-   **Resource Limits:** 0.5 CPUs, 512MB RAM

## Deployment Scripts

### 1. Start Services

```powershell
.\scripts\start-microservices.ps1
```

This script:

-   Creates Docker network
-   Builds all Gradle projects
-   Builds Docker images
-   Starts infrastructure services first
-   Starts core-platform service
-   Starts remaining microservices
-   Starts monitoring services

### 2. Test Deployment

```powershell
.\scripts\test-deployment.ps1 [-StartServices] [-StopServices] [-FullTest]
```

This script validates:

-   Docker Compose configuration
-   Docker system resources
-   Service startup
-   Health check endpoints
-   Container resource usage

### 3. Test Health Checks

```powershell
.\scripts\test-health-checks.ps1
```

This script:

-   Tests all service health endpoints
-   Displays detailed health check results
-   Shows Docker container status
-   Returns appropriate exit codes

## Service URLs

### Microservices

-   Core Platform: http://localhost:8081
-   Administration: http://localhost:8082
-   Customer Relationship: http://localhost:8083
-   Operations Service: http://localhost:8084
-   Commerce: http://localhost:8085
-   Financial Management: http://localhost:8086
-   Supply Chain Manufacturing: http://localhost:8087

### Infrastructure

-   Keycloak Admin: http://localhost:8180/admin (admin/admin)
-   MinIO Console: http://localhost:9001 (minioadmin/minioadmin)
-   Prometheus: http://localhost:9090
-   Grafana: http://localhost:3000 (admin/admin)

## Health Check Endpoints

Each service exposes Quarkus health check endpoints:

-   **Readiness:** `http://localhost:{port}/q/health/ready`
-   **Liveness:** `http://localhost:{port}/q/health/live`
-   **Health UI:** `http://localhost:{port}/q/health-ui`

## Environment Variables

### Common Variables (All Services)

-   `DB_USERNAME`: Database user for the service
-   `DB_PASSWORD`: Database password for the service
-   `DB_URL`: PostgreSQL connection URL with schema
-   `REDIS_URL`: Redis connection URL
-   `KAFKA_BOOTSTRAP_SERVERS`: Kafka broker addresses
-   `OIDC_SERVER_URL`: Keycloak OIDC server URL
-   `OIDC_CLIENT_SECRET`: Service-specific client secret

### Service-Specific Variables

Services with file storage (Commerce, Customer Relationship, Operations, Supply Chain):

-   `S3_ENDPOINT`: MinIO endpoint URL
-   `AWS_ACCESS_KEY`: MinIO access key
-   `AWS_SECRET_KEY`: MinIO secret key

## Resource Requirements

### Minimum System Requirements

-   **CPUs:** 12.75 cores
-   **Memory:** 12 GB RAM
-   **Disk:** 50 GB available space

### Per-Service Allocation

Each microservice:

-   **CPU Limit:** 1.0 CPU
-   **CPU Reservation:** 0.5 CPU
-   **Memory Limit:** 1 GB
-   **Memory Reservation:** 512 MB

## Docker Network

-   **Network Name:** chiro-erp-network
-   **Driver:** bridge
-   **Purpose:** Inter-service communication

## Volumes

-   `postgres_data`: PostgreSQL data persistence
-   `minio_data`: MinIO object storage persistence
-   `grafana_data`: Grafana dashboard persistence

## Security Configuration

### OIDC Authentication

All services integrate with Keycloak for authentication:

-   **Realm:** chiro-erp
-   **Protocol:** OIDC (OpenID Connect)
-   **Client Credentials:** Service-specific secrets

### Database Security

-   Schema-level isolation
-   User-specific permissions
-   Password-protected access
-   Connection encryption ready

## Development Mode

In development mode (quarkus.profile=dev):

-   Database connections are disabled
-   Services start without infrastructure dependencies
-   Hot reload enabled
-   Swagger UI available at `/{service}/swagger-ui`

## Next Steps

1. **Run the create structure script:**

    ```powershell
    .\scripts\create-complete-structure.ps1
    ```

2. **Build services:**

    ```powershell
    .\gradlew clean build -x test
    ```

3. **Start deployment:**

    ```powershell
    .\scripts\start-microservices.ps1
    ```

4. **Verify health:**
    ```powershell
    .\scripts\test-health-checks.ps1
    ```

## Migration Notes

This consolidated architecture replaces the original 30+ microservices structure with:

-   ✅ 7 consolidated services (76% reduction)
-   ✅ Domain-driven design with hexagonal architecture
-   ✅ Single database with schema separation
-   ✅ Simplified deployment and monitoring
-   ✅ Reduced operational complexity
-   ✅ Maintained domain boundaries and separation of concerns

For detailed domain models and migration guide, see:

-   `docs/architecture/BOUNDED-CONTEXTS.md`
-   `docs/SERVICE-DOMAIN-MODELS-INDEX.md`
