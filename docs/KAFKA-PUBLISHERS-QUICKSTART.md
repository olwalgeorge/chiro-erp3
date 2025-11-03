# Kafka Event Publishers - Developer Quick Start

## 🚀 Quick Start (5 Minutes)

### 1. Start Infrastructure

```powershell
# Start Kafka
docker-compose up -d kafka zookeeper

# Create topic
docker exec -it chiro-kafka kafka-topics.sh --create --bootstrap-server localhost:9092 --topic crm.customer.events --partitions 3 --replication-factor 1
```

### 2. Build & Run Service

```powershell
# Build
cd services\customer-relationship
..\..\gradlew.bat clean build -x test

# Run
..\..\gradlew.bat quarkusDev
```

### 3. Monitor Kafka Events

```powershell
# Open new terminal
docker exec -it chiro-kafka kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic crm.customer.events --from-beginning
```

### 4. Create Customer (Publish Event)

```powershell
curl -X POST http://localhost:8083/api/crm/customers -H "Content-Type: application/json" -d '{
  "firstName": "John",
  "lastName": "Doe",
  "email": "john@example.com",
  "phone": "555-1234",
  "customerType": "RETAIL",
  "tenantId": "tenant-001"
}'
```

### 5. Verify Event Published

Check the Kafka consumer terminal - you should see the CustomerCreatedEvent JSON!

---

## 📋 Implementation Pattern

### Step 1: Define Your Event (Already Done!)

Events are in `services/core-platform/src/main/kotlin/.../shared/events/`

```kotlin
// Example: CustomerCreatedEvent
data class CustomerCreatedEvent(
    override val eventId: String,
    override val aggregateId: String,
    override val occurredAt: Instant,
    override val tenantId: String?,
    override val metadata: EventMetadata,
    val customerId: String,
    val customerNumber: String,
    // ... other fields
) : IntegrationEvent
```

### Step 2: Configure Kafka Channels

In your service's `application.properties`:

```properties
# Publishing channel
mp.messaging.outgoing.crm-customer-events.connector=smallrye-kafka
mp.messaging.outgoing.crm-customer-events.topic=crm.customer.events
mp.messaging.outgoing.crm-customer-events.value.serializer=org.apache.kafka.common.serialization.StringSerializer
```

### Step 3: Inject EventPublisher

```kotlin
@ApplicationScoped
class YourService @Inject constructor(
    private val eventPublisher: EventPublisher
) {
    // Your methods here
}
```

### Step 4: Publish Events

```kotlin
fun createCustomer(command: CreateCustomerCommand): Customer {
    // 1. Create domain object
    val customer = Customer(/* ... */)

    // 2. Create event
    val event = CustomerCreatedEvent(
        eventId = UUID.randomUUID().toString(),
        aggregateId = customer.id,
        occurredAt = Instant.now(),
        tenantId = customer.tenantId,
        metadata = EventMetadata(
            correlationId = UUID.randomUUID().toString(),
            userId = "system",
            source = "customer-relationship"
        ),
        customerId = customer.id,
        // ... other fields
    )

    // 3. Publish to Kafka
    eventPublisher.publish(event)

    // 4. Return result
    return customer
}
```

---

## 🗺️ Kafka Topics Map

| Event Type           | Topic                             | Service               |
| -------------------- | --------------------------------- | --------------------- |
| Customer Events      | `crm.customer.events`             | customer-relationship |
| Order Events         | `commerce.order.events`           | commerce-management   |
| Invoice Events       | `finance.invoice.events`          | financial-management  |
| Inventory Events     | `supply.inventory.events`         | supply-chain          |
| Service Order Events | `operations.service-order.events` | operations-management |
| User Events          | `platform.user.events`            | user-management       |
| Internal Events      | `platform.internal.events`        | core-platform         |

---

## 🔍 Useful Commands

### Kafka Topic Management

```powershell
# List all topics
docker exec -it chiro-kafka kafka-topics.sh --list --bootstrap-server localhost:9092

# Describe topic
docker exec -it chiro-kafka kafka-topics.sh --describe --bootstrap-server localhost:9092 --topic crm.customer.events

# Delete topic (careful!)
docker exec -it chiro-kafka kafka-topics.sh --delete --bootstrap-server localhost:9092 --topic crm.customer.events
```

### Kafka Consumer

```powershell
# Consume from beginning
docker exec -it chiro-kafka kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic crm.customer.events --from-beginning

# Consume latest only
docker exec -it chiro-kafka kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic crm.customer.events

# With timestamp
docker exec -it chiro-kafka kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic crm.customer.events --from-beginning --property print.timestamp=true
```

### Service Health

```powershell
# Health check
curl http://localhost:8083/q/health

# Metrics
curl http://localhost:8083/q/metrics
```

---

## 📚 Available Events

### Customer Events (5)

-   `CustomerCreatedEvent`
-   `CustomerCreditLimitChangedEvent`
-   `CustomerStatusChangedEvent`
-   `CustomerContactUpdatedEvent`
-   `CustomerAssignedEvent`

### Order Events (6)

-   `OrderCreatedEvent`
-   `OrderLineItemAddedEvent`
-   `OrderStatusChangedEvent`
-   `OrderShippedEvent`
-   `OrderCancelledEvent`
-   `OrderPaymentReceivedEvent`

### Invoice Events (7)

-   `InvoiceGeneratedEvent`
-   `InvoiceLineItemAddedEvent`
-   `InvoiceSentToCustomerEvent`
-   `InvoicePaymentReceivedEvent`
-   `InvoicePartialPaymentReceivedEvent`
-   `InvoiceCancelledEvent`
-   `InvoiceOverdueEvent`

### Inventory Events (8)

-   `InventoryItemCreatedEvent`
-   `InventoryStockAdjustedEvent`
-   `InventoryStockReservedEvent`
-   `InventoryStockReleasedEvent`
-   `InventoryStockTransferredEvent`
-   `InventoryReorderPointReachedEvent`
-   `InventoryItemDiscontinuedEvent`
-   `InventoryCountCompletedEvent`

### Service Order Events (7)

-   `ServiceOrderCreatedEvent`
-   `ServiceOrderScheduledEvent`
-   `ServiceOrderStartedEvent`
-   `ServiceOrderCompletedEvent`
-   `ServiceOrderCancelledEvent`
-   `ServiceOrderTechnicianAssignedEvent`
-   `ServiceOrderPartUsedEvent`

### User Events (8)

-   `UserRegisteredEvent`
-   `UserProfileUpdatedEvent`
-   `UserPasswordChangedEvent`
-   `UserEmailVerifiedEvent`
-   `UserRoleAssignedEvent`
-   `UserRoleRevokedEvent`
-   `UserActivatedEvent`
-   `UserDeactivatedEvent`

---

## ⚠️ Common Issues

### Issue: Service won't start

**Error:** `UnsatisfiedResolutionException: Unsatisfied dependency for type Emitter<String>`
**Fix:** Add channel configuration to `application.properties`

### Issue: Events not appearing in Kafka

**Check:**

1. Is Kafka running? `docker ps | Select-String kafka`
2. Does topic exist? `docker exec -it chiro-kafka kafka-topics.sh --list --bootstrap-server localhost:9092`
3. Check service logs for "Published event"
4. Verify channel configuration in `application.properties`

### Issue: JSON serialization error

**Error:** `InvalidDefinitionException: Java 8 date/time type not supported`
**Fix:** Already configured in EventPublisher (JavaTimeModule)

---

## 📖 Documentation

-   **Full Details:** `docs/KAFKA-PUBLISHERS-VERIFICATION.md`
-   **Implementation Summary:** `docs/KAFKA-PUBLISHERS-IMPLEMENTATION-SUMMARY.md`
-   **Event Catalog:** `docs/EVENT-LIBRARY-INDEX.md`
-   **Architecture:** `docs/EVENT-LIBRARY-ARCHITECTURE.md`
-   **Kafka Guide:** `docs/KAFKA-MESSAGING-GUIDE.md`

---

## ✅ Checklist for New Events

When implementing a new event publisher:

-   [ ] Event already defined in shared library? (Check `EVENT-LIBRARY-INDEX.md`)
-   [ ] Kafka channel configured in `application.properties`?
-   [ ] EventPublisher injected in your service?
-   [ ] Event metadata populated (correlationId, userId, source)?
-   [ ] Kafka topic created in infrastructure?
-   [ ] Tested with kafka-console-consumer?
-   [ ] Logged "Published event" message appears?
-   [ ] REST endpoint returns success?

---

**Status:** ✅ Ready to use
**Last Updated:** 2024-01-15
**Version:** 1.0
