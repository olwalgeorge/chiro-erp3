# Shared Entities Strategy in DDD Hexagonal Architecture

## Executive Summary

This document outlines the **best practices for handling shared entities** in a Domain-Driven Design (DDD) architecture while respecting bounded context boundaries and maintaining domain purity.

**Key Principle**: Each bounded context owns its own data model. What appears to be "shared" is actually **context-specific representations** of related concepts.

---

## 🎯 Core DDD Principles for Shared Entities

### 1. **No Physical Sharing of Domain Models**

❌ **Anti-Pattern**: Sharing entity classes across bounded contexts

```kotlin
// ❌ WRONG: Shared entity class
// shared-kernel/Customer.kt
@Entity
class Customer { /* shared by CRM and Commerce */ }
```

✅ **Correct Pattern**: Each context owns its model

```kotlin
// ✅ CRM Context owns its Customer model
package com.chiro.erp.customerrelationship.crm.domain.models
@Entity
@Table(schema = "crm_schema")
class Customer(
    val id: CustomerId,
    val personalInfo: PersonalInfo,
    val creditInfo: CreditInfo,
    val relationships: List<Relationship>
)

// ✅ Commerce Context has its own model
package com.chiro.erp.commerce.ecommerce.domain.models
@Entity
@Table(schema = "commerce_schema")
class ShopperProfile(
    val customerId: CustomerId, // Reference only
    val shoppingPreferences: ShoppingPreferences,
    val cartHistory: List<Cart>,
    val wishlist: List<Product>
)
```

### 2. **Use References, Not Direct Relationships**

Each context references entities from other contexts by **ID only**, never by direct foreign key relationships.

```kotlin
// ✅ Reference by ID
@Entity
class Order(
    val id: OrderId,
    val customerId: CustomerId, // Just the ID, not @ManyToOne
    val items: List<OrderItem>
)

// ❌ Wrong: Direct relationship across contexts
@Entity
class Order(
    @ManyToOne
    @JoinColumn(name = "customer_id")
    val customer: Customer // ❌ Cross-context relationship
)
```

---

## 🏗️ Patterns for Handling Shared Concepts

### Pattern 1: Separate Models per Context

**When to Use**: Different contexts need different representations of the same concept.

**Example**: Customer entity

```kotlin
// 1️⃣ CRM Context - Full customer relationship data
package com.chiro.erp.customerrelationship.crm.domain.models

@Entity
@Table(name = "customers", schema = "crm_schema")
class Customer(
    @Id val id: UUID,
    val personalInfo: PersonalInfo,
    val contactInfo: ContactInfo,
    val creditInfo: CreditInfo,
    val relationships: MutableList<Relationship>,
    val opportunities: MutableList<Opportunity>,
    val segment: CustomerSegment,
    val lifetimeValue: BigDecimal
) {
    fun calculateLTV(): BigDecimal { /* CRM-specific logic */ }
    fun updateSegment() { /* CRM-specific logic */ }
}

// 2️⃣ Commerce Context - Shopping-focused data
package com.chiro.erp.commerce.ecommerce.domain.models

@Entity
@Table(name = "shopper_profiles", schema = "commerce_schema")
class ShopperProfile(
    @Id val id: UUID,
    val customerId: UUID, // Reference to CRM customer
    val shoppingPreferences: ShoppingPreferences,
    val cartHistory: MutableList<CartSnapshot>,
    val wishlist: MutableList<WishlistItem>,
    val recentViews: MutableList<ProductView>
) {
    fun recommendProducts(): List<UUID> { /* Commerce-specific logic */ }
    fun abandonedCart(): Cart? { /* Commerce-specific logic */ }
}

// 3️⃣ Financial Context - Billing-focused data
package com.chiro.erp.financialmanagement.accountsreceivable.domain.models

@Entity
@Table(name = "billing_accounts", schema = "finance_schema")
class BillingAccount(
    @Id val id: UUID,
    val customerId: UUID, // Reference to CRM customer
    val paymentTerms: PaymentTerms,
    val creditLimit: BigDecimal,
    val outstandingBalance: BigDecimal,
    val invoices: MutableList<Invoice>
) {
    fun canExtendCredit(amount: BigDecimal): Boolean { /* Finance-specific logic */ }
    fun calculateAging(): AgingReport { /* Finance-specific logic */ }
}
```

**Benefits**:

-   ✅ Each context optimized for its use cases
-   ✅ Independent evolution
-   ✅ Clear ownership
-   ✅ No shared coupling

---

### Pattern 2: Shared Kernel (Minimal)

**When to Use**: Very stable, truly universal concepts (use sparingly).

**What Belongs in Shared Kernel**:

-   Value Objects (Email, Money, Address)
-   Domain Events
-   Common types (CustomerId, TenantId)

```kotlin
// ✅ Shared Kernel - Common Value Objects
package com.chiro.erp.shared.domain.valueobjects

@Embeddable
data class Money(
    @Column(precision = 19, scale = 4)
    val amount: BigDecimal,

    @Column(length = 3)
    val currency: String
) {
    init {
        require(amount >= BigDecimal.ZERO) { "Amount cannot be negative" }
        require(currency.length == 3) { "Currency must be ISO 4217 code" }
    }

    operator fun plus(other: Money): Money {
        require(currency == other.currency) { "Cannot add different currencies" }
        return Money(amount + other.amount, currency)
    }
}

@Embeddable
data class Email(
    @Column(nullable = false)
    val address: String
) {
    init {
        require(address.matches(Regex("^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}\$"))) {
            "Invalid email format"
        }
    }
}

// ✅ Shared - Domain Event Base
package com.chiro.erp.shared.domain.events

interface DomainEvent {
    val eventId: UUID
    val occurredAt: Instant
    val aggregateId: UUID
    val tenantId: UUID
}

// ✅ Shared - Entity IDs (Type Aliases)
package com.chiro.erp.shared.domain.types

@JvmInline
value class CustomerId(val value: UUID)

@JvmInline
value class TenantId(val value: UUID)

@JvmInline
value class OrderId(val value: UUID)
```

**Structure**:

```
services/
├── core-platform/
├── customer-relationship/
├── commerce/
└── shared/                        # Minimal shared kernel
    └── src/main/kotlin/com/chiro/erp/shared/
        ├── domain/
        │   ├── valueobjects/      # Money, Email, Address
        │   ├── events/            # DomainEvent interface
        │   └── types/             # CustomerId, TenantId, etc.
        └── infrastructure/
            └── messaging/         # Event publishing utilities
```

---

### Pattern 3: Published Language (Events)

**When to Use**: Cross-context communication and data synchronization.

**Example**: Customer data synchronization

```kotlin
// 1️⃣ CRM Context publishes customer events
package com.chiro.erp.customerrelationship.crm.domain.events

data class CustomerCreatedEvent(
    override val eventId: UUID = UUID.randomUUID(),
    override val occurredAt: Instant = Instant.now(),
    override val aggregateId: UUID,
    override val tenantId: UUID,

    // Published language - what others need to know
    val customerId: UUID,
    val customerNumber: String,
    val name: String,
    val email: String,
    val type: String, // "B2C", "B2B"
    val status: String
) : DomainEvent

data class CustomerUpdatedEvent(
    override val eventId: UUID = UUID.randomUUID(),
    override val occurredAt: Instant = Instant.now(),
    override val aggregateId: UUID,
    override val tenantId: UUID,

    val customerId: UUID,
    val changes: Map<String, Any> // What changed
) : DomainEvent

// 2️⃣ Commerce Context subscribes and creates its model
package com.chiro.erp.commerce.ecommerce.application

@Component
class CustomerEventListener(
    private val shopperProfileRepository: ShopperProfileRepository
) {
    @KafkaListener(topics = ["customer-events"])
    suspend fun onCustomerCreated(event: CustomerCreatedEvent) {
        // Create commerce-specific model
        val shopperProfile = ShopperProfile(
            id = UUID.randomUUID(),
            customerId = event.customerId,
            shoppingPreferences = ShoppingPreferences.default(),
            cartHistory = mutableListOf(),
            wishlist = mutableListOf()
        )
        shopperProfileRepository.save(shopperProfile)
    }
}

// 3️⃣ Financial Context also subscribes
package com.chiro.erp.financialmanagement.accountsreceivable.application

@Component
class CustomerEventListener(
    private val billingAccountRepository: BillingAccountRepository
) {
    @KafkaListener(topics = ["customer-events"])
    suspend fun onCustomerCreated(event: CustomerCreatedEvent) {
        // Create finance-specific model
        val billingAccount = BillingAccount(
            id = UUID.randomUUID(),
            customerId = event.customerId,
            paymentTerms = PaymentTerms.default(),
            creditLimit = BigDecimal.ZERO,
            outstandingBalance = BigDecimal.ZERO,
            invoices = mutableListOf()
        )
        billingAccountRepository.save(billingAccount)
    }
}
```

**Benefits**:

-   ✅ Eventual consistency
-   ✅ Loose coupling
-   ✅ Independent scaling
-   ✅ Resilient to failures

---

### Pattern 4: Anti-Corruption Layer (ACL)

**When to Use**: Protecting domain from external models.

**Example**: Integrating with external customer service

```kotlin
// External API model (from legacy system or third party)
data class ExternalCustomerDTO(
    val customer_id: String,
    val full_name: String,
    val email_address: String,
    val status_code: Int
)

// ✅ Anti-Corruption Layer translates to domain model
package com.chiro.erp.customerrelationship.crm.infrastructure.external

@Component
class ExternalCustomerACL(
    private val externalCustomerApi: ExternalCustomerApi
) {
    suspend fun fetchCustomer(externalId: String): Customer {
        val external = externalCustomerApi.getCustomer(externalId)

        // Translate to our domain model
        return Customer(
            id = UUID.fromString(external.customer_id),
            personalInfo = parsePersonalInfo(external.full_name),
            contactInfo = ContactInfo(email = external.email_address),
            status = mapStatus(external.status_code),
            tenantId = getCurrentTenantId()
        )
    }

    private fun mapStatus(statusCode: Int): CustomerStatus {
        return when (statusCode) {
            1 -> CustomerStatus.ACTIVE
            2 -> CustomerStatus.INACTIVE
            else -> CustomerStatus.SUSPENDED
        }
    }
}
```

---

## 🗄️ Database Strategies

### Strategy 1: Schema-per-Domain (Recommended for Your Setup)

Each domain has its own schema within the shared database.

```sql
-- CRM Schema
CREATE SCHEMA crm_schema;

CREATE TABLE crm_schema.customers (
    id UUID PRIMARY KEY,
    customer_number VARCHAR(50) NOT NULL,
    personal_info JSONB,
    contact_info JSONB,
    credit_info JSONB,
    tenant_id UUID NOT NULL
);

-- Commerce Schema
CREATE SCHEMA commerce_schema;

CREATE TABLE commerce_schema.shopper_profiles (
    id UUID PRIMARY KEY,
    customer_id UUID NOT NULL, -- Reference only, no FK
    shopping_preferences JSONB,
    cart_history JSONB,
    tenant_id UUID NOT NULL
);

-- Financial Schema
CREATE SCHEMA finance_schema;

CREATE TABLE finance_schema.billing_accounts (
    id UUID PRIMARY KEY,
    customer_id UUID NOT NULL, -- Reference only, no FK
    payment_terms JSONB,
    credit_limit DECIMAL(19, 4),
    tenant_id UUID NOT NULL
);
```

**Benefits**:

-   ✅ Clear ownership
-   ✅ Independent evolution
-   ✅ Easy to query within domain
-   ✅ Can move to separate DB later

---

### Strategy 2: Reference Data Duplication

For frequently accessed reference data, duplicate into each context.

```kotlin
// ✅ Each context maintains its own customer reference data
package com.chiro.erp.commerce.ecommerce.domain.models

@Entity
@Table(name = "customer_references", schema = "commerce_schema")
class CustomerReference(
    @Id val customerId: UUID,
    val customerNumber: String,
    val displayName: String,
    val email: String,
    val status: String,
    val lastSyncedAt: Instant
) {
    companion object {
        fun fromEvent(event: CustomerCreatedEvent): CustomerReference {
            return CustomerReference(
                customerId = event.customerId,
                customerNumber = event.customerNumber,
                displayName = event.name,
                email = event.email,
                status = event.status,
                lastSyncedAt = Instant.now()
            )
        }
    }
}
```

**Synchronization via Events**:

```kotlin
@Component
class CustomerReferenceSyncListener(
    private val customerRefRepository: CustomerReferenceRepository
) {
    @KafkaListener(topics = ["customer-events"])
    suspend fun onCustomerUpdated(event: CustomerUpdatedEvent) {
        val ref = customerRefRepository.findById(event.customerId)
        if (ref != null) {
            // Update local reference
            ref.applyChanges(event.changes)
            ref.lastSyncedAt = Instant.now()
            customerRefRepository.save(ref)
        }
    }
}
```

---

## 📋 Implementation Checklist for Your ERP

### For Each "Shared" Entity:

-   [ ] **Identify True Owner**: Which context is the source of truth?
-   [ ] **Create Context-Specific Models**: Each context gets its own entity class
-   [ ] **Define Published Events**: What does the owner publish?
-   [ ] **Implement Event Listeners**: How do consumers stay synchronized?
-   [ ] **Use ID References Only**: No cross-schema foreign keys
-   [ ] **Create ACLs if Needed**: Protect domain from external models
-   [ ] **Document Relationships**: Update context mapping

### Example: Customer Entity

```
✅ CRM Context:
   - Owns: Customer (full entity with all relationship data)
   - Publishes: CustomerCreatedEvent, CustomerUpdatedEvent, CustomerDeletedEvent
   - Location: services/customer-relationship/src/main/kotlin/.../crm/domain/models/

✅ Commerce Context:
   - Owns: ShopperProfile (shopping-specific data)
   - References: customerId (UUID)
   - Subscribes: Customer events for synchronization
   - Location: services/commerce/src/main/kotlin/.../ecommerce/domain/models/

✅ Financial Context:
   - Owns: BillingAccount (billing-specific data)
   - References: customerId (UUID)
   - Subscribes: Customer events for synchronization
   - Location: services/financial-management/src/main/kotlin/.../accounts-receivable/domain/models/

✅ Operations Context:
   - Owns: ServiceCustomer (service history data)
   - References: customerId (UUID)
   - Subscribes: Customer events for synchronization
   - Location: services/operations-service/src/main/kotlin/.../field-service/domain/models/
```

---

## 🎯 Concrete Examples for Your Services

### Example 1: Product/Item

**Owner**: Supply Chain Manufacturing (Inventory Domain)

```kotlin
// 1️⃣ Supply Chain - Owns the product
package com.chiro.erp.supplychainmanufacturing.inventory.domain.models

@Entity
@Table(name = "products", schema = "supply_chain_schema")
class Product(
    @Id val id: UUID,
    val sku: String,
    val name: String,
    val category: ProductCategory,
    val dimensions: Dimensions,
    val weight: Weight,
    val stockLevels: MutableList<StockLevel>,
    val costInfo: CostInfo
)

// 2️⃣ Commerce - Has product catalog view
package com.chiro.erp.commerce.ecommerce.domain.models

@Entity
@Table(name = "catalog_items", schema = "commerce_schema")
class CatalogItem(
    @Id val id: UUID,
    val productId: UUID, // Reference
    val displayName: String,
    val description: String,
    val images: List<String>,
    val pricing: Pricing,
    val availability: Boolean
)

// 3️⃣ Financial - Has product pricing
package com.chiro.erp.financialmanagement.accountsreceivable.domain.models

@Entity
@Table(name = "price_list_items", schema = "finance_schema")
class PriceListItem(
    @Id val id: UUID,
    val productId: UUID, // Reference
    val sku: String,
    val basePrice: Money,
    val discounts: List<Discount>,
    val taxCategory: TaxCategory
)
```

### Example 2: Organization/Tenant

**Owner**: Core Platform (Organization Domain)

```kotlin
// 1️⃣ Core Platform - Owns organization
package com.chiro.erp.coreplatform.organization.domain.models

@Entity
@Table(name = "organizations", schema = "core_schema")
class Organization(
    @Id val id: UUID,
    val tenantId: UUID,
    val name: String,
    val hierarchy: OrganizationHierarchy,
    val departments: MutableList<Department>,
    val settings: OrganizationSettings
)

// 2️⃣ All other contexts - Reference only
// No entity needed, just use tenantId: UUID in every entity

@Entity
class Customer(
    @Id val id: UUID,
    val tenantId: UUID, // ✅ Reference to organization
    // ... other fields
)
```

### Example 3: User

**Owner**: Core Platform (Security Domain)

```kotlin
// 1️⃣ Core Platform - Owns user identity
package com.chiro.erp.coreplatform.security.domain.models

@Entity
@Table(name = "users", schema = "core_schema")
class User(
    @Id val id: UUID,
    val username: String,
    val email: Email,
    val passwordHash: String,
    val roles: MutableSet<UserRoleAssignment>,
    val mfaSettings: MfaSettings?
)

// 2️⃣ HR - Has employee data
package com.chiro.erp.administration.hr.domain.models

@Entity
@Table(name = "employees", schema = "admin_schema")
class Employee(
    @Id val id: UUID,
    val userId: UUID, // Reference to core platform user
    val employeeNumber: String,
    val department: String,
    val position: String,
    val salary: Money,
    val hireDate: LocalDate
)

// 3️⃣ Operations - Has technician data
package com.chiro.erp.operationsservice.fieldservice.domain.models

@Entity
@Table(name = "technicians", schema = "operations_schema")
class Technician(
    @Id val id: UUID,
    val userId: UUID, // Reference to core platform user
    val certifications: List<Certification>,
    val skills: Set<Skill>,
    val serviceArea: GeographicArea,
    val availability: Schedule
)
```

---

## 🚨 Common Pitfalls to Avoid

### ❌ Pitfall 1: Shared Entity Base Class

```kotlin
// ❌ WRONG: Shared base entity
@MappedSuperclass
abstract class BaseCustomer {
    @Id val id: UUID
    val name: String
}

// CRM inherits from shared base
class CRMCustomer : BaseCustomer()

// Commerce inherits from shared base
class CommerceCustomer : BaseCustomer()
```

**Why Wrong**: Creates tight coupling, makes independent evolution impossible.

### ❌ Pitfall 2: Cross-Schema Foreign Keys

```kotlin
// ❌ WRONG: Foreign key to another schema
@Entity
@Table(name = "orders", schema = "commerce_schema")
class Order(
    @Id val id: UUID,

    @ManyToOne
    @JoinColumn(
        name = "customer_id",
        foreignKey = ForeignKey(
            name = "fk_order_customer",
            foreignKeyDefinition = "FOREIGN KEY (customer_id) REFERENCES crm_schema.customers(id)"
        )
    )
    val customer: Customer // ❌ Cross-schema FK
)
```

**Why Wrong**: Creates database-level coupling, prevents independent deployment.

### ❌ Pitfall 3: Synchronous Cross-Context Queries

```kotlin
// ❌ WRONG: Synchronous call to another context
@Service
class OrderService(
    private val crmClient: CRMRestClient // ❌ Synchronous dependency
) {
    suspend fun createOrder(request: CreateOrderRequest) {
        val customer = crmClient.getCustomer(request.customerId) // ❌ Blocking
        // ... create order
    }
}
```

**Why Wrong**: Creates runtime coupling, reduces availability.

**✅ Correct**: Use local reference data synchronized via events.

---

## 📚 Recommended Reading

1. **Domain-Driven Design** by Eric Evans - Chapter on Bounded Contexts
2. **Implementing Domain-Driven Design** by Vaughn Vernon - Context Mapping patterns
3. **Building Microservices** by Sam Newman - Data management patterns
4. **Microservices Patterns** by Chris Richardson - Saga and event sourcing patterns

---

## ✅ Summary: Best Practices

1. **Each bounded context owns its model** - No shared entity classes
2. **Reference by ID only** - UUID references, not foreign keys
3. **Synchronize via events** - Published language for communication
4. **Minimal shared kernel** - Only value objects and event interfaces
5. **Anti-corruption layers** - Protect domain from external models
6. **Schema per domain** - Clear database ownership
7. **Eventual consistency** - Accept temporary inconsistency
8. **Context-specific optimization** - Each model optimized for its use case

---

**Your ERP Structure** follows these principles perfectly:

```
services/
├── core-platform/             # Owns: User, Organization, Tenant
├── customer-relationship/     # Owns: Customer, Lead, Opportunity
├── operations-service/        # Owns: WorkOrder, ServiceTicket
├── commerce/                  # Owns: Order, Cart, Catalog
├── financial-management/      # Owns: Invoice, Payment, BillingAccount
├── supply-chain-manufacturing/# Owns: Product, Stock, Production
└── administration/            # Owns: Employee, Fleet, Report

# Each references others by ID only
# Each synchronizes via domain events
# Each maintains its own optimized model
```

This approach gives you the best of both worlds: **clean domain boundaries** with **practical data access**.
