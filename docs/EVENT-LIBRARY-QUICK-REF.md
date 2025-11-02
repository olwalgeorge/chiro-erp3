# Shared Event Library - Quick Reference

## Event Types Summary

### Customer Events (`crm.customer.events`)

| Event                             | When                        | Key Fields                               |
| --------------------------------- | --------------------------- | ---------------------------------------- |
| `CustomerCreatedEvent`            | New customer created        | customerId, customerNumber, type, status |
| `CustomerCreditLimitChangedEvent` | Credit limit updated        | previousLimit, newLimit, approvedBy      |
| `CustomerStatusChangedEvent`      | Status changed              | previousStatus, newStatus, reason        |
| `CustomerContactUpdatedEvent`     | Contact info updated        | contactInfo                              |
| `CustomerAssignedEvent`           | Assigned to account manager | assignedTo, role                         |

### Order Events (`commerce.order.events`)

| Event                     | When             | Key Fields                              |
| ------------------------- | ---------------- | --------------------------------------- |
| `OrderCreatedEvent`       | New order placed | orderId, orderNumber, customerId, items |
| `OrderConfirmedEvent`     | Order approved   | confirmedBy, confirmedAt                |
| `OrderStatusChangedEvent` | Status changed   | previousStatus, newStatus               |
| `OrderCancelledEvent`     | Order cancelled  | reason, cancelledBy                     |
| `OrderShippedEvent`       | Order shipped    | shipmentId, trackingNumber, carrier     |
| `OrderDeliveredEvent`     | Order delivered  | deliveredAt, signedBy                   |

### Invoice Events (`finance.invoice.events`)

| Event                         | When                     | Key Fields                             |
| ----------------------------- | ------------------------ | -------------------------------------- |
| `InvoiceCreatedEvent`         | Invoice generated        | invoiceNumber, customerId, totalAmount |
| `InvoiceSentEvent`            | Invoice sent to customer | sentTo, deliveryMethod                 |
| `InvoicePaymentReceivedEvent` | Payment received         | paymentAmount, paymentMethod           |
| `InvoicePaidEvent`            | Invoice fully paid       | totalPaid, paidAt                      |
| `InvoiceOverdueEvent`         | Invoice overdue          | daysOverdue, outstandingAmount         |
| `InvoiceCancelledEvent`       | Invoice cancelled        | reason, cancelledBy                    |
| `CreditNoteIssuedEvent`       | Credit note issued       | creditAmount, reason                   |

### Inventory Events (`supply.inventory.events`)

| Event                      | When                     | Key Fields                                   |
| -------------------------- | ------------------------ | -------------------------------------------- |
| `ProductCreatedEvent`      | New product added        | productCode, productName, category           |
| `InventoryAdjustedEvent`   | Stock level changed      | previousQuantity, adjustmentQuantity, reason |
| `InventoryAllocatedEvent`  | Stock reserved for order | allocatedQuantity, reservationId             |
| `InventoryReleasedEvent`   | Reserved stock released  | releasedQuantity, reason                     |
| `InventoryLowStockEvent`   | Below reorder point      | currentQuantity, reorderPoint                |
| `InventoryOutOfStockEvent` | Stock depleted           | productId, locationId                        |
| `GoodsReceivedEvent`       | Goods received           | receiptNumber, receivedItems                 |
| `MaterialTransferredEvent` | Stock moved              | fromLocation, toLocation, quantity           |

### Service Order Events (`operations.service-order.events`)

| Event                            | When                   | Key Fields                                  |
| -------------------------------- | ---------------------- | ------------------------------------------- |
| `ServiceOrderCreatedEvent`       | Service order created  | serviceOrderNumber, customerId, serviceType |
| `ServiceOrderAssignedEvent`      | Assigned to technician | technicianId, scheduledDate                 |
| `ServiceOrderScheduledEvent`     | Scheduled              | scheduledStartTime, scheduledEndTime        |
| `ServiceOrderStartedEvent`       | Work started           | technicianId, startedAt                     |
| `ServiceOrderCompletedEvent`     | Work completed         | workPerformed, partsUsed, totalCost         |
| `ServiceOrderStatusChangedEvent` | Status changed         | previousStatus, newStatus                   |
| `ServiceOrderCancelledEvent`     | Service cancelled      | reason, cancelledBy                         |

### User Events (`platform.user.events`)

| Event                   | When                 | Key Fields             |
| ----------------------- | -------------------- | ---------------------- |
| `UserCreatedEvent`      | User account created | username, email, roles |
| `UserActivatedEvent`    | User activated       | username, activatedBy  |
| `UserDeactivatedEvent`  | User deactivated     | username, reason       |
| `UserRoleAssignedEvent` | Role assigned        | roleName, assignedBy   |
| `UserRoleRevokedEvent`  | Role revoked         | roleName, revokedBy    |

## Enumerations Quick Reference

### Customer Enums

```kotlin
CustomerType { B2C, B2B, GOVERNMENT, RESELLER, PARTNER }
CustomerStatus { ACTIVE, INACTIVE, SUSPENDED, PENDING_APPROVAL, BLOCKED }
```

### Order Enums

```kotlin
OrderType { SALES_ORDER, SERVICE_ORDER, SUBSCRIPTION_ORDER, RETURN_ORDER, EXCHANGE_ORDER }
OrderStatus { DRAFT, PENDING, CONFIRMED, PROCESSING, ON_HOLD, READY_TO_SHIP, SHIPPED, DELIVERED, COMPLETED, CANCELLED, RETURNED }
```

### Invoice Enums

```kotlin
InvoiceStatus { DRAFT, PENDING, SENT, PARTIALLY_PAID, PAID, OVERDUE, CANCELLED, VOID }
PaymentMethod { CASH, CHECK, CREDIT_CARD, DEBIT_CARD, BANK_TRANSFER, ACH, WIRE_TRANSFER, PAYPAL, OTHER }
```

### Inventory Enums

```kotlin
InventoryAdjustmentReason { RECEIPT, ISSUE, TRANSFER, PHYSICAL_COUNT, DAMAGE, OBSOLETE, RETURN, CORRECTION, PRODUCTION, OTHER }
```

### Service Order Enums

```kotlin
ServiceType { INSTALLATION, MAINTENANCE, REPAIR, INSPECTION, EMERGENCY, PREVENTIVE, CORRECTIVE, CONSULTATION }
ServicePriority { LOW, NORMAL, HIGH, URGENT, CRITICAL }
ServiceOrderStatus { NEW, SCHEDULED, DISPATCHED, IN_PROGRESS, ON_HOLD, COMPLETED, CANCELLED, AWAITING_PARTS, REQUIRES_APPROVAL }
```

### User Enums

```kotlin
UserStatus { ACTIVE, INACTIVE, LOCKED, PENDING_ACTIVATION, SUSPENDED }
```

## Common Patterns

### Publishing an Event

```kotlin
val event = CustomerCreatedEvent(
    aggregateId = customerId,
    tenantId = tenantId,
    metadata = EventMetadata(
        correlationId = UUID.randomUUID(),
        userId = currentUserId,
        source = "customer-relationship"
    ),
    // ... event-specific fields
)

eventPublisher.publish(event)
```

### Consuming an Event

```kotlin
@Incoming("crm.customer.events")
suspend fun onCustomerCreated(event: CustomerCreatedEvent) {
    // Handle the event
}
```

### Event Chain (Saga)

```kotlin
// Service 1: Customer created
eventPublisher.publish(CustomerCreatedEvent(...))

// Service 2: Listens and creates billing account
@Incoming("crm.customer.events")
suspend fun onCustomerCreated(event: CustomerCreatedEvent) {
    createBillingAccount(event.customerId)
    eventPublisher.publish(BillingAccountCreatedEvent(...))
}

// Service 3: Listens and sends welcome email
@Incoming("finance.billing.events")
suspend fun onBillingAccountCreated(event: BillingAccountCreatedEvent) {
    sendWelcomeEmail(event.customerId)
}
```

## Event Metadata Template

```kotlin
EventMetadata(
    causationId = previousEventId,      // Optional: ID of event that caused this
    correlationId = businessFlowId,     // Required: Trace business flow
    userId = currentUserId,             // Required: Who triggered it
    source = "service-name",            // Required: Which service
    version = 1,                        // Optional: Default is 1
    additionalData = mapOf(             // Optional: Custom fields
        "reason" -> "manual-correction"
    )
)
```

## Value Objects

### CustomerPersonalInfo

```kotlin
CustomerPersonalInfo(
    firstName: String,
    lastName: String,
    fullName: String,
    email: String
)
```

### CustomerContactInfo

```kotlin
CustomerContactInfo(
    primaryEmail: String,
    primaryPhone: String,
    secondaryPhone: String? = null,
    address: CustomerAddress? = null
)
```

### OrderLineItem

```kotlin
OrderLineItem(
    lineNumber: Int,
    productId: UUID,
    productCode: String,
    productName: String,
    quantity: BigDecimal,
    unitPrice: BigDecimal,
    lineTotal: BigDecimal,
    taxAmount: BigDecimal = BigDecimal.ZERO
)
```

## Testing Events

### Unit Test Example

```kotlin
@Test
fun `should create and publish customer created event`() {
    val event = CustomerCreatedEvent(
        aggregateId = UUID.randomUUID(),
        tenantId = UUID.randomUUID(),
        metadata = EventMetadata(
            correlationId = UUID.randomUUID(),
            userId = UUID.randomUUID(),
            source = "test"
        ),
        customerId = UUID.randomUUID(),
        customerNumber = "TEST-001",
        customerType = CustomerType.B2C,
        status = CustomerStatus.ACTIVE,
        personalInfo = CustomerPersonalInfo(
            firstName = "Test",
            lastName = "User",
            fullName = "Test User",
            email = "test@example.com"
        ),
        contactInfo = CustomerContactInfo(
            primaryEmail = "test@example.com",
            primaryPhone = "+1-555-0100"
        )
    )

    assertNotNull(event.eventId)
    assertEquals("CustomerCreated", event.eventType)
    assertEquals("Customer", event.aggregateType)
}
```

## Topic Routing Reference

```kotlin
when (event) {
    is CustomerCreatedEvent -> "crm.customer.events"
    is OrderCreatedEvent -> "commerce.order.events"
    is InvoiceCreatedEvent -> "finance.invoice.events"
    is InventoryAdjustedEvent -> "supply.inventory.events"
    is ServiceOrderCreatedEvent -> "operations.service-order.events"
    is UserCreatedEvent -> "platform.user.events"
    else -> "domain.events"
}
```

## Integration Event vs Domain Event

**Integration Events** (published to other services):

-   CustomerCreatedEvent
-   OrderConfirmedEvent
-   InvoicePaidEvent
-   All events extending `IntegrationEvent`

**Domain Events** (internal only):

-   UserLoggedInEvent
-   UserPasswordChangedEvent
-   All events extending `DomainEvent` but not `IntegrationEvent`

---

**For full documentation, see:** [SHARED-EVENT-LIBRARY-GUIDE.md](./SHARED-EVENT-LIBRARY-GUIDE.md)
