# ChiroERP Microservices Architecture

## Overview

ChiroERP has been architected as a microservices-based enterprise resource planning system using **Quarkus** and **Kotlin**. The system consists of 8 domain-driven microservices, each responsible for specific business capabilities.

## Microservices Architecture

### Core Services

| Service | Port | Description | Database |
|---------|------|-------------|----------|
| **Core Platform** | 8080 | Authentication, authorization, configuration, audit, notifications | core_db |
| **Analytics Intelligence** | 8081 | Data analytics, ML, reporting, business intelligence | analytics_db |
| **Commerce** | 8082 | E-commerce, catalog, orders, payments | commerce_db |
| **Customer Relationship** | 8083 | CRM, customer management, support, communication | crm_db |
| **Financial Management** | 8084 | Accounting, invoicing, payments, financial reporting | finance_db |
| **Logistics Transportation** | 8085 | Shipping, tracking, route optimization | logistics_db |
| **Operations Service** | 8086 | Workflow, quality control, maintenance, resource planning | operations_db |
| **Supply Chain Manufacturing** | 8087 | Procurement, inventory, production planning, MRP | supply_db |

### Infrastructure Components

- **PostgreSQL**: Primary database for all services
- **Redis**: Caching and session storage
- **Apache Kafka**: Event streaming and inter-service communication
- **MinIO**: Object storage (S3-compatible)
- **Keycloak**: Identity and access management
- **Prometheus**: Metrics collection
- **Grafana**: Monitoring dashboards
- **Traefik**: API Gateway and load balancer

## Technology Stack

- **Runtime**: Quarkus 3.29.0
- **Language**: Kotlin 2.2.20
- **JVM**: OpenJDK 21
- **Database**: PostgreSQL 15
- **Message Broker**: Apache Kafka
- **Cache**: Redis 7
- **Object Storage**: MinIO
- **Identity**: Keycloak 23.0
- **Containerization**: Docker & Docker Compose
- **Build Tool**: Gradle 8.x

## Project Structure

```
chiro-erp/
├── build.gradle                           # Root build configuration
├── settings.gradle                        # Multi-module settings
├── gradle.properties                      # Centralized version management
├── docker-compose.yml                     # Full stack deployment
├── docker-compose.gateway.yml             # API Gateway configuration
├── scripts/
│   ├── start-microservices.ps1           # Startup script
│   └── init-databases.sql                # Database initialization
└── services/
    ├── analytics-intelligence/
    │   ├── build.gradle                   # Service-specific dependencies
    │   ├── src/main/kotlin/               # Kotlin source code
    │   ├── src/main/resources/            # Configuration files
    │   └── src/main/docker/               # Docker configuration
    ├── commerce/
    ├── core-platform/
    ├── customer-relationship/
    ├── financial-management/
    ├── logistics-transportation/
    ├── operations-service/
    └── supply-chain-manufacturing/
```

## Getting Started

### Prerequisites

- Docker Desktop
- PowerShell (Windows) or Bash (Linux/Mac)
- Java 21 JDK
- Gradle 8.x

### Quick Start

1. **Clone and navigate to the project**:
   ```bash
   git clone <repository-url>
   cd chiro-erp
   ```

2. **Start all services**:
   ```powershell
   .\scripts\start-microservices.ps1
   ```

3. **Access the services**:
   - Core Platform API: http://localhost:8080
   - Analytics Intelligence: http://localhost:8081
   - Commerce: http://localhost:8082
   - Customer Relationship: http://localhost:8083
   - Financial Management: http://localhost:8084
   - Logistics Transportation: http://localhost:8085
   - Operations Service: http://localhost:8086
   - Supply Chain Manufacturing: http://localhost:8087

### Management Interfaces

- **Keycloak Admin**: http://localhost:8080/admin (admin/admin)
- **MinIO Console**: http://localhost:9001 (minioadmin/minioadmin)
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (admin/admin)

### Manual Build & Run

1. **Build all services**:
   ```bash
   ./gradlew buildAllServices
   ```

2. **Start infrastructure**:
   ```bash
   docker-compose up -d postgresql redis kafka zookeeper minio keycloak
   ```

3. **Start individual service**:
   ```bash
   ./gradlew :services:core-platform:quarkusDev
   ```

## Service Communication

### Event-Driven Architecture

Services communicate through Apache Kafka topics:

- **Platform Events**: `platform.events`, `platform.notifications`
- **Analytics**: `analytics.events`, `intelligence.reports`
- **Commerce**: `commerce.orders`, `commerce.payments`
- **CRM**: `crm.customers`, `crm.analytics`
- **Finance**: `finance.transactions`, `finance.reports`

### REST API Communication

- All services expose REST APIs documented via OpenAPI/Swagger
- API Gateway (Traefik) provides unified entry point
- Service-to-service calls use reactive HTTP clients

### Security

- **OAuth 2.0/OpenID Connect** via Keycloak
- **JWT tokens** for service authentication
- **Role-based access control (RBAC)**
- **Service-to-service security** with client credentials

## Development

### Running Individual Services

Each service can be run independently for development:

```bash
# Core Platform
./gradlew :services:core-platform:quarkusDev

# Analytics Intelligence  
./gradlew :services:analytics-intelligence:quarkusDev

# Commerce
./gradlew :services:commerce:quarkusDev
```

### Configuration

Each service has its own `application.properties` with:
- Database connection settings
- Kafka topic configurations
- Security settings
- Service-specific configurations

Environment variables can override default configurations.

### Testing

```bash
# Run all tests
./gradlew test

# Run tests for specific service
./gradlew :services:core-platform:test
```

## Monitoring & Observability

### Health Checks

Each service exposes health endpoints:
- `/q/health` - Overall health
- `/q/health/live` - Liveness probe
- `/q/health/ready` - Readiness probe

### Metrics

Prometheus metrics available at `/q/metrics` for each service.

### Logging

Structured JSON logging with correlation IDs for request tracing.

## Deployment

### Docker Compose (Development)

```bash
docker-compose up -d
```

### Kubernetes (Production)

Generate Kubernetes manifests:
```bash
./gradlew :services:core-platform:quarkus:generateKubernetesManifests
```

## Database Management

### Database per Service

Each microservice has its own PostgreSQL database:
- Ensures data isolation
- Allows independent scaling
- Enables polyglot persistence (if needed)

### Migrations

Database schema managed through Hibernate with `quarkus.hibernate-orm.database.generation=update`.

## API Documentation

Each service provides Swagger UI:
- Core Platform: http://localhost:8080/core/swagger-ui
- Analytics: http://localhost:8081/analytics/swagger-ui
- Commerce: http://localhost:8082/commerce/swagger-ui
- etc.

## Contributing

1. Create feature branch from `main`
2. Develop in relevant service(s)
3. Add tests for new functionality
4. Update documentation
5. Submit pull request

## License

[Your License Here]
