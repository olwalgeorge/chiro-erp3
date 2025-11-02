# Shared Event Library - Architecture Diagram

## Event Library Structure

```
┌─────────────────────────────────────────────────────────────────┐
│                    SHARED EVENT LIBRARY                         │
│           (core-platform/shared/events)                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ BaseEvents   │    │ Event Files  │    │ EventPubl.   │
│              │    │              │    │              │
│ • DomainEvent│    │ • Customer   │    │ • Publisher  │
│ • Integration│    │ • Order      │    │ • Serializer │
│ • Metadata   │    │ • Invoice    │    │ • Router     │
│ • Base Class │    │ • Inventory  │    │ • Error Hdlr │
│              │    │ • Service    │    │              │
└──────────────┘    │ • User       │    └──────────────┘
                    └──────────────┘
```

## Event Type Hierarchy

```
DomainEvent (interface)
    │
    ├── IntegrationEvent (interface)
    │       │
    │       ├── CustomerCreatedEvent
    │       ├── CustomerCreditLimitChangedEvent
    │       ├── CustomerStatusChangedEvent
    │       ├── OrderCreatedEvent
    │       ├── OrderConfirmedEvent
    │       ├── InvoiceCreatedEvent
    │       ├── InvoicePaidEvent
    │       ├── InventoryAdjustedEvent
    │       ├── ServiceOrderCreatedEvent
    │       ├── UserCreatedEvent
    │       └── ... (25+ more)
    │
    └── Internal Events (non-integration)
            ├── UserLoggedInEvent
            └── UserPasswordChangedEvent
```

## Event Flow Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    APPLICATION LAYER                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │   Service    │  │   Service    │  │   Service    │         │
│  │   Logic      │  │   Logic      │  │   Logic      │         │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘         │
│         │                  │                  │                 │
└─────────┼──────────────────┼──────────────────┼─────────────────┘
          │                  │                  │
          ▼                  ▼                  ▼
    ┌────────────────────────────────────────────────┐
    │           EVENT PUBLISHER                      │
    │  ┌──────────────────────────────────────┐     │
    │  │  1. Serialize Event to JSON          │     │
    │  │  2. Determine Topic by Event Type    │     │
    │  │  3. Add Kafka Headers (metadata)     │     │
    │  │  4. Send to Kafka                    │     │
    │  └──────────────────────────────────────┘     │
    └────────────────────┬───────────────────────────┘
                         │
                         ▼
    ┌────────────────────────────────────────────────┐
    │              KAFKA TOPICS                      │
    │                                                │
    │  ┌──────────────────────────────────────┐     │
    │  │  crm.customer.events                 │     │
    │  │  commerce.order.events               │     │
    │  │  finance.invoice.events              │     │
    │  │  supply.inventory.events             │     │
    │  │  operations.service-order.events     │     │
    │  │  platform.user.events                │     │
    │  │  platform.internal.events            │     │
    │  └──────────────────────────────────────┘     │
    └────────────┬───────────────┬────────────┬──────┘
                 │               │            │
        ┌────────▼───┐  ┌───────▼────┐  ┌───▼────────┐
        │ Service 1  │  │ Service 2  │  │ Service 3  │
        │ Consumer   │  │ Consumer   │  │ Consumer   │
        └────────────┘  └────────────┘  └────────────┘
```

## Topic Routing Logic

```
Event Type                     →  Kafka Topic
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CustomerCreatedEvent          →  crm.customer.events
CustomerCreditLimitChanged    →  crm.customer.events
CustomerStatusChanged         →  crm.customer.events
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OrderCreatedEvent             →  commerce.order.events
OrderConfirmedEvent           →  commerce.order.events
OrderShippedEvent             →  commerce.order.events
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
InvoiceCreatedEvent           →  finance.invoice.events
InvoicePaymentReceivedEvent   →  finance.invoice.events
InvoicePaidEvent              →  finance.invoice.events
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
InventoryAdjustedEvent        →  supply.inventory.events
InventoryLowStockEvent        →  supply.inventory.events
GoodsReceivedEvent            →  supply.inventory.events
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ServiceOrderCreatedEvent      →  operations.service-order.events
ServiceOrderCompletedEvent    →  operations.service-order.events
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
UserCreatedEvent              →  platform.user.events
UserRoleAssignedEvent         →  platform.user.events
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
UserLoggedInEvent             →  platform.internal.events
UserPasswordChangedEvent      →  platform.internal.events
```

## Event Metadata Flow

```
┌────────────────────────────────────────────────────┐
│              EVENT METADATA                        │
├────────────────────────────────────────────────────┤
│ eventId         : UUID (unique per event)          │
│ aggregateId     : UUID (entity ID)                 │
│ aggregateType   : String (e.g., "Customer")        │
│ eventType       : String (e.g., "CustomerCreated") │
│ occurredAt      : Instant (timestamp)              │
│ tenantId        : UUID (multi-tenancy)             │
│                                                    │
│ metadata:                                          │
│   ├─ causationId    : UUID? (parent event)        │
│   ├─ correlationId  : UUID (business flow)        │
│   ├─ userId         : UUID (who triggered)        │
│   ├─ source         : String (service name)       │
│   ├─ version        : Int (schema version)        │
│   └─ additionalData : Map<String, String>         │
└────────────────────────────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────────────────┐
│           KAFKA MESSAGE HEADERS                    │
├────────────────────────────────────────────────────┤
│ event-type      : CustomerCreated                  │
│ aggregate-type  : Customer                         │
│ aggregate-id    : 123e4567-e89b...                │
│ tenant-id       : 456e4567-e89b...                │
│ correlation-id  : cor-123                          │
│ causation-id    : evt-456 (optional)              │
│ source          : customer-relationship            │
│ version         : 1                                │
└────────────────────────────────────────────────────┘
```

## Cross-Service Event Example: Order Processing

```
┌─────────────────────────────────────────────────────────────────┐
│                  END-TO-END ORDER WORKFLOW                      │
└─────────────────────────────────────────────────────────────────┘

Step 1: Customer places order
┌──────────────────┐
│ Commerce Service │  OrderCreatedEvent
│                  │  ───────────────────→ commerce.order.events
└──────────────────┘

Step 2: Multiple services react
                    ┌─────────────────────┐
                    │  Inventory Service  │ InventoryAllocatedEvent
                    │                     │ ───────→ supply.inventory.events
                    └─────────────────────┘

                    ┌─────────────────────┐
                    │  Financial Service  │ InvoiceCreatedEvent
                    │                     │ ───────→ finance.invoice.events
                    └─────────────────────┘

                    ┌─────────────────────┐
                    │  Notification Svc   │ Email sent
                    └─────────────────────┘

Step 3: Inventory confirmed
┌──────────────────┐
│ Inventory Svc    │  InventoryAllocatedEvent (published)
└──────────────────┘
         │
         ▼
┌──────────────────┐
│ Commerce Service │  Listens and confirms order
│                  │  OrderConfirmedEvent
│                  │  ───────────────────→ commerce.order.events
└──────────────────┘

Step 4: Shipment
┌──────────────────┐
│ Operations Svc   │  OrderShippedEvent
│                  │  ───────────────────→ commerce.order.events
└──────────────────┘
         │
         ▼
┌──────────────────┐
│ Notification Svc │  Shipping notification sent
└──────────────────┘
```

## Event Structure Comparison

### Old (Simple) Event

```json
{
    "eventId": "abc-123",
    "eventType": "TEST_EVENT",
    "serviceName": "commerce",
    "timestamp": "2025-11-03T10:00:00Z",
    "payload": "Simple string message"
}
```

### New (Domain) Event

```json
{
  "eventId": "123e4567-e89b-12d3-a456-426614174000",
  "aggregateId": "789e4567-e89b-12d3-a456-426614174000",
  "aggregateType": "Order",
  "eventType": "OrderCreated",
  "occurredAt": "2025-11-03T10:00:00Z",
  "tenantId": "456e4567-e89b-12d3-a456-426614174000",
  "metadata": {
    "correlationId": "cor-123",
    "userId": "usr-456",
    "source": "commerce",
    "version": 1
  },
  "orderId": "789e4567-e89b-12d3-a456-426614174000",
  "orderNumber": "ORD-001",
  "customerId": "cust-123",
  "orderDate": "2025-11-03T10:00:00Z",
  "orderType": "SALES_ORDER",
  "totalAmount": 999.90,
  "currency": "USD",
  "status": "PENDING",
  "items": [...]
}
```

## Event Library Dependencies

```
┌─────────────────────────────────────────────────────┐
│             EVENT LIBRARY DEPENDENCIES              │
└─────────────────────────────────────────────────────┘

Kotlin Libraries:
  ├─ kotlin-stdlib
  └─ kotlin-reflect

Jakarta EE:
  ├─ jakarta.enterprise.cdi-api (for @ApplicationScoped)
  └─ jakarta.inject-api (for @Inject)

Quarkus:
  ├─ quarkus-messaging-kafka (for @Incoming, @Channel)
  ├─ quarkus-rest-jackson (for JSON)
  └─ quarkus-logging (for Logger)

Apache Kafka:
  └─ kafka-clients (for RecordHeaders, etc.)

Jackson:
  ├─ jackson-databind
  ├─ jackson-datatype-jsr310 (for Java Time)
  └─ jackson-module-kotlin (for Kotlin data classes)
```

## Integration Points

```
┌─────────────────────────────────────────────────────┐
│              SERVICES INTEGRATION                   │
└─────────────────────────────────────────────────────┘

Each Service Needs:
  1. Import shared events from core-platform
  2. Inject EventPublisher
  3. Configure Kafka channels
  4. Create event consumers (@Incoming)
  5. Publish events from domain logic

Example Service Structure:
  service/
    ├─ domain/
    │    ├─ Customer.kt (aggregate)
    │    └─ CustomerService.kt (publishes events)
    ├─ application/
    │    └─ CustomerEventListener.kt (consumes events)
    └─ infrastructure/
         └─ CustomerRepository.kt
```

## Monitoring & Observability

```
┌─────────────────────────────────────────────────────┐
│           EVENT MONITORING POINTS                   │
└─────────────────────────────────────────────────────┘

Publishing Metrics:
  ├─ Events published per second
  ├─ Publishing failures
  ├─ Publishing latency
  └─ Events per topic

Consumption Metrics:
  ├─ Consumer lag
  ├─ Processing time
  ├─ Processing failures
  └─ Retry attempts

Tracing:
  ├─ Correlation ID tracking
  ├─ Event causation chains
  ├─ End-to-end flow visualization
  └─ Service dependency mapping
```

---

**For implementation details, see:**

-   [SHARED-EVENT-LIBRARY-GUIDE.md](./SHARED-EVENT-LIBRARY-GUIDE.md)
-   [EVENT-LIBRARY-QUICK-REF.md](./EVENT-LIBRARY-QUICK-REF.md)
