# Hexagonal Architecture Quick Reference

## 🎯 30-Second Overview

-   **7 Services** consolidating 30+ microservices
-   **36 Domains** following hexagonal architecture
-   **4 Layers** per domain: Interfaces → Application → Domain → Infrastructure
-   **Zero infrastructure dependencies** in domain layer
-   **Event-driven integration** between services
-   **No shared entities** - Each context owns its model

---

## 🔑 Shared Entities Strategy

### Golden Rule: Each Context Owns Its Model

❌ **Don't**: Share entity classes across bounded contexts

```kotlin
// ❌ WRONG
shared/Customer.kt // Used by multiple services
```

✅ **Do**: Create context-specific models

```kotlin
// ✅ CRM owns its Customer
crm/domain/models/Customer.kt

// ✅ Commerce has ShopperProfile
commerce/domain/models/ShopperProfile.kt

// ✅ Finance has BillingAccount
finance/domain/models/BillingAccount.kt
```

### Reference by ID Only

```kotlin
// ✅ Correct: Reference by UUID
@Entity
class Order(
    val customerId: UUID, // Just the ID
    val items: List<OrderItem>
)

// ❌ Wrong: Cross-context relationship
@Entity
class Order(
    @ManyToOne
    val customer: Customer // ❌ Don't do this
)
```

### Synchronize via Events

```kotlin
// Owner publishes events
data class CustomerCreatedEvent(
    val customerId: UUID,
    val name: String,
    val email: String
)

// Consumers subscribe and create their models
@KafkaListener(topics = ["customer-events"])
suspend fun onCustomerCreated(event: CustomerCreatedEvent) {
    val shopperProfile = ShopperProfile(
        customerId = event.customerId,
        ...
    )
}
```

**📖 Full Details**: See `SHARED-ENTITIES-STRATEGY.md`

---

## 📋 Service Cheat Sheet

| Service                    | Domains | Schema              | Key Responsibility                                   |
| -------------------------- | ------- | ------------------- | ---------------------------------------------------- |
| core-platform              | 6       | core_schema         | Security, Audit, Config, Integration                 |
| customer-relationship      | 5       | crm_schema          | CRM, Customers, Providers, Subscriptions             |
| operations-service         | 4       | operations_schema   | Field Service, Scheduling, RMA                       |
| commerce                   | 4       | commerce_schema     | E-commerce, POS, Portal, Communication               |
| financial-management       | 6       | finance_schema      | GL, AP, AR, Assets, Tax, Expenses                    |
| supply-chain-manufacturing | 5       | supply_chain_schema | Production, Quality, Inventory, Costing, Procurement |
| administration             | 4       | admin_schema        | HR, Logistics, Analytics, Projects                   |

---

## 🏗️ Layer Responsibilities

### 1. Domain Layer (Pure Business Logic)

**Location**: `domain/`

-   **models/**: Entities, Value Objects, Aggregates
-   **services/**: Complex business rules
-   **ports/inbound/**: Use case interfaces (what domain offers)
-   **ports/outbound/**: Repository interfaces (what domain needs)

**Rules**:

-   ✅ Pure business logic
-   ✅ Framework-agnostic
-   ❌ NO infrastructure dependencies
-   ❌ NO annotations (except JPA entity mapping)

### 2. Application Layer (Use Case Orchestration)

**Location**: `application/`

-   Use case implementations
-   Transaction management
-   Security checks
-   Event coordination

**Rules**:

-   ✅ Orchestrates domain objects
-   ✅ Manages transactions
-   ✅ Can depend on domain
-   ❌ NO direct database access

### 3. Infrastructure Layer (Technical Implementations)

**Location**: `infrastructure/`

-   **persistence/**: JPA repositories, database config
-   **messaging/**: Kafka producers/consumers
-   **external/**: REST clients, third-party integrations

**Rules**:

-   ✅ Implements outbound ports
-   ✅ Technical concerns only
-   ✅ Can use frameworks
-   ❌ NO business logic

### 4. Interfaces Layer (Entry Points)

**Location**: `interfaces/`

-   **rest/**: REST controllers, DTOs
-   **graphql/**: GraphQL resolvers (optional)
-   **events/**: Event listeners/handlers

**Rules**:

-   ✅ Handles external requests
-   ✅ Converts DTOs to domain models
-   ✅ Calls application services
-   ❌ NO business logic

---

## 🔄 Request Flow

```
REST Request → Controller → Application Service → Domain Model → Repository
     ↓             ↓              ↓                    ↓             ↓
 interfaces/   interfaces/   application/         domain/    infrastructure/
    rest/        rest/                            models/     persistence/
```

---

## 📦 Package Naming Template

```
com.chiro.erp.{service-package}.{domain-name}.{layer}.{component}
```

**Examples**:

```
com.chiro.erp.coreplatform.security.domain.models.User
com.chiro.erp.customerrelationship.crm.application.CreateCustomerService
com.chiro.erp.financialmanagement.generalledger.interfaces.rest.JournalEntryController
```

---

## 🧪 Testing Quick Reference

| Layer          | Test Type   | Mock Level     | Tools                       |
| -------------- | ----------- | -------------- | --------------------------- |
| Domain         | Unit        | None           | JUnit, Kotlin Test          |
| Application    | Unit        | Mock repos     | MockK, Mockito              |
| Infrastructure | Integration | Testcontainers | Spring Test, Testcontainers |
| Interfaces     | Integration | Real services  | MockMvc, RestAssured        |

---

## ⚡ Common Commands

```powershell
# Generate structure
.\scripts\create-complete-structure.ps1

# Build all services
.\gradlew build

# Run specific service
.\gradlew :services:core-platform:bootRun

# Run tests for a domain
.\gradlew :services:customer-relationship:test --tests "*crm*"

# Check code style
.\gradlew ktlintCheck

# Format code
.\gradlew ktlintFormat
```

---

## 🔍 Find a Domain

### By Original Service

| Original Service                 | New Location                         |
| -------------------------------- | ------------------------------------ |
| service-security-framework       | core-platform/security               |
| service-crm                      | customer-relationship/crm            |
| service-accounting-core          | financial-management/general-ledger  |
| service-inventory-management     | supply-chain-manufacturing/inventory |
| service-ecomm-storefront         | commerce/ecommerce                   |
| service-field-service-management | operations-service/field-service     |
| service-hr-management            | administration/hr                    |

### By Feature

| Feature             | Service                    | Domain              |
| ------------------- | -------------------------- | ------------------- |
| User login          | core-platform              | security            |
| Customer management | customer-relationship      | crm                 |
| Create invoice      | financial-management       | accounts-receivable |
| Stock tracking      | supply-chain-manufacturing | inventory           |
| Online orders       | commerce                   | ecommerce           |
| Service tickets     | operations-service         | field-service       |
| Employee records    | administration             | hr                  |

---

## 🎨 Code Templates

### Domain Entity

```kotlin
@Entity
@Table(name = "entities", schema = "schema_name")
class MyEntity(
    @Id val id: UUID = UUID.randomUUID(),
    @Column(nullable = false) var name: String,
    @Column(nullable = false) val tenantId: UUID,
    @Column(nullable = false) val createdAt: Instant = Instant.now(),
    @Version var version: Long = 0
) {
    fun businessMethod() {
        // Pure business logic
    }
}
```

### Use Case Interface (Inbound Port)

```kotlin
interface MyUseCase {
    suspend fun execute(command: MyCommand): MyResult
}

data class MyCommand(val data: String, val tenantId: UUID)
data class MyResult(val id: UUID, val status: String)
```

### Application Service

```kotlin
@Service
@Transactional
class MyService(
    private val repository: MyRepository
) : MyUseCase {
    override suspend fun execute(command: MyCommand): MyResult {
        // Orchestrate domain objects
        val entity = MyEntity(name = command.data, tenantId = command.tenantId)
        repository.save(entity)
        return MyResult(entity.id, "SUCCESS")
    }
}
```

### Repository Interface (Outbound Port)

```kotlin
interface MyRepository {
    suspend fun save(entity: MyEntity): MyEntity
    suspend fun findById(id: UUID): MyEntity?
    suspend fun findByTenantId(tenantId: UUID): List<MyEntity>
}
```

### JPA Repository Implementation

```kotlin
@Repository
interface JpaMyRepository :
    MyRepository,
    CoroutineCrudRepository<MyEntity, UUID> {
    override suspend fun findByTenantId(tenantId: UUID): List<MyEntity>
}
```

### REST Controller

```kotlin
@RestController
@RequestMapping("/api/v1/entities")
class MyController(
    private val useCase: MyUseCase
) {
    @PostMapping
    suspend fun create(@RequestBody request: CreateRequest): ResponseEntity<CreateResponse> {
        val command = MyCommand(request.data, getTenantId())
        val result = useCase.execute(command)
        return ResponseEntity.ok(CreateResponse(result.id))
    }
}

data class CreateRequest(val data: String)
data class CreateResponse(val id: UUID)
```

---

## 🚨 Common Pitfalls

### ❌ Don't Do This

```kotlin
// Domain entity with @Autowired
@Entity
class Customer(
    @Autowired private val emailService: EmailService // ❌ NO!
)

// Application service with SQL
class MyService {
    fun execute() {
        jdbcTemplate.query("SELECT * FROM...") // ❌ NO! Use repository
    }
}

// Controller with business logic
@RestController
class MyController {
    fun create() {
        if (price > 1000) { // ❌ NO! Business logic in controller
            discount = 0.1
        }
    }
}
```

### ✅ Do This Instead

```kotlin
// Domain entity - pure logic
@Entity
class Customer {
    fun sendWelcomeEmail(): CustomerEmailEvent {
        return CustomerEmailEvent(this.id, "WELCOME")
    }
}

// Application service - orchestration
class MyService(private val repository: MyRepository) {
    suspend fun execute() {
        repository.findAll() // ✅ Use repository
    }
}

// Controller - delegation only
@RestController
class MyController(private val useCase: MyUseCase) {
    suspend fun create(request: Request) {
        useCase.execute(request.toCommand()) // ✅ Delegate to use case
    }
}
```

---

## 📚 Key Documents

| Document                               | Purpose                        | Read When               |
| -------------------------------------- | ------------------------------ | ----------------------- |
| ARCHITECTURE-SUMMARY.md                | Complete architecture overview | Starting project        |
| DOMAIN-MODELS-COMPLETE.md              | Entity definitions             | Implementing domain     |
| HEXAGONAL-ARCHITECTURE-VISUAL-GUIDE.md | Visual structure guide         | Understanding layers    |
| STRUCTURE-UPDATE-SUMMARY.md            | Update summary                 | After structure changes |
| This document                          | Quick reference                | Coding daily            |

---

## 🎯 Decision Flowchart

```
Need to add code?
    │
    ├─ Business rule/validation?
    │  └─→ Domain Layer (domain/models or domain/services)
    │
    ├─ Coordinate multiple operations?
    │  └─→ Application Layer (application/)
    │
    ├─ Database/Kafka/External API?
    │  └─→ Infrastructure Layer (infrastructure/)
    │
    └─ Handle HTTP request/response?
       └─→ Interfaces Layer (interfaces/rest)
```

---

## ✅ Checklist for New Domain Feature

-   [ ] Create entity in `domain/models/`
-   [ ] Define use case interface in `domain/ports/inbound/`
-   [ ] Define repository interface in `domain/ports/outbound/`
-   [ ] Implement use case in `application/`
-   [ ] Implement repository in `infrastructure/persistence/`
-   [ ] Create REST controller in `interfaces/rest/`
-   [ ] Add unit tests for domain logic
-   [ ] Add integration tests for API
-   [ ] Add Kafka events (if needed)
-   [ ] Update API documentation
-   [ ] Apply multi-tenant checks
-   [ ] Add audit logging

---

## 🔗 Integration Patterns

### Event Publishing

```kotlin
// In application service
class MyService(
    private val eventPublisher: EventPublisher
) {
    suspend fun execute(command: MyCommand) {
        // ... business logic ...
        eventPublisher.publish(MyDomainEvent(entityId, "CREATED"))
    }
}
```

### Event Consuming

```kotlin
// In infrastructure/messaging
@Component
class MyEventListener(
    private val useCase: MyUseCase
) {
    @KafkaListener(topics = ["my-events"])
    suspend fun handle(event: MyDomainEvent) {
        useCase.execute(event.toCommand())
    }
}
```

---

## 💡 Pro Tips

1. **Start with domain models** - Define entities before anything else
2. **Use value objects** - For concepts like Email, Money, Address
3. **Keep aggregates small** - One entity + direct children only
4. **Publish domain events** - For cross-service communication
5. **Use repository patterns** - Never expose JPA outside infrastructure
6. **DTOs at boundaries** - Don't expose domain models in REST APIs
7. **Test domain first** - Unit tests for business logic are fastest
8. **Document decisions** - Use ADRs (Architecture Decision Records)

---

## 📞 Getting Help

-   **Architecture questions**: Review ARCHITECTURE-SUMMARY.md
-   **Domain modeling**: Check DOMAIN-MODELS-COMPLETE.md
-   **Visual structure**: See HEXAGONAL-ARCHITECTURE-VISUAL-GUIDE.md
-   **Migration help**: Follow STRUCTURE-UPDATE-SUMMARY.md

---

**Last Updated**: November 2, 2025
**Version**: 1.0
**Status**: ✅ Complete
