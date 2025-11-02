# DDD Implementation Plan - ChiroERP

## Global and Shared Entity Management Strategy

**Created:** November 2, 2025
**Status:** 🎯 Implementation Roadmap
**Priority:** HIGH - Foundation for Scalable Microservices

---

## 📊 Current State Analysis

### ✅ What's Working Well

1. **Architecture Foundation**

    - ✅ 8 microservices with clear bounded contexts
    - ✅ Single database with schema separation (`*_schema`)
    - ✅ Hexagonal architecture (domain/application/infrastructure/interfaces)
    - ✅ Quarkus + Kotlin + Reactive stack
    - ✅ Kafka infrastructure ready for events
    - ✅ Keycloak for centralized authentication

2. **Deployment Success**
    - ✅ All 16 containers running
    - ✅ No port conflicts (Keycloak on 8180)
    - ✅ Health checks operational
    - ✅ Monitoring infrastructure (Prometheus/Grafana)

### ⚠️ Critical Gaps (Need Implementation)

1. **No Domain Events Implementation**

    - Missing event models
    - No event publishers/listeners
    - No Kafka integration in services

2. **No Anti-Corruption Layers**

    - Direct coupling potential between contexts
    - No translation layers for cross-context communication

3. **Shared Entity Pattern Unclear**

    - Need to verify if entities are duplicated or referenced
    - Missing UUID reference patterns
    - No documentation of owned vs referenced data

4. **No Event-Driven Synchronization**
    - Changes in one context don't propagate
    - Eventual consistency not implemented

---

## 🎯 Implementation Plan

### **Phase 1: Foundation - Event Infrastructure** (Week 1-2)

**Priority:** 🔴 CRITICAL - Must complete first

#### Task 1.1: Create Shared Event Library

**Location:** `services/core-platform/src/main/kotlin/com/chiro/erp/coreplatform/shared/events/`

```kotlin
// Base event types
sealed interface DomainEvent {
    val eventId: UUID
    val aggregateId: UUID
    val aggregateType: String
    val eventType: String
    val occurredAt: Instant
    val tenantId: UUID
    val metadata: EventMetadata
}

data class EventMetadata(
    val causationId: UUID?,      // Event that caused this
    val correlationId: UUID,     // Business flow ID
    val userId: UUID,            // Who triggered it
    val source: String,          // Which service
    val version: Int = 1
)

// Customer-related events
data class CustomerCreatedEvent(
    override val eventId: UUID = UUID.randomUUID(),
    override val aggregateId: UUID,
    override val aggregateType: String = "Customer",
    override val eventType: String = "CustomerCreated",
    override val occurredAt: Instant = Instant.now(),
    override val tenantId: UUID,
    override val metadata: EventMetadata,

    // Payload
    val customerId: UUID,
    val customerNumber: String,
    val customerType: String,
    val status: String,
    val personalInfo: CustomerPersonalInfo,
    val contactInfo: CustomerContactInfo
) : DomainEvent

data class CustomerCreditLimitChangedEvent(
    override val eventId: UUID = UUID.randomUUID(),
    override val aggregateId: UUID,
    override val aggregateType: String = "Customer",
    override val eventType: String = "CustomerCreditLimitChanged",
    override val occurredAt: Instant = Instant.now(),
    override val tenantId: UUID,
    override val metadata: EventMetadata,

    // Payload
    val customerId: UUID,
    val previousLimit: BigDecimal,
    val newLimit: BigDecimal,
    val reason: String,
    val approvedBy: UUID
) : DomainEvent

data class CustomerStatusChangedEvent(
    override val eventId: UUID = UUID.randomUUID(),
    override val aggregateId: UUID,
    override val aggregateType: String = "Customer",
    override val eventType: String = "CustomerStatusChanged",
    override val occurredAt: Instant = Instant.now(),
    override val tenantId: UUID,
    override val metadata: EventMetadata,

    // Payload
    val customerId: UUID,
    val previousStatus: String,
    val newStatus: String,
    val reason: String?
) : DomainEvent

// Value objects for events (minimal data)
data class CustomerPersonalInfo(
    val firstName: String,
    val lastName: String,
    val email: String
)

data class CustomerContactInfo(
    val primaryEmail: String,
    val primaryPhone: String
)
```

**Files to Create:**

-   `DomainEvent.kt`
-   `CustomerEvents.kt`
-   `OrderEvents.kt`
-   `InvoiceEvents.kt`
-   `InventoryEvents.kt`
-   `ServiceOrderEvents.kt`

---

#### Task 1.2: Kafka Event Publisher

**Location:** `services/core-platform/src/main/kotlin/com/chiro/erp/coreplatform/shared/events/`

```kotlin
@ApplicationScoped
class EventPublisher(
    private val emitter: Emitter<String> // Kafka emitter
) {
    private val logger = LoggerFactory.getLogger(javaClass)

    suspend fun publish(event: DomainEvent) {
        try {
            val topic = getTopic(event)
            val message = Message.of(event)
                .withTopic(topic)
                .withKey(event.aggregateId.toString())
                .withMetadata(Metadata.of(
                    OutgoingKafkaRecordMetadata.builder<String>()
                        .withKey(event.aggregateId.toString())
                        .withHeaders(mapEventHeaders(event))
                        .build()
                ))

            emitter.send(message).await()

            logger.info(
                "Published event: {} for aggregate: {} to topic: {}",
                event.eventType,
                event.aggregateId,
                topic
            )
        } catch (e: Exception) {
            logger.error("Failed to publish event: ${event.eventType}", e)
            throw EventPublishingException("Failed to publish event", e)
        }
    }

    private fun getTopic(event: DomainEvent): String {
        return when (event.aggregateType) {
            "Customer" -> "crm.customer.events"
            "Invoice" -> "finance.invoice.events"
            "Order" -> "commerce.order.events"
            "ServiceOrder" -> "operations.service-order.events"
            "InventoryItem" -> "supply.inventory.events"
            else -> "domain.events"
        }
    }

    private fun mapEventHeaders(event: DomainEvent): RecordHeaders {
        val headers = RecordHeaders()
        headers.add("event-type", event.eventType.toByteArray())
        headers.add("aggregate-type", event.aggregateType.toByteArray())
        headers.add("correlation-id", event.metadata.correlationId.toString().toByteArray())
        headers.add("tenant-id", event.tenantId.toString().toByteArray())
        return headers
    }
}

class EventPublishingException(message: String, cause: Throwable? = null) :
    RuntimeException(message, cause)
```

---

#### Task 1.3: Kafka Configuration

**Location:** Update all `application.properties`

```properties
# Kafka Producer Configuration (for all services)
mp.messaging.outgoing.domain-events.connector=smallrye-kafka
mp.messaging.outgoing.domain-events.topic=domain.events
mp.messaging.outgoing.domain-events.value.serializer=io.quarkus.kafka.client.serialization.JsonbSerializer
mp.messaging.outgoing.domain-events.key.serializer=org.apache.kafka.common.serialization.StringSerializer

# Service-specific topics
# CRM Service
mp.messaging.outgoing.customer-events.connector=smallrye-kafka
mp.messaging.outgoing.customer-events.topic=crm.customer.events
mp.messaging.outgoing.customer-events.value.serializer=io.quarkus.kafka.client.serialization.JsonbSerializer

# Financial Service
mp.messaging.outgoing.invoice-events.connector=smallrye-kafka
mp.messaging.outgoing.invoice-events.topic=finance.invoice.events
mp.messaging.outgoing.invoice-events.value.serializer=io.quarkus.kafka.client.serialization.JsonbSerializer

# Consumer Configuration (for each service)
mp.messaging.incoming.customer-events.connector=smallrye-kafka
mp.messaging.incoming.customer-events.topic=crm.customer.events
mp.messaging.incoming.customer-events.value.deserializer=io.quarkus.kafka.client.serialization.JsonbDeserializer
mp.messaging.incoming.customer-events.group.id=${quarkus.application.name}
mp.messaging.incoming.customer-events.auto.offset.reset=earliest
```

---

### **Phase 2: Customer Context Implementation** (Week 2-3)

**Priority:** 🔴 HIGH - Most referenced entity across services

#### Task 2.1: Define Customer Ownership (CRM Service)

**Location:** `services/customer-relationship/src/main/kotlin/com/chiro/erp/customerrelationship/crm/domain/`

```kotlin
@Entity
@Table(name = "customers", schema = "customerrelationship_schema")
class Customer(
    @Id val id: UUID = UUID.randomUUID(),

    // Identification
    val customerNumber: String, // CUST-2025-000001
    val tenantId: UUID,

    // Profile (OWNED by CRM)
    @Embedded var personalInfo: PersonalInfo,
    @Embedded var contactInfo: ContactInfo,

    // Classification
    @Enumerated(EnumType.STRING)
    var customerType: CustomerType,

    @Enumerated(EnumType.STRING)
    var status: CustomerStatus,

    @Enumerated(EnumType.STRING)
    var segment: CustomerSegment,

    // Credit Info (basic - for business rules)
    @Embedded var creditInfo: CreditInfo,

    // Metadata
    val createdAt: Instant = Instant.now(),
    var updatedAt: Instant = Instant.now(),
    val createdBy: UUID,
    var updatedBy: UUID?,

    @Version var version: Long = 0
) {
    companion object {
        fun create(
            tenantId: UUID,
            personalInfo: PersonalInfo,
            contactInfo: ContactInfo,
            customerType: CustomerType,
            createdBy: UUID
        ): Pair<Customer, List<DomainEvent>> {
            val customer = Customer(
                tenantId = tenantId,
                customerNumber = generateCustomerNumber(),
                personalInfo = personalInfo,
                contactInfo = contactInfo,
                customerType = customerType,
                status = CustomerStatus.ACTIVE,
                segment = CustomerSegment.CONSUMER,
                creditInfo = CreditInfo(),
                createdBy = createdBy
            )

            val events = listOf(
                CustomerCreatedEvent(
                    aggregateId = customer.id,
                    tenantId = tenantId,
                    metadata = EventMetadata(
                        causationId = null,
                        correlationId = UUID.randomUUID(),
                        userId = createdBy,
                        source = "customer-relationship-service"
                    ),
                    customerId = customer.id,
                    customerNumber = customer.customerNumber,
                    customerType = customerType.name,
                    status = CustomerStatus.ACTIVE.name,
                    personalInfo = CustomerPersonalInfo(
                        firstName = personalInfo.firstName,
                        lastName = personalInfo.lastName,
                        email = contactInfo.primaryEmail
                    ),
                    contactInfo = CustomerContactInfo(
                        primaryEmail = contactInfo.primaryEmail,
                        primaryPhone = contactInfo.primaryPhone
                    )
                )
            )

            return Pair(customer, events)
        }

        private fun generateCustomerNumber(): String {
            val year = LocalDate.now().year
            val sequence = String.format("%06d", Random.nextInt(999999))
            return "CUST-$year-$sequence"
        }
    }

    fun updateCreditLimit(
        newLimit: BigDecimal,
        approvedBy: UUID,
        reason: String
    ): List<DomainEvent> {
        val previousLimit = creditInfo.creditLimit
        creditInfo = creditInfo.copy(creditLimit = newLimit)
        updatedAt = Instant.now()
        updatedBy = approvedBy

        return listOf(
            CustomerCreditLimitChangedEvent(
                aggregateId = id,
                tenantId = tenantId,
                metadata = EventMetadata(
                    causationId = null,
                    correlationId = UUID.randomUUID(),
                    userId = approvedBy,
                    source = "customer-relationship-service"
                ),
                customerId = id,
                previousLimit = previousLimit,
                newLimit = newLimit,
                reason = reason,
                approvedBy = approvedBy
            )
        )
    }

    fun changeStatus(
        newStatus: CustomerStatus,
        userId: UUID,
        reason: String?
    ): List<DomainEvent> {
        val previousStatus = status
        status = newStatus
        updatedAt = Instant.now()
        updatedBy = userId

        return listOf(
            CustomerStatusChangedEvent(
                aggregateId = id,
                tenantId = tenantId,
                metadata = EventMetadata(
                    causationId = null,
                    correlationId = UUID.randomUUID(),
                    userId = userId,
                    source = "customer-relationship-service"
                ),
                customerId = id,
                previousStatus = previousStatus.name,
                newStatus = newStatus.name,
                reason = reason
            )
        )
    }
}

// Value Objects
data class PersonalInfo(
    val firstName: String,
    val lastName: String,
    val middleName: String? = null,
    val dateOfBirth: LocalDate? = null
)

data class ContactInfo(
    val primaryEmail: String,
    val primaryPhone: String,
    val secondaryEmail: String? = null,
    val secondaryPhone: String? = null
)

data class CreditInfo(
    val creditLimit: BigDecimal = BigDecimal.ZERO,
    val availableCredit: BigDecimal = BigDecimal.ZERO,
    val creditRating: String? = null
)

// Enums
enum class CustomerType { B2B, B2C, B2G, PARTNER }
enum class CustomerStatus { PROSPECT, ACTIVE, SUSPENDED, INACTIVE, CHURNED }
enum class CustomerSegment { ENTERPRISE, SMB, CONSUMER, VIP }
```

---

#### Task 2.2: Customer Service with Event Publishing

**Location:** `services/customer-relationship/src/main/kotlin/com/chiro/erp/customerrelationship/crm/application/`

```kotlin
@ApplicationScoped
class CustomerService(
    private val customerRepository: CustomerRepository,
    private val eventPublisher: EventPublisher
) {
    private val logger = LoggerFactory.getLogger(javaClass)

    @Transactional
    suspend fun createCustomer(command: CreateCustomerCommand): CustomerDto {
        logger.info("Creating customer for tenant: ${command.tenantId}")

        // Create aggregate and get domain events
        val (customer, events) = Customer.create(
            tenantId = command.tenantId,
            personalInfo = PersonalInfo(
                firstName = command.firstName,
                lastName = command.lastName
            ),
            contactInfo = ContactInfo(
                primaryEmail = command.email,
                primaryPhone = command.phone
            ),
            customerType = CustomerType.valueOf(command.customerType),
            createdBy = command.userId
        )

        // Persist
        customerRepository.persist(customer)

        // Publish domain events
        events.forEach { event ->
            eventPublisher.publish(event)
        }

        return customer.toDto()
    }

    @Transactional
    suspend fun updateCreditLimit(
        customerId: UUID,
        newLimit: BigDecimal,
        approvedBy: UUID,
        reason: String
    ): CustomerDto {
        val customer = customerRepository.findById(customerId)
            ?: throw CustomerNotFoundException(customerId)

        val events = customer.updateCreditLimit(newLimit, approvedBy, reason)

        customerRepository.persist(customer)

        events.forEach { event ->
            eventPublisher.publish(event)
        }

        return customer.toDto()
    }
}
```

---

#### Task 2.3: Financial Service - Customer Reference (NOT Ownership)

**Location:** `services/financial-management/src/main/kotlin/com/chiro/erp/financialmanagement/accounts-receivable/domain/`

```kotlin
@Entity
@Table(name = "customer_accounts", schema = "finance_schema")
class CustomerAccount(
    @Id val id: UUID = UUID.randomUUID(),

    // ⚠️ REFERENCE ONLY - NOT OWNED
    val customerId: UUID,  // References CRM.Customer.id

    // Financial data OWNED by Finance
    val accountNumber: String,
    val tenantId: UUID,

    @Enumerated(EnumType.STRING)
    var accountType: AccountType,

    val currency: String, // ISO 4217

    // Credit management (Finance owns the operational side)
    var creditLimit: BigDecimal = BigDecimal.ZERO,
    var creditUsed: BigDecimal = BigDecimal.ZERO,
    var availableCredit: BigDecimal = BigDecimal.ZERO,

    // Balances
    var totalOutstanding: BigDecimal = BigDecimal.ZERO,
    var currentBalance: BigDecimal = BigDecimal.ZERO,
    var overdueBalance: BigDecimal = BigDecimal.ZERO,

    // Terms
    @Enumerated(EnumType.STRING)
    var paymentTerms: PaymentTerms,

    @Enumerated(EnumType.STRING)
    var creditStatus: CreditStatus,

    // Audit
    val createdAt: Instant = Instant.now(),
    var updatedAt: Instant = Instant.now(),

    @Version var version: Long = 0
) {
    companion object {
        fun createFromCustomerCreatedEvent(
            event: CustomerCreatedEvent
        ): CustomerAccount {
            return CustomerAccount(
                customerId = event.customerId,
                accountNumber = generateAccountNumber(),
                tenantId = event.tenantId,
                accountType = AccountType.STANDARD,
                currency = "USD",
                paymentTerms = PaymentTerms.NET30,
                creditStatus = CreditStatus.GOOD
            )
        }

        private fun generateAccountNumber(): String {
            val year = LocalDate.now().year
            val sequence = String.format("%06d", Random.nextInt(999999))
            return "AR-$year-$sequence"
        }
    }

    fun updateCreditLimitFromEvent(
        newLimit: BigDecimal
    ) {
        creditLimit = newLimit
        availableCredit = creditLimit - creditUsed
        updatedAt = Instant.now()
    }
}

enum class AccountType { STANDARD, PREPAID, CREDIT_ACCOUNT }
enum class PaymentTerms { NET15, NET30, NET60, NET90, DUE_ON_RECEIPT }
enum class CreditStatus { GOOD, WARNING, HOLD, SUSPENDED }
```

---

#### Task 2.4: Financial Service - Event Listener

**Location:** `services/financial-management/src/main/kotlin/com/chiro/erp/financialmanagement/accounts-receivable/infrastructure/`

```kotlin
@ApplicationScoped
class CustomerEventListener(
    private val customerAccountRepository: CustomerAccountRepository,
    private val logger: Logger
) {

    @Incoming("customer-events")
    @Transactional
    suspend fun onCustomerEvent(message: Message<CustomerCreatedEvent>) {
        val event = message.payload

        try {
            logger.info("Received CustomerCreatedEvent: ${event.customerId}")

            // Create corresponding CustomerAccount
            val account = CustomerAccount.createFromCustomerCreatedEvent(event)
            customerAccountRepository.persist(account)

            logger.info(
                "Created CustomerAccount: ${account.id} for Customer: ${event.customerId}"
            )

            message.ack().await()
        } catch (e: Exception) {
            logger.error("Failed to process CustomerCreatedEvent", e)
            message.nack(e).await()
        }
    }

    @Incoming("customer-events")
    @Transactional
    suspend fun onCustomerCreditLimitChanged(
        message: Message<CustomerCreditLimitChangedEvent>
    ) {
        val event = message.payload

        try {
            logger.info(
                "Received CustomerCreditLimitChangedEvent: ${event.customerId}"
            )

            val account = customerAccountRepository.findByCustomerId(event.customerId)
            if (account != null) {
                account.updateCreditLimitFromEvent(event.newLimit)
                customerAccountRepository.persist(account)

                logger.info(
                    "Updated credit limit for account: ${account.id} " +
                    "from ${event.previousLimit} to ${event.newLimit}"
                )
            } else {
                logger.warn("No account found for customer: ${event.customerId}")
            }

            message.ack().await()
        } catch (e: Exception) {
            logger.error("Failed to process CustomerCreditLimitChangedEvent", e)
            message.nack(e).await()
        }
    }
}
```

---

### **Phase 3: Anti-Corruption Layers** (Week 3-4)

**Priority:** 🟡 MEDIUM - Prevents model pollution

#### Task 3.1: Commerce ACL for Customer

**Location:** `services/commerce/src/main/kotlin/com/chiro/erp/commerce/shared/acl/`

```kotlin
/**
 * Anti-Corruption Layer for CRM Customer domain
 * Translates CRM concepts to Commerce concepts
 */
@ApplicationScoped
class CustomerACL(
    private val crmClient: CRMCustomerClient  // HTTP client to CRM service
) {
    private val logger = LoggerFactory.getLogger(javaClass)

    suspend fun toShopperProfile(customerId: UUID): ShopperProfile? {
        return try {
            val crmCustomer = crmClient.getCustomer(customerId)

            ShopperProfile(
                customerId = crmCustomer.id,
                displayName = "${crmCustomer.firstName} ${crmCustomer.lastName}",
                email = crmCustomer.primaryEmail,
                phone = crmCustomer.primaryPhone,
                shoppingPreferences = mapShoppingPreferences(crmCustomer),
                loyaltyTier = mapToLoyaltyTier(crmCustomer.segment),
                // Commerce-specific data (not from CRM)
                cartHistory = emptyList(),
                wishlistItems = emptyList()
            )
        } catch (e: Exception) {
            logger.error("Failed to fetch customer from CRM", e)
            null
        }
    }

    private fun mapShoppingPreferences(
        customer: CRMCustomerDto
    ): ShoppingPreferences {
        return ShoppingPreferences(
            preferredCurrency = "USD",  // Default
            preferredLanguage = "en",
            communicationOptIn = true  // Default
        )
    }

    private fun mapToLoyaltyTier(segment: String): LoyaltyTier {
        return when (segment) {
            "VIP", "ENTERPRISE" -> LoyaltyTier.PLATINUM
            "SMB" -> LoyaltyTier.GOLD
            "CONSUMER" -> LoyaltyTier.SILVER
            else -> LoyaltyTier.BRONZE
        }
    }
}

// Commerce domain model (DIFFERENT from CRM)
data class ShopperProfile(
    val customerId: UUID,
    val displayName: String,
    val email: String,
    val phone: String,
    val shoppingPreferences: ShoppingPreferences,
    val loyaltyTier: LoyaltyTier,
    val cartHistory: List<CartSnapshot>,
    val wishlistItems: List<UUID>
)

data class ShoppingPreferences(
    val preferredCurrency: String,
    val preferredLanguage: String,
    val communicationOptIn: Boolean
)

enum class LoyaltyTier { BRONZE, SILVER, GOLD, PLATINUM }
```

---

### **Phase 4: Reference Data & Configuration** (Week 4)

**Priority:** 🟢 LOW - Nice to have

#### Task 4.1: Core Configuration Service

**Location:** `services/core-platform/src/main/kotlin/com/chiro/erp/coreplatform/configuration/domain/`

```kotlin
@Entity
@Table(name = "currencies", schema = "core_schema")
class Currency(
    @Id val code: String,  // ISO 4217: USD, EUR, GBP
    val name: String,
    val symbol: String,
    val decimalPlaces: Int = 2,
    val isActive: Boolean = true
)

@Entity
@Table(name = "countries", schema = "core_schema")
class Country(
    @Id val code: String,  // ISO 3166-1: US, GB, DE
    val name: String,
    val alpha3Code: String,
    val phoneCode: String,
    val isActive: Boolean = true
)

@ApplicationScoped
class ConfigurationService(
    private val currencyRepository: CurrencyRepository,
    private val countryRepository: CountryRepository
) {
    // Cache for 1 hour
    @CacheResult(cacheName = "currencies")
    suspend fun getAllCurrencies(): List<Currency> {
        return currencyRepository.listAll()
    }

    @CacheResult(cacheName = "countries")
    suspend fun getAllCountries(): List<Country> {
        return countryRepository.listAll()
    }
}
```

---

### **Phase 5: Testing & Validation** (Week 5)

**Priority:** 🔴 CRITICAL - Ensure everything works

#### Task 5.1: Integration Tests

**Location:** `services/customer-relationship/src/test/kotlin/`

```kotlin
@QuarkusTest
@TestTransaction
class CustomerEventIntegrationTest {

    @Inject
    lateinit var customerService: CustomerService

    @Inject
    lateinit var eventPublisher: EventPublisher

    @InjectMock
    lateinit var mockKafka: KafkaEmitter

    @Test
    fun `should publish CustomerCreatedEvent when customer is created`() = runBlocking {
        // Given
        val command = CreateCustomerCommand(
            tenantId = UUID.randomUUID(),
            firstName = "John",
            lastName = "Doe",
            email = "john.doe@example.com",
            phone = "+1234567890",
            customerType = "B2C",
            userId = UUID.randomUUID()
        )

        // When
        val customer = customerService.createCustomer(command)

        // Then
        assertNotNull(customer.id)
        verify(mockKafka, times(1)).send(any<CustomerCreatedEvent>())
    }
}
```

---

## 📋 Implementation Checklist

### Phase 1: Event Infrastructure ⬜

-   [ ] Create `DomainEvent` base interface
-   [ ] Create `CustomerEvents.kt` (Created, CreditLimitChanged, StatusChanged)
-   [ ] Create `OrderEvents.kt` (Placed, Shipped, Completed)
-   [ ] Create `InvoiceEvents.kt` (Created, Sent, Paid)
-   [ ] Create `EventPublisher` service
-   [ ] Configure Kafka topics in all `application.properties`
-   [ ] Test event publishing with unit tests

### Phase 2: Customer Context ⬜

-   [ ] Define `Customer` entity in CRM service (owner)
-   [ ] Create `CustomerService` with event publishing
-   [ ] Define `CustomerAccount` entity in Finance service (reference only)
-   [ ] Create event listener in Finance service
-   [ ] Test customer creation flow end-to-end
-   [ ] Test credit limit update synchronization
-   [ ] Verify eventual consistency

### Phase 3: Anti-Corruption Layers ⬜

-   [ ] Create `CustomerACL` in Commerce service
-   [ ] Create CRM HTTP client interface
-   [ ] Define Commerce-specific domain models
-   [ ] Test ACL translation logic
-   [ ] Document ACL responsibilities

### Phase 4: Reference Data ⬜

-   [ ] Create `Currency` entity in Core Platform
-   [ ] Create `Country` entity in Core Platform
-   [ ] Implement caching strategy
-   [ ] Seed initial reference data
-   [ ] Test cache invalidation

### Phase 5: Testing ⬜

-   [ ] Write integration tests for each service
-   [ ] Test event-driven flows
-   [ ] Test failure scenarios (Kafka down, retry logic)
-   [ ] Load testing for event throughput
-   [ ] Document testing strategy

---

## 🔧 Required Dependencies

Add to all service `build.gradle` files:

```gradle
dependencies {
    // Kafka Reactive Messaging
    implementation("io.quarkus:quarkus-smallrye-reactive-messaging-kafka")
    implementation("io.quarkus:quarkus-kafka-client")

    // JSON serialization
    implementation("io.quarkus:quarkus-jsonb")

    // Redis caching
    implementation("io.quarkus:quarkus-redis-client")
    implementation("io.quarkus:quarkus-cache")

    // HTTP clients for ACL
    implementation("io.quarkus:quarkus-rest-client-reactive")
    implementation("io.quarkus:quarkus-rest-client-reactive-jackson")
}
```

---

## 📈 Success Metrics

After implementation, you should achieve:

1. **Zero Shared Entity Classes** between services
2. **100% Event-Driven Synchronization** for critical entities
3. **< 1 second** event propagation time
4. **Eventual Consistency** across all bounded contexts
5. **Clear ACL Boundaries** preventing model pollution
6. **95%+ Test Coverage** for domain events

---

## 🚀 Quick Start Command

```powershell
# Phase 1 - Create event infrastructure
New-Item -ItemType Directory -Path "services/core-platform/src/main/kotlin/com/chiro/erp/coreplatform/shared/events"

# Generate event files
@"
// DomainEvent.kt
package com.chiro.erp.coreplatform.shared.events

import java.time.Instant
import java.util.UUID

sealed interface DomainEvent {
    val eventId: UUID
    val aggregateId: UUID
    val aggregateType: String
    val eventType: String
    val occurredAt: Instant
    val tenantId: UUID
    val metadata: EventMetadata
}

data class EventMetadata(
    val causationId: UUID?,
    val correlationId: UUID,
    val userId: UUID,
    val source: String,
    val version: Int = 1
)
"@ | Out-File -FilePath "services/core-platform/src/main/kotlin/com/chiro/erp/coreplatform/shared/events/DomainEvent.kt"
```

---

## 📚 Documentation Updates Needed

1. **Create:** `docs/EVENT-DRIVEN-ARCHITECTURE.md`
2. **Update:** `docs/architecture/CONTEXT-MAPPING.md` with event flows
3. **Create:** `docs/ACL-GUIDE.md` for Anti-Corruption Layers
4. **Update:** `MICROSERVICES-README.md` with event infrastructure
5. **Create:** `docs/TESTING-EVENTS.md` for testing strategies

---

## ⚠️ Common Pitfalls to Avoid

1. **DON'T** share entity classes between services via shared libraries
2. **DON'T** use synchronous HTTP calls for data replication
3. **DON'T** create bidirectional dependencies between services
4. **DON'T** forget to handle event ordering issues
5. **DON'T** skip ACLs when integrating contexts
6. **DON'T** store full customer profiles in every service
7. **DON'T** use distributed transactions (2PC)

---

## 🎓 Learning Resources

-   [Domain-Driven Design by Eric Evans](https://www.domainlanguage.com/ddd/)
-   [Implementing Domain-Driven Design by Vaughn Vernon](https://vaughnvernon.com/)
-   [Kafka Event-Driven Microservices](https://www.confluent.io/learn/event-driven-microservices/)
-   [Quarkus Kafka Guide](https://quarkus.io/guides/kafka)
-   [Anti-Corruption Layer Pattern](https://docs.microsoft.com/en-us/azure/architecture/patterns/anti-corruption-layer)

---

## 📞 Next Steps

**Immediate Actions:**

1. Review this plan with the team
2. Set up development environment for Phase 1
3. Create feature branch: `feature/ddd-event-infrastructure`
4. Start with Task 1.1 (Shared Event Library)
5. Schedule daily standups to track progress

**Questions to Answer:**

-   Which entities besides Customer need event-driven sync?
-   What's the acceptable eventual consistency delay?
-   Do we need event sourcing for audit trail?
-   Should we implement outbox pattern for guaranteed delivery?

---

**Status:** 📋 Ready for Implementation
**Estimated Effort:** 5 weeks (1 developer)
**Risk Level:** Medium (solid foundation, clear patterns)
**ROI:** High (enables true microservices scalability)
