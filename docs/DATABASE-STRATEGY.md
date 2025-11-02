# Database Strategy for ChiroERP Microservices

## Current Architecture

### Single Database with Schema Separation

**Updated:** November 2, 2025 - Migrated from database-per-service to schema-based separation

This architecture uses **one PostgreSQL database** with **separate schemas** for each service to ensure:

-   **Data Autonomy**: Services own their schema and data
-   **Logical Isolation**: Schemas provide namespace separation
-   **Resource Efficiency**: Single database instance reduces overhead
-   **Access Control**: Schema-level permissions maintain security
-   **Simplified Operations**: Easier backups, monitoring, and management

### Database Configuration

#### Single PostgreSQL Instance with Multiple Schemas

```yaml
postgresql:
    host: localhost
    port: 5432
    database: chiro_erp (single database)
    schemas: 8 service schemas
    total_storage: Shared volume
```

#### Service Schemas

| Service                    | Schema            | Schema Owner    | Purpose                                             |
| -------------------------- | ----------------- | --------------- | --------------------------------------------------- |
| core-platform              | core_schema       | core_user       | Authentication, authorization, audit, notifications |
| analytics-intelligence     | analytics_schema  | analytics_user  | Analytics, ML models, reporting data                |
| commerce                   | commerce_schema   | commerce_user   | Products, orders, payments, catalog                 |
| customer-relationship      | crm_schema        | crm_user        | Customers, leads, opportunities, support            |
| financial-management       | finance_schema    | finance_user    | GL, AP, AR, assets, tax, expenses                   |
| logistics-transportation   | logistics_schema  | logistics_user  | Fleet, TMS, WMS data                                |
| operations-service         | operations_schema | operations_user | Field service, scheduling, repairs                  |
| supply-chain-manufacturing | supply_schema     | supply_user     | Inventory, production, procurement                  |

**Connection String Format:**

```
postgresql://localhost:5432/chiro_erp?currentSchema=<schema_name>
```

## Cross-Service Data Access Patterns

### ❌ Anti-Patterns (Avoid These)

1. **Direct Database Access**: Never query another service's database

    ```kotlin
    // WRONG: Don't do this!
    val connection = DriverManager.getConnection("jdbc:postgresql://localhost:5432/commerce_db")
    ```

2. **Shared Database Tables**: Don't create shared tables across services

3. **Distributed Transactions**: Avoid 2-phase commits across services

### ✅ Recommended Patterns

#### 1. Event-Driven Communication (Primary)

Use Kafka for asynchronous data sharing:

```kotlin
// Commerce Service publishes order created event
@Outgoing("order-events")
fun publishOrderCreated(order: Order): Message<OrderCreatedEvent> {
    return Message.of(OrderCreatedEvent(
        orderId = order.id,
        customerId = order.customerId,
        totalAmount = order.total,
        timestamp = Instant.now()
    ))
}

// Financial Service consumes the event
@Incoming("order-events")
fun handleOrderCreated(event: OrderCreatedEvent) {
    // Create invoice in finance_db
    invoiceService.createFromOrder(event)
}
```

**Topics Structure**:

```
commerce.orders          -> Order lifecycle events
commerce.payments        -> Payment events
finance.invoices         -> Invoice events
crm.customers           -> Customer updates
supply.inventory        -> Inventory changes
logistics.shipments     -> Shipping events
platform.notifications  -> System notifications
```

#### 2. API Gateway Pattern

Use REST APIs for synchronous queries:

```kotlin
// Customer Service exposes customer data
@Path("/api/customers/{id}")
@GET
fun getCustomer(@PathParam("id") id: String): CustomerDTO {
    return customerRepository.findById(id)?.toDTO()
}

// Commerce Service consumes via REST
@RestClient
interface CustomerClient {
    @GET
    @Path("/api/customers/{id}")
    fun getCustomer(@PathParam("id") id: String): CustomerDTO
}
```

#### 3. CQRS with Read Models

Maintain local read replicas for frequently accessed data:

```kotlin
// Commerce service maintains local customer cache
@Entity
@Table(name = "customer_read_model")
data class CustomerReadModel(
    @Id val id: String,
    val name: String,
    val email: String,
    val lastUpdated: Instant
)

// Updated via Kafka events from CRM service
@Incoming("crm.customer-updates")
fun updateCustomerCache(event: CustomerUpdatedEvent) {
    customerReadModelRepository.save(event.toReadModel())
}
```

#### 4. Saga Pattern for Distributed Transactions

Coordinate complex workflows across services:

```kotlin
// Order Saga Orchestrator
class OrderSaga {
    suspend fun processOrder(order: Order) {
        try {
            // Step 1: Reserve inventory (Supply Chain)
            val reservation = inventoryService.reserve(order.items)

            // Step 2: Authorize payment (Commerce)
            val payment = paymentService.authorize(order.total)

            // Step 3: Create shipment (Logistics)
            val shipment = shippingService.create(order, reservation)

            // Step 4: Confirm order
            orderService.confirm(order.id)

        } catch (e: Exception) {
            // Compensating transactions
            inventoryService.releaseReservation(reservation.id)
            paymentService.cancelAuthorization(payment.id)
        }
    }
}
```

## Data Consistency Strategies

### Eventual Consistency

Most inter-service data operations use eventual consistency:

```kotlin
// Example: Customer updates flow through the system
1. CRM Service: Update customer → Publish event
2. Commerce Service: Receive event → Update local cache (100ms later)
3. Analytics Service: Receive event → Update reports (5 minutes later)
```

### Strong Consistency (When Required)

For critical operations requiring immediate consistency:

```kotlin
// Synchronous API call with retry logic
@Retry(maxRetries = 3, delay = 1000)
suspend fun verifyInventory(productId: String, quantity: Int): Boolean {
    return inventoryClient.checkAvailability(productId, quantity)
}
```

## Database Scaling Strategies

### Development Environment (Current)

-   Single PostgreSQL instance
-   Multiple databases
-   Shared resources
-   Fast startup

### Production Recommendations

#### Option 1: Separate Database Instances

```yaml
# Each service gets dedicated PostgreSQL instance
core-platform:
    postgresql-core:
        host: postgres-core.internal
        replication: read-replicas (2)

commerce:
    postgresql-commerce:
        host: postgres-commerce.internal
        replication: read-replicas (3) # High read load
```

#### Option 2: Managed Database Services

```yaml
# Use cloud-managed databases
core-platform:
    database: Azure Database for PostgreSQL
    tier: General Purpose

analytics-intelligence:
    database: Azure Synapse Analytics # Data warehouse

commerce:
    primary: Azure Database for PostgreSQL
    cache: Azure Cache for Redis
```

#### Option 3: Polyglot Persistence

```yaml
# Different databases for different needs
commerce:
    primary: PostgreSQL (transactional data)
    search: Elasticsearch (product catalog)
    cache: Redis (session, cart)

analytics-intelligence:
    warehouse: Snowflake (analytics)
    timeseries: InfluxDB (metrics)

customer-relationship:
    primary: PostgreSQL (structured data)
    documents: MongoDB (unstructured data)
```

## Migration & Backup Strategies

### Schema Management

Each service manages its own schema:

```kotlin
// Use Flyway or Liquibase per service
quarkus.flyway.migrate-at-start=true
quarkus.flyway.locations=classpath:db/migration
```

```
services/commerce/src/main/resources/db/migration/
    V1__create_products_table.sql
    V2__create_orders_table.sql
    V3__add_order_status_index.sql
```

### Backup Strategy

#### Development

```bash
# Backup all databases
pg_dumpall -U postgres > chiro_erp_backup.sql

# Backup single service database
pg_dump -U commerce_user commerce_db > commerce_backup.sql
```

#### Production

```yaml
automated_backups:
    frequency: hourly
    retention: 30 days
    strategy: incremental

point_in_time_recovery:
    enabled: true
    retention: 7 days

cross_region_replication:
    enabled: true
    target_region: secondary_datacenter
```

## Monitoring & Observability

### Database Metrics per Service

```properties
# Prometheus metrics
quarkus.datasource.metrics.enabled=true

# Monitor per service:
- Connection pool utilization
- Query execution time
- Transaction rollback rate
- Database size growth
- Slow query logs
```

### Distributed Tracing

```kotlin
// Trace data flow across services
@Traced
suspend fun createOrder(order: Order) {
    // Trace ID flows through Kafka events
    // Shows end-to-end latency
}
```

## Security Best Practices

### 1. Principle of Least Privilege

```sql
-- Service users only access their database
GRANT CONNECT ON DATABASE commerce_db TO commerce_user;
REVOKE ALL ON DATABASE finance_db FROM commerce_user;
```

### 2. Encrypted Connections

```properties
# Force SSL in production
quarkus.datasource.jdbc.url=jdbc:postgresql://localhost:5432/commerce_db?ssl=true&sslmode=require
```

### 3. Secret Management

```yaml
# Use secret management tools
secrets:
    DB_PASSWORD: ${vault:secret/commerce/db-password}
    DB_USERNAME: ${vault:secret/commerce/db-username}
```

### 4. Network Isolation

```yaml
# Services on private network
networks:
    backend:
        internal: true
    frontend:
        external: true
```

## Testing Strategies

### Unit Tests

```kotlin
// Use H2 in-memory database for fast tests
%test.quarkus.datasource.db-kind=h2
%test.quarkus.datasource.jdbc.url=jdbc:h2:mem:test
```

### Integration Tests

```kotlin
// Use Testcontainers for realistic tests
@QuarkusTest
@TestProfile(PostgresTestProfile::class)
class OrderRepositoryTest {

    @Inject
    lateinit var orderRepository: OrderRepository

    companion object {
        @Container
        val postgres = PostgreSQLContainer("postgres:15-alpine")
            .withDatabaseName("commerce_test")
    }
}
```

### Contract Tests

```kotlin
// Verify API contracts between services
@Pact(consumer = "commerce-service")
fun customerApiContract() = pact {
    given("customer exists")
    upon receiving("get customer request")
        .method("GET")
        .path("/api/customers/123")
    will respond with {
        status = 200
        body = CustomerDTO(id = "123", name = "John Doe")
    }
}
```

## Troubleshooting Common Issues

### Issue 1: Service Can't Connect to Database

```bash
# Check database exists
docker exec -it postgresql psql -U postgres -c "\l"

# Check user permissions
docker exec -it postgresql psql -U postgres -c "\du"

# Test connection
docker exec -it postgresql psql -U commerce_user -d commerce_db
```

### Issue 2: Slow Queries

```sql
-- Enable query logging
ALTER DATABASE commerce_db SET log_statement = 'all';
ALTER DATABASE commerce_db SET log_duration = on;

-- Find slow queries
SELECT query, mean_exec_time, calls
FROM pg_stat_statements
WHERE mean_exec_time > 1000
ORDER BY mean_exec_time DESC;
```

### Issue 3: Connection Pool Exhaustion

```properties
# Tune connection pool per service
quarkus.datasource.jdbc.max-size=20
quarkus.datasource.jdbc.min-size=5
quarkus.datasource.jdbc.acquisition-timeout=30
```

## Future Enhancements

1. **Read Replicas**: Add read-only replicas for heavy-read services
2. **Sharding**: Partition large tables (orders, transactions) by date/tenant
3. **CDC (Change Data Capture)**: Use Debezium for real-time data pipelines
4. **Multi-Region**: Replicate databases across regions for disaster recovery
5. **Data Lake**: Aggregate analytics data into centralized data lake

## References

-   [Microservices Database Patterns](https://microservices.io/patterns/data/database-per-service.html)
-   [PostgreSQL Multi-Database Setup](https://www.postgresql.org/docs/15/managing-databases.html)
-   [Quarkus Datasource Configuration](https://quarkus.io/guides/datasource)
-   [Event-Driven Architecture](https://martinfowler.com/articles/201701-event-driven.html)
-   [CQRS Pattern](https://martinfowler.com/bliki/CQRS.html)
