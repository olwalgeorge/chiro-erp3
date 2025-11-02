# Migration Guide: Simple Events → Domain Events

## Overview

This guide helps you migrate from the legacy `SimpleEvent` format to the new strongly-typed domain events in the Shared Event Library.

## What's Changing?

### Before (Legacy)

```kotlin
// Simple string-based event
val event = SimpleEvent(
    eventId = UUID.randomUUID().toString(),
    eventType = "CUSTOMER_CREATED",
    serviceName = "customer-relationship",
    payload = "Customer John Doe created"
)
```

### After (New)

```kotlin
// Strongly-typed domain event
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
    personalInfo = CustomerPersonalInfo(...),
    contactInfo = CustomerContactInfo(...)
)
```

## Benefits of Migration

1. **Type Safety** - Compile-time validation, no runtime string errors
2. **Rich Data** - Structured data instead of string payloads
3. **Auto-completion** - IDE support for event fields
4. **Documentation** - Self-documenting event structures
5. **Versioning** - Built-in schema version support
6. **Traceability** - Correlation and causation tracking

## Migration Strategy

### Phase 1: Add New Event Types (✅ COMPLETE)

-   Shared event library created
-   All domain event types defined
-   EventPublisher utility ready

### Phase 2: Parallel Publishing (Current)

-   Keep old SimpleEvent for testing
-   Add new domain events alongside
-   Both systems work together

### Phase 3: Update Consumers

-   Add consumers for new event types
-   Maintain old consumers temporarily
-   Test with both event formats

### Phase 4: Switch Publishers

-   Update services to publish new events
-   Remove old SimpleEvent publishing
-   Keep old format for test endpoints only

### Phase 5: Cleanup

-   Remove old consumers
-   Deprecate SimpleEvent completely
-   Update all documentation

## Step-by-Step Migration

### 1. Identify Event to Migrate

Look for current event publishing code:

```kotlin
// Find code like this
eventProducer.publishEvent(
    eventType = "CUSTOMER_CREATED",
    payload = "..."
)
```

### 2. Choose Appropriate Domain Event

Reference the [Event Library Quick Reference](./EVENT-LIBRARY-QUICK-REF.md) to find the matching domain event:

-   Customer operations → `CustomerEvents.kt`
-   Order operations → `OrderEvents.kt`
-   Invoice operations → `InvoiceEvents.kt`
-   Inventory operations → `InventoryEvents.kt`
-   Service orders → `ServiceOrderEvents.kt`
-   User operations → `UserEvents.kt`

### 3. Create Event Metadata

```kotlin
private fun createMetadata(userId: UUID, correlationId: UUID? = null): EventMetadata {
    return EventMetadata(
        correlationId = correlationId ?: UUID.randomUUID(),
        userId = userId,
        source = "customer-relationship", // Your service name
        version = 1
    )
}
```

### 4. Build Domain Event

```kotlin
val event = CustomerCreatedEvent(
    aggregateId = customer.id,
    tenantId = customer.tenantId,
    metadata = createMetadata(command.userId),
    customerId = customer.id,
    customerNumber = customer.customerNumber,
    customerType = customer.type,
    status = customer.status,
    personalInfo = CustomerPersonalInfo(
        firstName = customer.firstName,
        lastName = customer.lastName,
        fullName = customer.fullName,
        email = customer.email
    ),
    contactInfo = CustomerContactInfo(
        primaryEmail = customer.email,
        primaryPhone = customer.phone
    )
)
```

### 5. Publish Using EventPublisher

```kotlin
@ApplicationScoped
class CustomerService(
    private val eventPublisher: EventPublisher,  // Inject this
    private val repository: CustomerRepository
) {
    fun createCustomer(command: CreateCustomerCommand): Customer {
        val customer = Customer(...)
        repository.save(customer)

        // Publish new domain event
        val event = CustomerCreatedEvent(...)
        eventPublisher.publish(event)

        return customer
    }
}
```

### 6. Create Consumer

```kotlin
@ApplicationScoped
class CustomerEventListener(
    private val objectMapper: ObjectMapper
) {
    private val logger = Logger.getLogger(CustomerEventListener::class.java)

    @Incoming("crm.customer.events")
    suspend fun onCustomerEvent(eventJson: String) {
        try {
            // Deserialize event
            val node = objectMapper.readTree(eventJson)
            val eventType = node.get("eventType").asText()

            when (eventType) {
                "CustomerCreated" -> {
                    val event = objectMapper.readValue<CustomerCreatedEvent>(eventJson)
                    handleCustomerCreated(event)
                }
                "CustomerCreditLimitChanged" -> {
                    val event = objectMapper.readValue<CustomerCreditLimitChangedEvent>(eventJson)
                    handleCreditLimitChanged(event)
                }
                // ... other events
            }
        } catch (e: Exception) {
            logger.error("Failed to process customer event", e)
            // Consider DLQ or retry logic
        }
    }

    private suspend fun handleCustomerCreated(event: CustomerCreatedEvent) {
        logger.info("Creating shopper profile for customer: ${event.customerId}")
        // Business logic here
    }
}
```

## Migration Checklist Per Service

### For Each Service Publishing Events:

-   [ ] Inject `EventPublisher` into service classes
-   [ ] Identify all event publishing points
-   [ ] Replace string-based events with domain events
-   [ ] Add metadata creation helper
-   [ ] Test event publishing
-   [ ] Verify events in Kafka topics
-   [ ] Keep test endpoints using SimpleEvent for now

### For Each Service Consuming Events:

-   [ ] Add Kafka topic configuration
-   [ ] Create event listener class
-   [ ] Add `@Incoming` annotation with topic
-   [ ] Deserialize JSON to domain event
-   [ ] Handle each event type
-   [ ] Add error handling and logging
-   [ ] Test event consumption
-   [ ] Monitor consumer lag

## Configuration Updates

### Add to application.properties

```properties
# Event Publishing (new)
mp.messaging.outgoing.domain-events-out.connector=smallrye-kafka
mp.messaging.outgoing.domain-events-out.value.serializer=org.apache.kafka.common.serialization.StringSerializer

# Event Consumption - Customer Events
mp.messaging.incoming.customer-events.connector=smallrye-kafka
mp.messaging.incoming.customer-events.topic=crm.customer.events
mp.messaging.incoming.customer-events.group.id=${service.name}-customer-consumer
mp.messaging.incoming.customer-events.value.deserializer=org.apache.kafka.common.serialization.StringDeserializer

# Event Consumption - Order Events
mp.messaging.incoming.order-events.connector=smallrye-kafka
mp.messaging.incoming.order-events.topic=commerce.order.events
mp.messaging.incoming.order-events.group.id=${service.name}-order-consumer
mp.messaging.incoming.order-events.value.deserializer=org.apache.kafka.common.serialization.StringDeserializer

# Add more as needed for other event types
```

## Common Migration Patterns

### Pattern 1: Simple Event → Customer Event

**Before:**

```kotlin
eventProducer.publishEvent(
    "CUSTOMER_CREATED",
    "Customer ${customer.name} created"
)
```

**After:**

```kotlin
eventPublisher.publish(
    CustomerCreatedEvent(
        aggregateId = customer.id,
        tenantId = customer.tenantId,
        metadata = createMetadata(userId),
        customerId = customer.id,
        // ... full customer data
    )
)
```

### Pattern 2: Simple Event → Order Event

**Before:**

```kotlin
eventProducer.publishEvent(
    "ORDER_PLACED",
    "Order ${order.number} for $${order.total}"
)
```

**After:**

```kotlin
eventPublisher.publish(
    OrderCreatedEvent(
        aggregateId = order.id,
        tenantId = order.tenantId,
        metadata = createMetadata(userId),
        orderId = order.id,
        orderNumber = order.number,
        customerId = order.customerId,
        items = order.items.map { it.toOrderLineItem() },
        totalAmount = order.total,
        // ... full order data
    )
)
```

### Pattern 3: Consuming Multiple Event Types

```kotlin
@ApplicationScoped
class OrderEventListener {

    @Incoming("commerce.order.events")
    suspend fun onOrderEvent(eventJson: String) {
        val eventType = extractEventType(eventJson)

        when (eventType) {
            "OrderCreated" -> handleOrderCreated(
                deserialize<OrderCreatedEvent>(eventJson)
            )
            "OrderConfirmed" -> handleOrderConfirmed(
                deserialize<OrderConfirmedEvent>(eventJson)
            )
            "OrderShipped" -> handleOrderShipped(
                deserialize<OrderShippedEvent>(eventJson)
            )
            else -> logger.warn("Unknown event type: $eventType")
        }
    }
}
```

## Testing Migration

### Unit Test Example

```kotlin
@Test
fun `should publish customer created event with correct data`() {
    // Arrange
    val command = CreateCustomerCommand(
        firstName = "John",
        lastName = "Doe",
        email = "john@example.com"
    )

    // Act
    val customer = service.createCustomer(command)

    // Assert
    argumentCaptor<DomainEvent>().apply {
        verify(eventPublisher).publish(capture())

        val event = firstValue as CustomerCreatedEvent
        assertEquals(customer.id, event.customerId)
        assertEquals("John", event.personalInfo.firstName)
        assertEquals(CustomerStatus.ACTIVE, event.status)
    }
}
```

### Integration Test Example

```kotlin
@QuarkusTest
class CustomerEventIntegrationTest {

    @Inject
    lateinit var customerService: CustomerService

    @Test
    fun `should publish and consume customer event`() {
        // Given
        val command = CreateCustomerCommand(...)

        // When
        customerService.createCustomer(command)

        // Then
        // Wait for async processing
        await().atMost(5, TimeUnit.SECONDS).until {
            // Verify event was consumed and processed
            shopperProfileRepository.findByCustomerId(customer.id) != null
        }
    }
}
```

## Troubleshooting

### Issue: Events Not Being Published

**Check:**

1. EventPublisher is injected correctly
2. Kafka is running
3. Topic exists (check with `kafka-topics --list`)
4. No serialization errors in logs

**Solution:**

```bash
# Check Kafka topics
docker exec -it chiro-erp-kafka kafka-topics --bootstrap-server localhost:9092 --list

# Watch for published events
docker exec -it chiro-erp-kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic crm.customer.events \
  --from-beginning
```

### Issue: Events Not Being Consumed

**Check:**

1. Consumer group ID is unique
2. Topic name matches configuration
3. Deserializer is correct
4. No exceptions in consumer

**Solution:**

```bash
# Check consumer groups
docker exec -it chiro-erp-kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --list

# Check consumer lag
docker exec -it chiro-erp-kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --group my-service-customer-consumer \
  --describe
```

### Issue: Deserialization Errors

**Check:**

1. JSON structure matches event class
2. All required fields are present
3. Field types match (UUID, Instant, etc.)
4. Jackson modules are registered

**Solution:**

```kotlin
// Add proper Jackson configuration
@ApplicationScoped
class JacksonConfig {
    @Produces
    fun objectMapper(): ObjectMapper {
        return jacksonObjectMapper().apply {
            registerModule(JavaTimeModule())
            disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS)
            // Handle unknown properties gracefully
            configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false)
        }
    }
}
```

## Rollback Plan

If issues arise during migration:

1. **Keep Old System Running** - SimpleEvent still works
2. **Disable New Consumers** - Comment out @Incoming methods
3. **Revert Publishers** - Switch back to old event format
4. **Fix Issues** - Debug in development
5. **Retry Migration** - Apply fixes and try again

## Service-by-Service Migration Order

Recommended order:

1. **Core Platform** - Already has event library
2. **Customer Relationship** - Publishes customer events
3. **Commerce** - Publishes order events, consumes customer events
4. **Financial Management** - Consumes order events, publishes invoice events
5. **Supply Chain** - Consumes order events, publishes inventory events
6. **Operations** - Publishes service order events
7. **Administration** - Consumes user events

## Success Criteria

Migration is successful when:

-   [ ] All services publish domain events
-   [ ] All services consume relevant events
-   [ ] No SimpleEvent publishing in production code
-   [ ] All tests pass
-   [ ] No consumer lag
-   [ ] Correlation IDs tracked across services
-   [ ] Monitoring shows healthy event flow
-   [ ] Documentation updated

## Resources

-   [Shared Event Library Guide](./SHARED-EVENT-LIBRARY-GUIDE.md)
-   [Event Library Quick Reference](./EVENT-LIBRARY-QUICK-REF.md)
-   [Event Library Architecture](./EVENT-LIBRARY-ARCHITECTURE.md)
-   [Kafka Messaging Guide](./KAFKA-MESSAGING-GUIDE.md)

---

**Need Help?** Check the logs, verify Kafka is running, and review the event structure in the guide.

**Last Updated:** November 3, 2025
