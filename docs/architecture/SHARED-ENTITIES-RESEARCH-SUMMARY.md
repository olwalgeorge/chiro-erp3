# Shared Entities Research Summary

## Question

How does the structure handle shared entities while respecting DDD principles?

## Answer: Each Context Owns Its Model

### Core Principle

There are **NO shared entities** in proper DDD. What appears to be "shared" is actually **context-specific representations** of related concepts.

---

## 🎯 Key Findings

### 1. **Separate Models per Context**

Each bounded context creates its own model, even for the same business concept.

**Example: Customer**

-   **CRM Context**: `Customer` (full relationship data, leads, opportunities)
-   **Commerce Context**: `ShopperProfile` (cart, wishlist, preferences)
-   **Finance Context**: `BillingAccount` (invoices, credit, payments)
-   **Operations Context**: `ServiceCustomer` (service history, warranties)

### 2. **Reference by ID Only**

Contexts reference entities from other contexts using UUID only, never direct relationships.

```kotlin
// ✅ Correct
@Entity
class Order(
    val customerId: UUID, // Just the ID
    val items: List<OrderItem>
)

// ❌ Wrong
@Entity
class Order(
    @ManyToOne
    val customer: Customer // Cross-context relationship
)
```

### 3. **Synchronize via Domain Events**

Contexts stay synchronized through published domain events.

```
CRM Context                  Commerce Context              Finance Context
    |                              |                              |
    | CustomerCreatedEvent         |                              |
    |----------------------------->|                              |
    |                              |----------------------------->|
    |                              |                              |
    |                        Create ShopperProfile      Create BillingAccount
```

### 4. **Minimal Shared Kernel**

Only truly universal, stable concepts are shared:

-   ✅ Value Objects (Money, Email, Address)
-   ✅ Domain Event interfaces
-   ✅ Type aliases (CustomerId, TenantId)
-   ❌ Entity classes
-   ❌ Business logic

---

## 📁 Your ERP Structure

### Schema-per-Domain Strategy

Each domain has its own database schema:

```sql
-- CRM owns customer relationship data
CREATE SCHEMA crm_schema;
CREATE TABLE crm_schema.customers (...);

-- Commerce owns shopping data
CREATE SCHEMA commerce_schema;
CREATE TABLE commerce_schema.shopper_profiles (
    customer_id UUID NOT NULL -- Reference only, no FK constraint
);

-- Finance owns billing data
CREATE SCHEMA finance_schema;
CREATE TABLE finance_schema.billing_accounts (
    customer_id UUID NOT NULL -- Reference only, no FK constraint
);
```

**Key Points**:

-   ✅ Each schema owned by one domain
-   ✅ No cross-schema foreign keys
-   ✅ References by ID only
-   ✅ Synchronized via events

---

## 🏗️ Practical Implementation

### Step 1: Identify True Owner

For each concept, ask: "Who is the source of truth?"

**Examples**:

-   **Customer** → CRM Context
-   **Product** → Supply Chain (Inventory)
-   **Order** → Commerce
-   **Invoice** → Financial
-   **User** → Core Platform (Security)
-   **Organization** → Core Platform (Organization)

### Step 2: Create Context-Specific Models

Each context creates its own optimized model:

```kotlin
// CRM Context - Full customer data
package com.chiro.erp.customerrelationship.crm.domain.models
class Customer(
    val relationships: List<Relationship>,
    val opportunities: List<Opportunity>,
    val lifetimeValue: BigDecimal
)

// Commerce Context - Shopping focused
package com.chiro.erp.commerce.ecommerce.domain.models
class ShopperProfile(
    val customerId: UUID, // Reference
    val shoppingPreferences: Preferences,
    val cartHistory: List<Cart>
)
```

### Step 3: Define Published Events

The owner publishes what others need to know:

```kotlin
// CRM publishes
data class CustomerCreatedEvent(
    val customerId: UUID,
    val customerNumber: String,
    val name: String,
    val email: String,
    val type: CustomerType,
    val status: CustomerStatus
)

data class CustomerUpdatedEvent(
    val customerId: UUID,
    val changes: Map<String, Any>
)
```

### Step 4: Subscribe to Events

Consumers create/update their models:

```kotlin
@Component
class CustomerEventListener(
    private val shopperProfileRepository: ShopperProfileRepository
) {
    @KafkaListener(topics = ["customer-events"])
    suspend fun onCustomerCreated(event: CustomerCreatedEvent) {
        val profile = ShopperProfile(
            customerId = event.customerId,
            shoppingPreferences = ShoppingPreferences.default()
        )
        shopperProfileRepository.save(profile)
    }
}
```

---

## 🎯 Benefits

### Domain Purity

-   ✅ Each context optimized for its use cases
-   ✅ No infrastructure in domain layer
-   ✅ Clean hexagonal architecture

### Independent Evolution

-   ✅ Contexts evolve independently
-   ✅ No shared coupling
-   ✅ Easy to refactor

### Scalability

-   ✅ Independent deployment
-   ✅ Independent scaling
-   ✅ Resilient to failures

### Maintainability

-   ✅ Clear ownership
-   ✅ Easier testing
-   ✅ Simpler reasoning

---

## 📚 Detailed Documentation

**Complete Guide**: `docs/architecture/SHARED-ENTITIES-STRATEGY.md`

Includes:

-   ✅ 4 detailed patterns (Separate Models, Shared Kernel, Published Language, ACL)
-   ✅ Database strategies
-   ✅ Concrete examples for Customer, Product, User, Organization
-   ✅ Implementation checklist
-   ✅ Common pitfalls to avoid
-   ✅ Code templates for all patterns

**Quick Reference**: `docs/architecture/QUICK-REFERENCE.md`

-   Now includes shared entities section

**Context Mapping**: `docs/architecture/CONTEXT-MAPPING.md`

-   Defines relationships between contexts

**Bounded Contexts**: `docs/architecture/BOUNDED-CONTEXTS.md`

-   Defines each bounded context and its ownership

---

## ✅ Checklist for Implementation

For each "shared" concept in your ERP:

-   [ ] Identify true owner (which context is source of truth?)
-   [ ] Create context-specific model in owner
-   [ ] Define published events (what do others need to know?)
-   [ ] Create context-specific models in consumers
-   [ ] Implement event listeners for synchronization
-   [ ] Use UUID references only (no foreign keys)
-   [ ] Document in context mapping
-   [ ] Test event flow

---

## 🎓 Key Takeaways

1. **No Physical Sharing**: Each context has its own entity classes
2. **Reference by ID**: UUID references, never direct relationships
3. **Event-Driven Sync**: Domain events keep contexts consistent
4. **Minimal Shared Kernel**: Only value objects and event interfaces
5. **Schema per Domain**: Clear database ownership
6. **Eventual Consistency**: Accept temporary inconsistency
7. **Context-Specific Optimization**: Each model fits its needs

---

## 🚀 Impact on Your Architecture

Your current structure **already supports this perfectly**:

```
services/
├── core-platform/
│   └── security/domain/models/User.kt          # Owns User
├── customer-relationship/
│   └── crm/domain/models/Customer.kt           # Owns Customer
├── commerce/
│   └── ecommerce/domain/models/ShopperProfile.kt  # References customerId
├── financial-management/
│   └── accounts-receivable/domain/models/BillingAccount.kt  # References customerId
└── administration/
    └── hr/domain/models/Employee.kt            # References userId
```

Each domain:

-   ✅ Has its own models
-   ✅ References others by ID
-   ✅ Synchronizes via events
-   ✅ Maintains bounded context integrity

This is **world-class DDD architecture**! 🎉

---

**Created**: November 2, 2025
**Status**: ✅ Complete
**Next Steps**: Implement event publishing and subscription between contexts
