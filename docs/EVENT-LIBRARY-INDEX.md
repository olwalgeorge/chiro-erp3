# Shared Event Library - Complete Documentation Index

## 📚 Documentation Overview

This is the complete index of documentation for the ChiroERP Shared Event Library, an enterprise-grade event-driven messaging system built on Domain-Driven Design principles.

---

## 🎯 Quick Start

**New to the Event Library?** Start here:

1. Read: [Shared Event Library Summary](./SHARED-EVENT-LIBRARY-SUMMARY.md) (5 min)
2. Review: [Event Library Quick Reference](./EVENT-LIBRARY-QUICK-REF.md) (10 min)
3. Study: [Shared Event Library Guide](./SHARED-EVENT-LIBRARY-GUIDE.md) (30 min)
4. Implement: Follow examples in the guide

**Migrating from old events?** → [Migration Guide](./EVENT-LIBRARY-MIGRATION-GUIDE.md)

---

## 📖 Core Documentation

### 1. [Shared Event Library Summary](./SHARED-EVENT-LIBRARY-SUMMARY.md)

**Purpose:** High-level overview and implementation summary

**Contents:**

-   What was implemented
-   File structure
-   Event statistics
-   Key features
-   Next steps
-   Success criteria

**When to use:** Getting started, understanding scope, project overview

---

### 2. [Shared Event Library Guide](./SHARED-EVENT-LIBRARY-GUIDE.md)

**Purpose:** Complete usage guide and best practices

**Contents:**

-   Architecture overview
-   Event types and hierarchy
-   How to publish events
-   How to consume events
-   Event serialization
-   Versioning strategies
-   Best practices
-   Testing approaches
-   Configuration
-   Monitoring

**When to use:** Implementing events, learning patterns, troubleshooting

---

### 3. [Event Library Quick Reference](./EVENT-LIBRARY-QUICK-REF.md)

**Purpose:** Fast lookup for event types and usage

**Contents:**

-   Event type tables (all 35+ events)
-   Enumeration reference
-   Common patterns
-   Value objects
-   Code snippets
-   Testing examples

**When to use:** Quick lookup, code examples, event selection

---

### 4. [Event Library Architecture](./EVENT-LIBRARY-ARCHITECTURE.md)

**Purpose:** Visual architecture and diagrams

**Contents:**

-   Architecture diagrams
-   Event hierarchy
-   Event flow diagrams
-   Topic routing logic
-   Cross-service examples
-   Monitoring points

**When to use:** Understanding architecture, presentations, design reviews

---

### 5. [Migration Guide](./EVENT-LIBRARY-MIGRATION-GUIDE.md)

**Purpose:** Step-by-step migration from old events

**Contents:**

-   Migration strategy
-   Before/after examples
-   Step-by-step instructions
-   Configuration updates
-   Testing migration
-   Troubleshooting
-   Rollback plan

**When to use:** Migrating existing code, planning updates

---

## 🗂️ Event Type Reference

### Customer Events

| Document            | Events                                                                                                                                |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `CustomerEvents.kt` | CustomerCreatedEvent, CustomerCreditLimitChangedEvent, CustomerStatusChangedEvent, CustomerContactUpdatedEvent, CustomerAssignedEvent |
| **Topic:**          | `crm.customer.events`                                                                                                                 |
| **Service:**        | Customer Relationship Management                                                                                                      |

### Order Events

| Document         | Events                                                                                                                       |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `OrderEvents.kt` | OrderCreatedEvent, OrderConfirmedEvent, OrderStatusChangedEvent, OrderCancelledEvent, OrderShippedEvent, OrderDeliveredEvent |
| **Topic:**       | `commerce.order.events`                                                                                                      |
| **Service:**     | Commerce / E-commerce                                                                                                        |

### Invoice Events

| Document           | Events                                                                                                                                                  |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `InvoiceEvents.kt` | InvoiceCreatedEvent, InvoiceSentEvent, InvoicePaymentReceivedEvent, InvoicePaidEvent, InvoiceOverdueEvent, InvoiceCancelledEvent, CreditNoteIssuedEvent |
| **Topic:**         | `finance.invoice.events`                                                                                                                                |
| **Service:**       | Financial Management                                                                                                                                    |

### Inventory Events

| Document             | Events                                                                                                                                                                                       |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `InventoryEvents.kt` | ProductCreatedEvent, InventoryAdjustedEvent, InventoryAllocatedEvent, InventoryReleasedEvent, InventoryLowStockEvent, InventoryOutOfStockEvent, GoodsReceivedEvent, MaterialTransferredEvent |
| **Topic:**           | `supply.inventory.events`                                                                                                                                                                    |
| **Service:**         | Supply Chain Management                                                                                                                                                                      |

### Service Order Events

| Document                | Events                                                                                                                                                                                            |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ServiceOrderEvents.kt` | ServiceOrderCreatedEvent, ServiceOrderAssignedEvent, ServiceOrderScheduledEvent, ServiceOrderStartedEvent, ServiceOrderCompletedEvent, ServiceOrderStatusChangedEvent, ServiceOrderCancelledEvent |
| **Topic:**              | `operations.service-order.events`                                                                                                                                                                 |
| **Service:**            | Operations / Field Service                                                                                                                                                                        |

### User Events

| Document        | Events                                                                                                                                                                 |
| --------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `UserEvents.kt` | UserCreatedEvent, UserUpdatedEvent, UserActivatedEvent, UserDeactivatedEvent, UserRoleAssignedEvent, UserRoleRevokedEvent, UserLoggedInEvent, UserPasswordChangedEvent |
| **Topic:**      | `platform.user.events` (public), `platform.internal.events` (internal)                                                                                                 |
| **Service:**    | Core Platform                                                                                                                                                          |

---

## 🏗️ Source Code Reference

### Core Event Library Files

```
services/core-platform/src/main/kotlin/com/chiro/erp/coreplatform/shared/events/
├── BaseEvents.kt           - Core interfaces (DomainEvent, IntegrationEvent, EventMetadata)
├── CustomerEvents.kt       - Customer lifecycle events
├── OrderEvents.kt          - Order and commerce events
├── InvoiceEvents.kt        - Invoice and payment events
├── InventoryEvents.kt      - Inventory and material events
├── ServiceOrderEvents.kt   - Service order events
├── UserEvents.kt           - User and identity events
├── EventPublisher.kt       - Publishing utility with routing
└── DomainEvent.kt         - Legacy (deprecated SimpleEvent)
```

---

## 🎓 Learning Path

### For Developers New to Event-Driven Architecture

1. **Day 1: Learn Basics**

    - Read: Shared Event Library Summary
    - Read: What are Domain Events?
    - Review: Event architecture diagram

2. **Day 2: Understand Events**

    - Read: Shared Event Library Guide (focus on "Event Examples")
    - Review: All event types in Quick Reference
    - Study: Event metadata structure

3. **Day 3: Implement Publishing**

    - Follow: "Using the Event Publisher" in Guide
    - Code: Create simple event publisher
    - Test: Publish event and verify in Kafka

4. **Day 4: Implement Consuming**

    - Follow: "Consuming Events" in Guide
    - Code: Create event listener
    - Test: End-to-end event flow

5. **Day 5: Best Practices**
    - Read: Best practices section
    - Review: Error handling patterns
    - Study: Testing approaches

### For Developers Migrating Existing Code

1. Read: Migration Guide (complete)
2. Review: Your current event publishing code
3. Plan: Migration strategy for your service
4. Implement: One event type at a time
5. Test: Parallel running (old + new)
6. Switch: Move to new events exclusively
7. Cleanup: Remove old code

---

## 🔍 Common Use Cases

### "I need to publish a customer event"

→ [Customer Events Reference](./EVENT-LIBRARY-QUICK-REF.md#customer-events)
→ [Publishing Example](./SHARED-EVENT-LIBRARY-GUIDE.md#publishing-single-events)

### "I need to consume order events"

→ [Order Events Reference](./EVENT-LIBRARY-QUICK-REF.md#order-events)
→ [Consuming Example](./SHARED-EVENT-LIBRARY-GUIDE.md#consuming-events)

### "I need to trace events across services"

→ [Event Metadata Guide](./SHARED-EVENT-LIBRARY-GUIDE.md#eventmetadata)
→ [Correlation Tracking](./SHARED-EVENT-LIBRARY-GUIDE.md#event-tracing)

### "I need to version my events"

→ [Event Versioning](./SHARED-EVENT-LIBRARY-GUIDE.md#event-versioning)

### "I need to test event publishing"

→ [Testing Section](./SHARED-EVENT-LIBRARY-GUIDE.md#testing)

### "My events aren't being consumed"

→ [Troubleshooting](./EVENT-LIBRARY-MIGRATION-GUIDE.md#troubleshooting)

---

## 📊 Event Statistics

| Metric             | Count |
| ------------------ | ----- |
| Total Event Types  | 35+   |
| Integration Events | 33    |
| Internal Events    | 2     |
| Event Categories   | 6     |
| Kafka Topics       | 7     |
| Value Objects      | 15+   |
| Enumerations       | 11    |

---

## 🔗 Related Documentation

### Kafka Infrastructure

-   [Kafka Messaging Guide](./KAFKA-MESSAGING-GUIDE.md)
-   [Kafka Implementation Summary](./KAFKA-IMPLEMENTATION-SUMMARY.md)
-   [Kafka Testing Guide](./KAFKA-TESTING-GUIDE.md)

### Architecture

-   [DDD Implementation Plan](./DDD-IMPLEMENTATION-PLAN.md)
-   [Shared Entities Strategy](./architecture/SHARED-ENTITIES-STRATEGY.md)
-   [Hexagonal Architecture Guide](./architecture/HEXAGONAL-ARCHITECTURE-VISUAL-GUIDE.md)

### Testing

-   [Testing Guide](./TESTING-GUIDE.md)
-   [Kafka REST Tests](./KAFKA-REST-TESTS-GUIDE.md)

---

## 💻 Code Examples Repository

All documentation includes inline code examples. For complete working examples:

1. **Publishing Events:** See `SHARED-EVENT-LIBRARY-GUIDE.md` → "Using the Event Publisher"
2. **Consuming Events:** See `SHARED-EVENT-LIBRARY-GUIDE.md` → "Consuming Events"
3. **Testing Events:** See `EVENT-LIBRARY-QUICK-REF.md` → "Testing Events"
4. **Migration Examples:** See `EVENT-LIBRARY-MIGRATION-GUIDE.md` → "Common Patterns"

---

## 🎯 Decision Trees

### Which Event Type Should I Use?

```
What domain does this event belong to?
├─ Customer operations → CustomerEvents.kt
├─ Order/Sales → OrderEvents.kt
├─ Invoice/Payment → InvoiceEvents.kt
├─ Inventory/Stock → InventoryEvents.kt
├─ Field Service → ServiceOrderEvents.kt
└─ User/Identity → UserEvents.kt
```

### Should This Be an Integration Event?

```
Does another service need to know about this?
├─ YES → extends IntegrationEvent
│   Examples: CustomerCreatedEvent, OrderConfirmedEvent
└─ NO → extends DomainEvent only
    Examples: UserLoggedInEvent, UserPasswordChangedEvent
```

---

## 🛠️ Tools and Utilities

### EventPublisher

**File:** `EventPublisher.kt`
**Purpose:** Centralized event publishing with automatic routing
**Usage:** Inject into services, call `publish(event)`

### Event Metadata Helper

**Pattern:** Create helper method in your service

```kotlin
private fun createMetadata(userId: UUID): EventMetadata {
    return EventMetadata(
        correlationId = UUID.randomUUID(),
        userId = userId,
        source = "service-name"
    )
}
```

---

## 📞 Support and Troubleshooting

### Common Issues

1. **Events not publishing** → Check EventPublisher injection, Kafka connectivity
2. **Events not consuming** → Check topic configuration, consumer group
3. **Deserialization errors** → Check JSON format, Jackson configuration
4. **Wrong topic** → Check event type in EventPublisher routing logic

### Debug Commands

```bash
# List topics
docker exec -it chiro-erp-kafka kafka-topics --bootstrap-server localhost:9092 --list

# Watch events
docker exec -it chiro-erp-kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 --topic crm.customer.events --from-beginning

# Check consumer groups
docker exec -it chiro-erp-kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 --list
```

---

## 🎉 Quick Wins

### Get Started in 5 Minutes

1. Inject `EventPublisher` into your service
2. Create an event: `val event = CustomerCreatedEvent(...)`
3. Publish it: `eventPublisher.publish(event)`
4. Check Kafka: Events appear in topic!

### First Integration in 15 Minutes

1. Publish event from Service A
2. Add `@Incoming` listener in Service B
3. Deserialize and handle event
4. Test end-to-end flow
5. You have cross-service communication!

---

## 📈 Maturity Levels

### Level 1: Basic (Current State)

-   [x] Event library created
-   [x] Event types defined
-   [x] EventPublisher utility
-   [ ] Services publishing events
-   [ ] Services consuming events

### Level 2: Integrated

-   [ ] All services publish domain events
-   [ ] All services consume relevant events
-   [ ] Legacy SimpleEvent deprecated
-   [ ] Monitoring in place

### Level 3: Advanced

-   [ ] Event sourcing implemented
-   [ ] Saga patterns in use
-   [ ] Complete tracing
-   [ ] Automated replay

---

## 📅 Version History

| Version | Date       | Changes                              |
| ------- | ---------- | ------------------------------------ |
| 1.0     | 2025-11-03 | Initial event library implementation |
|         |            | - 35+ event types                    |
|         |            | - 6 event categories                 |
|         |            | - EventPublisher utility             |
|         |            | - Comprehensive documentation        |

---

## 📝 Document Maintenance

### Update Frequency

-   **Event types:** Add as new domains emerge
-   **Documentation:** Update with lessons learned
-   **Examples:** Refresh with real-world use cases
-   **Best practices:** Evolve based on team experience

### Documentation Owner

-   Core Platform team maintains event library code
-   Each service team maintains their event publishing/consuming code
-   Architecture team maintains overall patterns and guidelines

---

**Last Updated:** November 3, 2025

**Ready to start?** → Begin with [Shared Event Library Summary](./SHARED-EVENT-LIBRARY-SUMMARY.md)
