# Shared Event Library - ChiroERP

## Overview

The Shared Event Library provides a comprehensive set of domain events for event-driven communication across all microservices in the ChiroERP system. This library implements Domain-Driven Design (DDD) principles and supports both domain events and integration events.

## Architecture

### Event Types

1. **Domain Events** - Events that occur within a bounded context
2. **Integration Events** - Subset of domain events published across services
3. **Simple Events** - Legacy test events (deprecated, for backward compatibility)

### Event Categories

The library includes events for the following business domains:

-   **Customer Management** - Customer lifecycle events
-   **Order Processing** - Sales and service order events
-   **Financial Management** - Invoice and payment events
-   **Inventory Management** - Stock and material events
-   **Service Operations** - Field service and work order events
-   **User Management** - Identity and access events

## File Structure

```
services/core-platform/src/main/kotlin/com/chiro/erp/coreplatform/shared/events/
├── BaseEvents.kt              # Base interfaces and classes
├── CustomerEvents.kt          # Customer-related events
├── OrderEvents.kt             # Order and commerce events
├── InvoiceEvents.kt           # Invoice and payment events
├── InventoryEvents.kt         # Inventory and material events
├── ServiceOrderEvents.kt      # Service order events
├── UserEvents.kt              # User and identity events
├── EventPublisher.kt          # Event publishing utility
└── DomainEvent.kt            # Legacy (deprecated)
```

## Base Event Types

### DomainEvent Interface

All domain events implement this interface:

```kotlin
sealed interface DomainEvent {
    val eventId: UUID              // Unique event identifier
    val aggregateId: UUID          // Aggregate root ID
    val aggregateType: String      // Type of aggregate (e.g., "Customer")
    val eventType: String          // Specific event type (e.g., "CustomerCreated")
    val occurredAt: Instant        // When the event occurred
    val tenantId: UUID             // Multi-tenancy support
    val metadata: EventMetadata    // Additional metadata
}
```

### EventMetadata

Every event includes metadata for traceability:

```kotlin
data class EventMetadata(
    val causationId: UUID?,        // Event that caused this event
    val correlationId: UUID,       // Business flow tracking ID
    val userId: UUID,              // User who triggered the event
    val source: String,            // Service that published the event
    val version: Int = 1,          // Event schema version
    val additionalData: Map<String, String> = emptyMap()
)
```

## Event Examples

### Customer Events

#### CustomerCreatedEvent

Published when a new customer is created:

```kotlin
val event = CustomerCreatedEvent(
    aggregateId = customerId,
    tenantId = tenantId,
    metadata = EventMetadata(
        correlationId = UUID.randomUUID(),
        userId = currentUserId,
        source = "customer-relationship"
    ),
    customerId = customerId,
    customerNumber = "CUST-001",
    customerType = CustomerType.B2B,
    status = CustomerStatus.ACTIVE,
    personalInfo = CustomerPersonalInfo(
        firstName = "John",
        lastName = "Doe",
        fullName = "John Doe",
        email = "john.doe@example.com"
    ),
    contactInfo = CustomerContactInfo(
        primaryEmail = "john.doe@example.com",
        primaryPhone = "+1-555-0100"
    )
)
```

### Order Events

#### OrderCreatedEvent

Published when a new order is placed:

```kotlin
val event = OrderCreatedEvent(
    aggregateId = orderId,
    tenantId = tenantId,
    metadata = metadata,
    orderId = orderId,
    orderNumber = "ORD-001",
    customerId = customerId,
    orderDate = Instant.now(),
    orderType = OrderType.SALES_ORDER,
    items = listOf(
        OrderLineItem(
            lineNumber = 1,
            productId = productId,
            productCode = "PROD-001",
            productName = "Widget",
            quantity = BigDecimal("10"),
            unitPrice = BigDecimal("99.99"),
            lineTotal = BigDecimal("999.90")
        )
    ),
    totalAmount = BigDecimal("999.90"),
    currency = "USD",
    status = OrderStatus.PENDING
)
```

### Invoice Events

#### InvoiceCreatedEvent

Published when an invoice is generated:

```kotlin
val event = InvoiceCreatedEvent(
    aggregateId = invoiceId,
    tenantId = tenantId,
    metadata = metadata,
    invoiceId = invoiceId,
    invoiceNumber = "INV-001",
    customerId = customerId,
    orderId = orderId,
    invoiceDate = LocalDate.now(),
    dueDate = LocalDate.now().plusDays(30),
    totalAmount = BigDecimal("1199.88"),
    taxAmount = BigDecimal("199.98"),
    netAmount = BigDecimal("999.90"),
    currency = "USD",
    status = InvoiceStatus.PENDING,
    lineItems = listOf(...)
)
```

## Using the Event Publisher

### Publishing Single Events

```kotlin
@ApplicationScoped
class CustomerService(
    private val eventPublisher: EventPublisher
) {
    fun createCustomer(command: CreateCustomerCommand): Customer {
        // Business logic to create customer
        val customer = ...

        // Publish event
        val event = CustomerCreatedEvent(
            aggregateId = customer.id,
            tenantId = command.tenantId,
            metadata = createMetadata(command),
            // ... other fields
        )

        eventPublisher.publish(event)

        return customer
    }
}
```

### Publishing Multiple Events

```kotlin
fun completeOrder(orderId: UUID) {
    val events = listOf(
        OrderConfirmedEvent(...),
        InventoryAllocatedEvent(...),
        InvoiceCreatedEvent(...)
    )

    eventPublisher.publishAll(events)
}
```

## Topic Routing

Events are automatically routed to appropriate Kafka topics:

| Event Type           | Kafka Topic                       |
| -------------------- | --------------------------------- |
| Customer events      | `crm.customer.events`             |
| Order events         | `commerce.order.events`           |
| Invoice events       | `finance.invoice.events`          |
| Inventory events     | `supply.inventory.events`         |
| Service Order events | `operations.service-order.events` |
| User events          | `platform.user.events`            |
| Internal events      | `platform.internal.events`        |

## Consuming Events

### In Application Service

```kotlin
@ApplicationScoped
class OrderEventListener(
    private val invoiceService: InvoiceService
) {
    @Incoming("commerce.order.events")
    suspend fun onOrderConfirmed(event: OrderConfirmedEvent) {
        // Create invoice when order is confirmed
        invoiceService.createFromOrder(event.orderId)
    }
}
```

### With Error Handling

```kotlin
@ApplicationScoped
class CustomerEventListener(
    private val repository: ShopperProfileRepository
) {
    @Incoming("crm.customer.events")
    suspend fun onCustomerCreated(event: CustomerCreatedEvent) {
        try {
            val profile = createShopperProfile(event)
            repository.save(profile)
            logger.info("Created shopper profile for customer: ${event.customerId}")
        } catch (e: Exception) {
            logger.error("Failed to create shopper profile", e)
            // Could publish compensation event or add to DLQ
        }
    }
}
```

## Event Versioning

All events include a version field in their metadata:

```kotlin
metadata = EventMetadata(
    version = 1,  // Schema version
    // ...
)
```

When evolving event schemas:

1. **Add new fields** - Always optional with defaults
2. **Never remove fields** - Mark as deprecated instead
3. **Change semantics** - Create new event type (e.g., `CustomerCreatedEventV2`)
4. **Consumers** - Handle multiple versions gracefully

## Event Serialization

Events are serialized to JSON using Jackson:

```json
{
  "eventId": "123e4567-e89b-12d3-a456-426614174000",
  "aggregateId": "789e4567-e89b-12d3-a456-426614174000",
  "aggregateType": "Customer",
  "eventType": "CustomerCreated",
  "occurredAt": "2025-11-03T10:30:00Z",
  "tenantId": "456e4567-e89b-12d3-a456-426614174000",
  "metadata": {
    "correlationId": "cor-123",
    "userId": "usr-456",
    "source": "customer-relationship",
    "version": 1
  },
  "customerId": "789e4567-e89b-12d3-a456-426614174000",
  "customerNumber": "CUST-001",
  "customerType": "B2B",
  "status": "ACTIVE",
  ...
}
```

## Best Practices

### 1. Event Naming

-   Use past tense (e.g., `CustomerCreated`, not `CreateCustomer`)
-   Be specific and descriptive
-   Include aggregate name

### 2. Event Size

-   Keep events focused and minimal
-   Include only essential data
-   Consumer services can query for more details if needed

### 3. Idempotency

-   Consumers should be idempotent
-   Use `eventId` to detect duplicate processing
-   Store processed event IDs if necessary

### 4. Ordering

-   Events from same aggregate maintain order (using Kafka partition key)
-   Events across aggregates are eventually consistent

### 5. Error Handling

-   Log all event publishing failures
-   Implement retry logic for transient failures
-   Consider dead-letter queues for problematic events

### 6. Testing

```kotlin
@Test
fun `should publish customer created event`() {
    // Arrange
    val command = CreateCustomerCommand(...)

    // Act
    service.createCustomer(command)

    // Assert
    verify(eventPublisher).publish(
        argThat { event ->
            event is CustomerCreatedEvent &&
            event.customerNumber == "CUST-001"
        }
    )
}
```

## Migration from Legacy Events

The library maintains backward compatibility with the old `SimpleEvent` format used in test endpoints.

To migrate:

1. Use new event types for new features
2. Gradually update existing code
3. Legacy test endpoints continue to work
4. Eventually remove `SimpleEvent` when all services migrated

## Configuration

### Kafka Configuration

```properties
# Event publishing
mp.messaging.outgoing.domain-events-out.connector=smallrye-kafka
mp.messaging.outgoing.domain-events-out.value.serializer=org.apache.kafka.common.serialization.StringSerializer

# Event consumption
mp.messaging.incoming.customer-events.connector=smallrye-kafka
mp.messaging.incoming.customer-events.topic=crm.customer.events
mp.messaging.incoming.customer-events.group.id=${service-name}-consumer
```

## Monitoring

### Metrics to Track

-   Event publishing rate
-   Event publishing failures
-   Event processing time
-   Consumer lag
-   Dead-letter queue size

### Logging

All events are logged with:

-   Event type
-   Aggregate ID
-   Target topic
-   Correlation ID

Example log:

```
INFO  Published event: CustomerCreated for aggregate: Customer/789e4567... to topic: crm.customer.events
```

## Related Documentation

-   [Kafka Messaging Guide](../../../docs/KAFKA-MESSAGING-GUIDE.md)
-   [DDD Implementation Plan](../../../docs/DDD-IMPLEMENTATION-PLAN.md)
-   [Shared Entities Strategy](../../../docs/architecture/SHARED-ENTITIES-STRATEGY.md)

---

**Last Updated:** November 3, 2025
