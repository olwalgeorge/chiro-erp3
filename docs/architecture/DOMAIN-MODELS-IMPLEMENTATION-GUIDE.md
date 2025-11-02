# Domain Models Implementation Guide

## Overview

This document provides **comprehensive implementation guidelines** for all domain models across the Chiro ERP system, covering:

-   Domain model patterns and best practices
-   Database schema design
-   Repository patterns
-   Event-driven architecture
-   Cross-service integration
-   Testing strategies

---

## Table of Contents

### Domain Models Documentation

1. **[DOMAIN-MODELS-COMPLETE.md](./DOMAIN-MODELS-COMPLETE.md)**

    - Core Platform domains (Security, Organization, Audit, Configuration, Notification)
    - Customer Relationship domains (CRM, Client, Provider, Subscription, Promotion)

2. **[DOMAIN-MODELS-FINANCIAL.md](./DOMAIN-MODELS-FINANCIAL.md)**

    - General Ledger (SAP FI pattern)
    - Accounts Receivable
    - Accounts Payable
    - Asset Accounting
    - Tax Engine
    - Expense Management

3. **[DOMAIN-MODELS-SUPPLY-CHAIN.md](./DOMAIN-MODELS-SUPPLY-CHAIN.md)**
    - Inventory Management (SAP MM pattern)
    - Production Management (SAP PP pattern)
    - Procurement Management
    - Quality Management
    - Product Costing

---

## Implementation Roadmap

### Phase 1: Foundation (Weeks 1-4)

**Core Platform Service**

Priority order:

1. **Security Domain** (Week 1)

    - User, Role, Permission entities
    - Authentication and authorization
    - Security context propagation

2. **Organization Domain** (Week 1-2)

    - Organization, Department entities
    - Multi-tenant data isolation
    - Organizational hierarchy

3. **Audit Domain** (Week 2)

    - Audit logging infrastructure
    - Event capture mechanism

4. **Configuration Domain** (Week 3)

    - System configuration management
    - Feature flags

5. **Notification Domain** (Week 3-4)
    - Multi-channel notifications
    - Email/SMS integration

### Phase 2: Financial Foundation (Weeks 5-10)

**Financial Management Service**

1. **General Ledger** (Week 5-7)

    - Chart of Accounts
    - GL Accounts
    - Journal Entries
    - Account Balances
    - **Critical**: Single source of financial truth

2. **Accounts Payable** (Week 8-9)

    - Vendor invoices
    - 3-way matching
    - Vendor payments

3. **Accounts Receivable** (Week 9-10)
    - Customer invoices
    - Payment processing
    - Credit management

### Phase 3: Supply Chain Core (Weeks 11-16)

**Supply Chain Manufacturing Service**

1. **Inventory Management** (Week 11-13)

    - Materials master data
    - Stock management
    - Storage locations
    - Material movements

2. **Procurement** (Week 14-15)

    - Purchase requisitions
    - Purchase orders
    - Goods receipt

3. **Production** (Week 15-16)
    - Production orders
    - Bill of Materials
    - Work centers

### Phase 4: Customer & Operations (Weeks 17-22)

**Customer Relationship & Operations Services**

1. **CRM Domain** (Week 17-18)

    - Customer, Lead, Opportunity
    - Sales pipeline

2. **Field Service** (Week 19-20)

    - Service orders
    - Technician scheduling

3. **Commerce** (Week 21-22)
    - Product catalog
    - Shopping cart
    - Order processing

### Phase 5: Analytics & Optimization (Weeks 23-26)

**Analytics Intelligence Service**

1. **Data Products** (Week 23-24)

    - ETL pipelines
    - Data warehousing

2. **Reporting** (Week 25-26)
    - Business intelligence
    - Dashboards

---

## Domain Model Implementation Patterns

### 1. Entity Base Classes

```kotlin
// Base entity with audit fields
@MappedSuperclass
abstract class AuditableEntity(
    @Id
    open val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, updatable = false)
    open val createdAt: Instant = Instant.now(),

    @Column(nullable = false, updatable = false)
    open val createdBy: UUID,

    @Column(nullable = false)
    open var updatedAt: Instant = Instant.now(),

    @Column(nullable = false)
    open var updatedBy: UUID,

    @Version
    open var version: Long = 0
)

// Tenant-aware entity
@MappedSuperclass
abstract class TenantEntity(
    @Column(nullable = false)
    open val tenantId: UUID,

    @Column(nullable = false)
    open val organizationId: UUID
) : AuditableEntity()

// Soft-deletable entity
@MappedSuperclass
abstract class SoftDeletableEntity : TenantEntity() {
    @Column(nullable = false)
    open var isDeleted: Boolean = false

    open var deletedAt: Instant? = null
    open var deletedBy: UUID? = null
}
```

### 2. Repository Pattern

```kotlin
// Base repository interface
interface BaseRepository<T, ID> {
    suspend fun findById(id: ID): T?
    suspend fun findAll(): List<T>
    suspend fun save(entity: T): T
    suspend fun delete(entity: T)
    suspend fun existsById(id: ID): Boolean
}

// Example: User Repository (Outbound Port)
interface UserRepository : BaseRepository<User, UUID> {
    suspend fun findByUsername(username: String): User?
    suspend fun findByEmail(email: String): User?
    suspend fun findByTenantId(tenantId: UUID): List<User>
    suspend fun findActiveUsers(): List<User>
}

// Panache implementation
@ApplicationScoped
class UserRepositoryImpl : PanacheRepositoryBase<User, UUID>, UserRepository {
    override suspend fun findByUsername(username: String): User? {
        return find("username = ?1 and isDeleted = false", username)
            .firstResult()
            .awaitSuspending()
    }

    override suspend fun findByEmail(email: String): User? {
        return find("email.address = ?1 and isDeleted = false", email)
            .firstResult()
            .awaitSuspending()
    }

    override suspend fun findByTenantId(tenantId: UUID): List<User> {
        return find("tenantId = ?1 and isDeleted = false", tenantId)
            .list()
            .awaitSuspending()
    }

    override suspend fun findActiveUsers(): List<User> {
        return find("status = ?1 and isDeleted = false", UserStatus.ACTIVE)
            .list()
            .awaitSuspending()
    }
}
```

### 3. Domain Services

```kotlin
// Domain service for complex business logic
@ApplicationScoped
class UserDomainService(
    private val userRepository: UserRepository,
    private val roleRepository: RoleRepository,
    private val eventPublisher: DomainEventPublisher
) {
    suspend fun createUser(
        username: String,
        email: String,
        tenantId: UUID,
        createdBy: UUID
    ): User {
        // Business validation
        val existingUser = userRepository.findByUsername(username)
        require(existingUser == null) { "Username already exists" }

        val existingEmail = userRepository.findByEmail(email)
        require(existingEmail == null) { "Email already exists" }

        // Create user
        val user = User(
            username = username,
            email = Email(email),
            tenantId = tenantId,
            createdBy = createdBy,
            updatedBy = createdBy
        )

        val savedUser = userRepository.save(user)

        // Publish domain event
        eventPublisher.publish(
            UserCreatedEvent(
                userId = savedUser.id,
                tenantId = savedUser.tenantId,
                username = savedUser.username,
                email = savedUser.email.address
            )
        )

        return savedUser
    }

    suspend fun assignRole(userId: UUID, roleId: UUID, assignedBy: UUID) {
        val user = userRepository.findById(userId)
            ?: throw EntityNotFoundException("User not found: $userId")

        val role = roleRepository.findById(roleId)
            ?: throw EntityNotFoundException("Role not found: $roleId")

        user.assignRole(role, assignedBy)
        userRepository.save(user)

        eventPublisher.publish(
            UserRoleAssignedEvent(
                userId = userId,
                roleId = roleId,
                assignedBy = assignedBy
            )
        )
    }
}
```

### 4. Application Services (Use Cases)

```kotlin
// Application service (coordinates domain services)
@ApplicationScoped
class UserManagementService(
    private val userDomainService: UserDomainService,
    private val auditService: AuditService,
    private val notificationService: NotificationService
) {
    @Transactional
    suspend fun registerNewUser(command: RegisterUserCommand): UserDTO {
        // Call domain service
        val user = userDomainService.createUser(
            username = command.username,
            email = command.email,
            tenantId = command.tenantId,
            createdBy = command.requesterId
        )

        // Audit
        auditService.log(
            action = AuditAction.CREATE,
            entityType = "User",
            entityId = user.id,
            userId = command.requesterId,
            description = "User created: ${user.username}"
        )

        // Send notification
        notificationService.sendWelcomeEmail(user)

        return user.toDTO()
    }
}

data class RegisterUserCommand(
    val username: String,
    val email: String,
    val tenantId: UUID,
    val requesterId: UUID
)
```

### 5. REST Controllers (Inbound Adapters)

```kotlin
@Path("/api/users")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
class UserController(
    private val userManagementService: UserManagementService
) {
    @POST
    @Transactional
    suspend fun createUser(request: CreateUserRequest): Response {
        val command = RegisterUserCommand(
            username = request.username,
            email = request.email,
            tenantId = getCurrentTenantId(),
            requesterId = getCurrentUserId()
        )

        val user = userManagementService.registerNewUser(command)

        return Response.status(Response.Status.CREATED)
            .entity(user)
            .build()
    }

    @GET
    @Path("/{id}")
    suspend fun getUser(@PathParam("id") id: UUID): Response {
        val user = userManagementService.getUserById(id)
        return Response.ok(user).build()
    }
}

data class CreateUserRequest(
    val username: String,
    val email: String
)
```

---

## Event-Driven Architecture

### 1. Domain Events

```kotlin
// Base domain event
interface DomainEvent {
    val eventId: UUID get() = UUID.randomUUID()
    val occurredAt: Instant get() = Instant.now()
    val eventType: String get() = this::class.simpleName ?: "UnknownEvent"
}

// Example domain events
data class UserCreatedEvent(
    val userId: UUID,
    val tenantId: UUID,
    val username: String,
    val email: String,
    override val occurredAt: Instant = Instant.now()
) : DomainEvent

data class JournalEntryPostedEvent(
    val journalEntryId: UUID,
    val documentNumber: String,
    val totalDebit: BigDecimal,
    val totalCredit: BigDecimal,
    val fiscalYear: Int,
    val fiscalPeriod: Int,
    override val occurredAt: Instant = Instant.now()
) : DomainEvent

data class MaterialMovementEvent(
    val materialDocumentId: UUID,
    val documentNumber: String,
    val materialId: UUID,
    val quantity: BigDecimal,
    val movementType: MovementType,
    val storageLocationId: UUID,
    override val occurredAt: Instant = Instant.now()
) : DomainEvent
```

### 2. Event Publisher

```kotlin
@ApplicationScoped
class DomainEventPublisher(
    @Channel("domain-events")
    private val eventEmitter: Emitter<String>,
    private val objectMapper: ObjectMapper
) {
    fun publish(event: DomainEvent) {
        val json = objectMapper.writeValueAsString(event)
        eventEmitter.send(Message.of(json)
            .withMetadata(
                Metadata.of(
                    OutgoingKafkaRecordMetadata.builder<String>()
                        .withTopic(getTopicForEvent(event))
                        .withKey(getKeyForEvent(event))
                        .build()
                )
            ))
    }

    private fun getTopicForEvent(event: DomainEvent): String {
        return when (event) {
            is UserCreatedEvent -> "core.users"
            is JournalEntryPostedEvent -> "finance.journal-entries"
            is MaterialMovementEvent -> "supply.material-movements"
            else -> "domain.events"
        }
    }

    private fun getKeyForEvent(event: DomainEvent): String {
        return when (event) {
            is UserCreatedEvent -> event.userId.toString()
            is JournalEntryPostedEvent -> event.journalEntryId.toString()
            is MaterialMovementEvent -> event.materialId.toString()
            else -> event.eventId.toString()
        }
    }
}
```

### 3. Event Consumers

```kotlin
@ApplicationScoped
class AnalyticsEventConsumer(
    private val analyticsService: AnalyticsService
) {
    @Incoming("finance.journal-entries")
    suspend fun handleJournalEntryPosted(message: String) {
        val event = objectMapper.readValue<JournalEntryPostedEvent>(message)

        // Update analytics data warehouse
        analyticsService.recordJournalEntry(
            journalEntryId = event.journalEntryId,
            fiscalYear = event.fiscalYear,
            fiscalPeriod = event.fiscalPeriod,
            amount = event.totalDebit
        )
    }

    @Incoming("supply.material-movements")
    suspend fun handleMaterialMovement(message: String) {
        val event = objectMapper.readValue<MaterialMovementEvent>(message)

        // Update inventory analytics
        analyticsService.recordInventoryMovement(
            materialId = event.materialId,
            quantity = event.quantity,
            movementType = event.movementType
        )
    }
}
```

---

## Cross-Service Integration Patterns

### 1. Read Models for Cross-Service Data

```kotlin
// Customer read model in Finance service
@Entity
@Table(name = "customer_read_model", schema = "finance_schema")
class CustomerReadModel(
    @Id val customerId: UUID,
    var customerNumber: String,
    var customerName: String,
    var email: String,
    var status: String,
    var creditLimit: BigDecimal,
    var lastUpdated: Instant
)

// Event consumer to maintain read model
@ApplicationScoped
class CustomerReadModelConsumer(
    private val readModelRepository: CustomerReadModelRepository
) {
    @Incoming("crm.customer-updates")
    suspend fun handleCustomerUpdate(message: String) {
        val event = objectMapper.readValue<CustomerUpdatedEvent>(message)

        val readModel = readModelRepository.findById(event.customerId)
            ?: CustomerReadModel(customerId = event.customerId)

        readModel.apply {
            customerNumber = event.customerNumber
            customerName = event.customerName
            email = event.email
            status = event.status
            creditLimit = event.creditLimit
            lastUpdated = Instant.now()
        }

        readModelRepository.save(readModel)
    }
}
```

### 2. Saga Pattern for Distributed Transactions

```kotlin
// Order fulfillment saga
@ApplicationScoped
class OrderFulfillmentSaga(
    private val inventoryClient: InventoryClient,
    private val financialClient: FinancialClient,
    private val logisticsClient: LogisticsClient,
    private val sagaRepository: SagaRepository
) {
    @Transactional
    suspend fun fulfillOrder(orderId: UUID) {
        val saga = Saga(
            sagaId = UUID.randomUUID(),
            orderId = orderId,
            status = SagaStatus.STARTED
        )

        try {
            // Step 1: Reserve inventory
            val reservation = inventoryClient.reserveStock(orderId)
            saga.addStep("inventory-reservation", reservation.id)

            // Step 2: Create invoice
            val invoice = financialClient.createInvoice(orderId)
            saga.addStep("invoice-creation", invoice.id)

            // Step 3: Create shipment
            val shipment = logisticsClient.createShipment(orderId)
            saga.addStep("shipment-creation", shipment.id)

            saga.status = SagaStatus.COMPLETED
            sagaRepository.save(saga)

        } catch (e: Exception) {
            // Compensating transactions
            saga.status = SagaStatus.COMPENSATING
            sagaRepository.save(saga)

            compensate(saga)
        }
    }

    private suspend fun compensate(saga: Saga) {
        saga.steps.reversed().forEach { step ->
            when (step.name) {
                "inventory-reservation" ->
                    inventoryClient.releaseReservation(step.resourceId)
                "invoice-creation" ->
                    financialClient.cancelInvoice(step.resourceId)
                "shipment-creation" ->
                    logisticsClient.cancelShipment(step.resourceId)
            }
        }

        saga.status = SagaStatus.COMPENSATED
        sagaRepository.save(saga)
    }
}
```

---

## Database Schema Guidelines

### 1. Naming Conventions

```sql
-- Tables: lowercase with underscores
CREATE TABLE customer_invoices (...)
CREATE TABLE journal_entry_line_items (...)

-- Columns: lowercase with underscores
customer_id UUID
invoice_date DATE
total_amount DECIMAL(19,2)

-- Indexes: idx_<table>_<column(s)>
CREATE INDEX idx_customer_invoices_customer ON customer_invoices(customer_id);
CREATE INDEX idx_invoice_date ON customer_invoices(invoice_date);

-- Foreign keys: fk_<table>_<referenced_table>
ALTER TABLE invoices ADD CONSTRAINT fk_invoices_customers
    FOREIGN KEY (customer_id) REFERENCES customers(id);

-- Unique constraints: uk_<table>_<column(s)>
ALTER TABLE users ADD CONSTRAINT uk_users_username
    UNIQUE (username);
```

### 2. Schema Structure Per Service

```sql
-- Core Platform Schema
CREATE SCHEMA IF NOT EXISTS core_schema;

-- Create extension for UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table
CREATE TABLE core_schema.users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL,
    tenant_id UUID NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by UUID NOT NULL,
    updated_by UUID NOT NULL,
    version BIGINT NOT NULL DEFAULT 0,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,

    CONSTRAINT uk_users_username UNIQUE (username),
    CONSTRAINT uk_users_email UNIQUE (email)
);

CREATE INDEX idx_users_tenant ON core_schema.users(tenant_id);
CREATE INDEX idx_users_status ON core_schema.users(status);
CREATE INDEX idx_users_email ON core_schema.users(email);
```

### 3. Migration Scripts

```kotlin
// Flyway migration: V1__Create_users_table.sql
CREATE SCHEMA IF NOT EXISTS core_schema;

CREATE TABLE core_schema.users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    -- ... columns
);

-- Add indexes
CREATE INDEX idx_users_tenant ON core_schema.users(tenant_id);

-- Add constraints
ALTER TABLE core_schema.users
    ADD CONSTRAINT uk_users_username UNIQUE (username);
```

---

## Testing Strategy

### 1. Unit Tests (Domain Logic)

```kotlin
class UserTest {
    @Test
    fun `should assign role to user`() {
        // Given
        val user = User(
            username = "john.doe",
            email = Email("john@example.com"),
            tenantId = UUID.randomUUID(),
            createdBy = UUID.randomUUID(),
            updatedBy = UUID.randomUUID()
        )

        val role = Role(
            name = "Admin",
            tenantId = user.tenantId
        )

        // When
        user.assignRole(role, user.createdBy)

        // Then
        assertTrue(user.roleAssignments.isNotEmpty())
        assertEquals(role.id, user.roleAssignments.first().roleId)
    }

    @Test
    fun `should not allow negative quantity in journal entry`() {
        // Given
        val journalEntry = JournalEntry(...)

        // When & Then
        assertThrows<IllegalArgumentException> {
            journalEntry.addLineItem(
                JournalEntryLineItem(
                    debitAmount = BigDecimal("-100.00")
                )
            )
        }
    }
}
```

### 2. Integration Tests (Repository Layer)

```kotlin
@QuarkusTest
@TestTransaction
class UserRepositoryTest {
    @Inject
    lateinit var userRepository: UserRepository

    @Test
    fun `should find user by username`() = runBlocking {
        // Given
        val user = User(
            username = "test.user",
            email = Email("test@example.com"),
            tenantId = UUID.randomUUID(),
            createdBy = UUID.randomUUID(),
            updatedBy = UUID.randomUUID()
        )
        userRepository.save(user)

        // When
        val found = userRepository.findByUsername("test.user")

        // Then
        assertNotNull(found)
        assertEquals("test.user", found?.username)
    }
}
```

### 3. API Tests (End-to-End)

```kotlin
@QuarkusTest
class UserControllerTest {
    @Test
    fun `should create user via API`() {
        given()
            .contentType(ContentType.JSON)
            .body("""
                {
                    "username": "new.user",
                    "email": "new@example.com"
                }
            """)
        .`when`()
            .post("/api/users")
        .then()
            .statusCode(201)
            .body("username", equalTo("new.user"))
            .body("email", equalTo("new@example.com"))
    }
}
```

---

## Performance Optimization

### 1. Database Indexing Strategy

```sql
-- Index on frequently queried columns
CREATE INDEX idx_invoices_customer ON customer_invoices(customer_id);
CREATE INDEX idx_invoices_date ON customer_invoices(invoice_date);
CREATE INDEX idx_invoices_status ON customer_invoices(status);

-- Composite indexes for common query patterns
CREATE INDEX idx_invoices_customer_date
    ON customer_invoices(customer_id, invoice_date);

-- Partial indexes for specific conditions
CREATE INDEX idx_invoices_unpaid
    ON customer_invoices(customer_id)
    WHERE status = 'POSTED' AND balance_due > 0;
```

### 2. Query Optimization

```kotlin
// Use pagination for large result sets
interface InvoiceRepository {
    @Query("FROM CustomerInvoice WHERE customerId = :customerId ORDER BY invoiceDate DESC")
    fun findByCustomerId(
        customerId: UUID,
        page: Page
    ): PanacheQuery<CustomerInvoice>
}

// Use projections for read-only queries
data class InvoiceSummary(
    val id: UUID,
    val invoiceNumber: String,
    val totalAmount: BigDecimal,
    val status: String
)

@Query("""
    SELECT new com.chiro.erp.InvoiceSummary(
        i.id, i.invoiceNumber, i.totalAmount, i.status
    )
    FROM CustomerInvoice i
    WHERE i.customerId = :customerId
""")
fun findInvoiceSummaries(customerId: UUID): List<InvoiceSummary>
```

### 3. Caching Strategy

```kotlin
@ApplicationScoped
class MaterialService(
    private val materialRepository: MaterialRepository,
    @CacheResult(cacheName = "materials")
    private val cache: Cache
) {
    @CacheResult(cacheName = "materials")
    suspend fun getMaterialById(id: UUID): Material? {
        return materialRepository.findById(id)
    }

    @CacheInvalidate(cacheName = "materials")
    suspend fun updateMaterial(material: Material): Material {
        return materialRepository.save(material)
    }
}
```

---

## Security Considerations

### 1. Row-Level Security

```kotlin
// Filter by tenant automatically
@PrePersist
@PreUpdate
fun validateTenant(entity: TenantEntity) {
    val currentTenant = SecurityContext.getCurrentTenantId()
    require(entity.tenantId == currentTenant) {
        "Cannot access data from different tenant"
    }
}

// Repository with tenant filtering
@ApplicationScoped
class TenantAwareUserRepository : UserRepository {
    override suspend fun findById(id: UUID): User? {
        val currentTenant = SecurityContext.getCurrentTenantId()
        return find("id = ?1 and tenantId = ?2", id, currentTenant)
            .firstResult()
            .awaitSuspending()
    }
}
```

### 2. Audit Logging

```kotlin
@ApplicationScoped
class AutomaticAuditLogger {
    @PrePersist
    fun onPersist(entity: AuditableEntity) {
        auditService.log(
            action = AuditAction.CREATE,
            entityType = entity::class.simpleName,
            entityId = entity.id,
            userId = SecurityContext.getCurrentUserId()
        )
    }

    @PostUpdate
    fun onUpdate(entity: AuditableEntity) {
        auditService.log(
            action = AuditAction.UPDATE,
            entityType = entity::class.simpleName,
            entityId = entity.id,
            userId = SecurityContext.getCurrentUserId()
        )
    }
}
```

---

## Next Steps

1. **Review domain models** with domain experts
2. **Implement Phase 1** (Core Platform)
3. **Set up CI/CD pipeline** for automated testing
4. **Create migration scripts** for database schemas
5. **Implement event-driven architecture** with Kafka
6. **Build monitoring and observability** tools

---

## Additional Resources

-   [BOUNDED-CONTEXTS.md](./BOUNDED-CONTEXTS.md) - Detailed bounded context mappings
-   [DATABASE-STRATEGY.md](../DATABASE-STRATEGY.md) - Database architecture
-   [ARCHITECTURE-SUMMARY.md](./ARCHITECTURE-SUMMARY.md) - Overall architecture overview
-   [TESTING-GUIDE.md](../TESTING-GUIDE.md) - Comprehensive testing strategies
