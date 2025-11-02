# ChiroERP Consolidated Services - Quick Reference

## 🚀 Quick Commands

```powershell
# Create complete structure
.\scripts\create-complete-structure.ps1

# Start all services
.\scripts\start-microservices.ps1

# Test deployment
.\scripts\test-deployment.ps1

# Check health
.\scripts\test-health-checks.ps1

# View logs
docker-compose logs -f [service-name]

# Stop all services
docker-compose down

# Reset everything (including data)
docker-compose down -v
```

## 📊 Service Map

| Service               | Port | URL                   | Health Check                         |
| --------------------- | ---- | --------------------- | ------------------------------------ |
| Core Platform         | 8081 | http://localhost:8081 | http://localhost:8081/q/health/ready |
| Administration        | 8082 | http://localhost:8082 | http://localhost:8082/q/health/ready |
| Customer Relationship | 8083 | http://localhost:8083 | http://localhost:8083/q/health/ready |
| Operations Service    | 8084 | http://localhost:8084 | http://localhost:8084/q/health/ready |
| Commerce              | 8085 | http://localhost:8085 | http://localhost:8085/q/health/ready |
| Financial Management  | 8086 | http://localhost:8086 | http://localhost:8086/q/health/ready |
| Supply Chain Mfg      | 8087 | http://localhost:8087 | http://localhost:8087/q/health/ready |

## 🛠️ Infrastructure Services

| Service    | Port       | Access                      | Credentials           |
| ---------- | ---------- | --------------------------- | --------------------- |
| PostgreSQL | 5432       | localhost:5432              | postgres/postgres     |
| Redis      | 6379       | localhost:6379              | -                     |
| Kafka      | 9092, 9093 | localhost:9092              | -                     |
| MinIO      | 9000, 9001 | http://localhost:9001       | minioadmin/minioadmin |
| Keycloak   | 8180       | http://localhost:8180/admin | admin/admin           |
| Prometheus | 9090       | http://localhost:9090       | -                     |
| Grafana    | 3000       | http://localhost:3000       | admin/admin           |

## 🗄️ Database Structure

**Database:** `chiro_erp`

| Schema                          | User                          | Service                    |
| ------------------------------- | ----------------------------- | -------------------------- |
| core_schema                     | core_user                     | Core Platform              |
| administration_schema           | administration_user           | Administration             |
| customerrelationship_schema     | customerrelationship_user     | Customer Relationship      |
| operationsservice_schema        | operationsservice_user        | Operations Service         |
| commerce_schema                 | commerce_user                 | Commerce                   |
| financialmanagement_schema      | financialmanagement_user      | Financial Management       |
| supplychainmanufacturing_schema | supplychainmanufacturing_user | Supply Chain Manufacturing |

## 🏗️ Service Domains

### Core Platform (8081)

-   security
-   organization
-   audit
-   configuration
-   notification
-   integration

### Administration (8082)

-   hr
-   logistics-transportation
-   analytics-intelligence
-   project-management

### Customer Relationship (8083)

-   crm
-   client
-   provider
-   subscription
-   promotion

### Operations Service (8084)

-   field-service
-   scheduling
-   records
-   repair-rma

### Commerce (8085)

-   ecommerce
-   portal
-   communication
-   pos

### Financial Management (8086)

-   general-ledger
-   accounts-payable
-   accounts-receivable
-   asset-accounting
-   tax-engine
-   expense-management

### Supply Chain Manufacturing (8087)

-   production
-   quality
-   inventory
-   product-costing
-   procurement

## 📁 Directory Structure

```
services/{service}/
├── src/
│   ├── main/
│   │   ├── kotlin/com/chiro/erp/{service}/
│   │   │   ├── {domain}/
│   │   │   │   ├── domain/
│   │   │   │   │   ├── models/
│   │   │   │   │   ├── services/
│   │   │   │   │   └── ports/
│   │   │   │   │       ├── inbound/    (use cases)
│   │   │   │   │       └── outbound/   (repositories)
│   │   │   │   ├── application/         (use case implementations)
│   │   │   │   ├── infrastructure/
│   │   │   │   │   ├── persistence/
│   │   │   │   │   ├── messaging/
│   │   │   │   │   └── external/
│   │   │   │   └── interfaces/
│   │   │   │       ├── rest/
│   │   │   │       ├── graphql/
│   │   │   │       └── events/
│   │   │   └── shared/
│   │   ├── resources/
│   │   │   └── application.properties
│   │   └── docker/
│   │       └── Dockerfile.jvm
│   └── test/
└── build.gradle
```

## 🔧 Environment Variables

### Common (All Services)

```properties
DB_USERNAME={service}_user
DB_PASSWORD={service}_pass
DB_URL=postgresql://postgresql:5432/chiro_erp?currentSchema={service}_schema
REDIS_URL=redis://redis:6379
KAFKA_BOOTSTRAP_SERVERS=kafka:9092
OIDC_SERVER_URL=http://keycloak:8180/realms/chiro-erp
OIDC_CLIENT_SECRET={service}-secret
```

### Storage Services (Commerce, CRM, Operations, Supply Chain)

```properties
S3_ENDPOINT=http://minio:9000
AWS_ACCESS_KEY=minioadmin
AWS_SECRET_KEY=minioadmin
```

## 💻 Development Mode

```shell
cd services/{service}
../../gradlew quarkusDev
```

Features:

-   Hot reload
-   Dev UI at http://localhost:{port}/q/dev/
-   Swagger UI at http://localhost:{port}/q/swagger-ui
-   Database disabled (no infrastructure required)

## 🧪 Testing

```powershell
# Run all tests
./gradlew test

# Run specific service tests
./gradlew :services:{service}:test

# Build without tests
./gradlew build -x test
```

## 📦 Building

```powershell
# Build all services
./gradlew clean build

# Build specific service
./gradlew :services:{service}:build

# Build Docker images
docker-compose build
```

## 🐛 Troubleshooting

### Service won't start

```powershell
# Check logs
docker-compose logs {service-name}

# Check health
curl http://localhost:{port}/q/health

# Restart service
docker-compose restart {service-name}
```

### Database connection issues

```powershell
# Check PostgreSQL
docker-compose logs postgresql

# Connect to database
docker exec -it chiro-erp-postgresql-1 psql -U postgres -d chiro_erp

# List schemas
\dn
```

### Port conflicts

```powershell
# Check what's using a port (Windows)
netstat -ano | findstr :{port}

# Kill process
taskkill /PID {pid} /F
```

## 📈 Resource Monitoring

```powershell
# View resource usage
docker stats

# Monitor specific service
docker stats {container-name}

# Check Prometheus metrics
curl http://localhost:9090/metrics
```

## 🔄 Migration from Old Structure

The consolidated architecture replaces:

-   ✅ 30+ microservices → 7 consolidated services
-   ✅ Multiple databases → Single database with schemas
-   ✅ Complex networking → Simplified service mesh
-   ✅ Scattered domains → Organized bounded contexts

## 📚 Documentation

-   [Full Deployment Guide](CONSOLIDATED-DEPLOYMENT-GUIDE.md)
-   [Architecture Details](architecture/ARCHITECTURE-SUMMARY.md)
-   [Domain Models](SERVICE-DOMAIN-MODELS-INDEX.md)
-   [Testing Guide](TESTING-GUIDE.md)

## 🆘 Need Help?

1. Check service logs: `docker-compose logs -f {service}`
2. Verify health: `.\scripts\test-health-checks.ps1`
3. Review documentation in `/docs`
4. Check Grafana dashboards: http://localhost:3000
