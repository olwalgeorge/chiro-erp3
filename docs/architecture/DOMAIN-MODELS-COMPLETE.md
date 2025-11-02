# Complete Domain Models & Data Modeling Strategy

## Overview

This document provides **comprehensive domain modeling** for the Chiro ERP system following:

-   **Domain-Driven Design (DDD)** principles
-   **Hexagonal Architecture** (Ports & Adapters)
-   **SAP ERP patterns** (FI, MM, CO, SD modules)
-   **Single Database with Schema Separation**
-   **Event-Driven Architecture** with Kafka

## Architecture Principles

### 1. Domain Layer Purity

-   **No Infrastructure Dependencies**: Domain models contain only business logic
-   **Rich Domain Models**: Behavior encapsulated within entities
-   **Value Objects**: Immutable objects representing domain concepts
-   **Aggregates**: Consistency boundaries with aggregate roots

### 2. Hexagonal Architecture Structure

Each domain within a consolidated service follows this structure:

```
services/
└── {service-name}/
    └── src/
        ├── main/
        │   └── kotlin/
        │       └── com/chiro/erp/{service-package}/{domain-name}/
        │           ├── domain/
        │           │   ├── models/          # Entities, Value Objects, Aggregates
        │           │   ├── services/        # Domain services (business rules)
        │           │   └── ports/
        │           │       ├── inbound/     # Use case interfaces
        │           │       └── outbound/    # Repository & external service interfaces
        │           ├── application/         # Use case implementations
        │           ├── infrastructure/
        │           │   ├── persistence/     # JPA repositories, database adapters
        │           │   ├── messaging/       # Kafka event producers/consumers
        │           │   └── external/        # External service integrations
        │           └── interfaces/
        │               ├── rest/            # REST API controllers
        │               ├── graphql/         # GraphQL resolvers (optional)
        │               └── events/          # Event listeners/handlers
        └── test/
            └── kotlin/
                └── com/chiro/erp/{service-package}/{domain-name}/
                    ├── domain/              # Domain logic tests
                    ├── application/         # Use case tests
                    ├── infrastructure/      # Infrastructure tests
                    └── interfaces/          # API integration tests
```

**Key Principles:**

-   **Domain Layer**: Pure business logic, no framework dependencies
-   **Application Layer**: Orchestrates use cases, coordinates domain objects
-   **Infrastructure Layer**: Technical implementations (database, messaging, external APIs)
-   **Interfaces Layer**: Entry points (REST, GraphQL, events)

### 3. Data Modeling Standards

#### Entity Guidelines

```kotlin
// Aggregate Root Example
@Entity
@Table(name = "customers", schema = "crm_schema")
class Customer(
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    val id: UUID = UUID.randomUUID(),

    // Value Object embedded
    @Embedded
    var personalInfo: PersonalInfo,

    @Embedded
    var contactInfo: ContactInfo,

    @Enumerated(EnumType.STRING)
    var status: CustomerStatus,

    // Audit fields
    @Column(nullable = false, updatable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @Column(nullable = false)
    var version: Long = 0
) {
    // Business methods
    fun activate() {
        this.status = CustomerStatus.ACTIVE
        this.updatedAt = Instant.now()
    }

    fun deactivate() {
        require(canDeactivate()) { "Customer cannot be deactivated with active orders" }
        this.status = CustomerStatus.INACTIVE
        this.updatedAt = Instant.now()
    }

    private fun canDeactivate(): Boolean {
        // Business logic here
        return true
    }
}

// Value Object Example
@Embeddable
data class PersonalInfo(
    @Column(nullable = false)
    val firstName: String,

    @Column(nullable = false)
    val lastName: String,

    val middleName: String? = null
) {
    init {
        require(firstName.isNotBlank()) { "First name cannot be blank" }
        require(lastName.isNotBlank()) { "Last name cannot be blank" }
    }

    fun fullName(): String = listOfNotNull(firstName, middleName, lastName).joinToString(" ")
}
```

#### Common Patterns

**1. Audit Trail Pattern**

```kotlin
@MappedSuperclass
abstract class AuditableEntity(
    @Column(nullable = false, updatable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false, updatable = false)
    val createdBy: UUID,

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedBy: UUID
)
```

**2. Soft Delete Pattern**

```kotlin
@MappedSuperclass
abstract class SoftDeletableEntity : AuditableEntity() {
    @Column(nullable = false)
    var isDeleted: Boolean = false

    var deletedAt: Instant? = null
    var deletedBy: UUID? = null

    fun softDelete(userId: UUID) {
        this.isDeleted = true
        this.deletedAt = Instant.now()
        this.deletedBy = userId
    }
}
```

**3. Multi-Tenant Pattern**

```kotlin
@MappedSuperclass
abstract class TenantAwareEntity : AuditableEntity() {
    @Column(nullable = false)
    val tenantId: UUID

    @Column(nullable = false)
    val organizationId: UUID
}
```

**4. Versioning for Optimistic Locking**

```kotlin
@Entity
class VersionedEntity(
    @Id val id: UUID = UUID.randomUUID(),

    @Version
    @Column(nullable = false)
    var version: Long = 0
)
```

---

---

## Consolidated Services Structure

### Service Mapping Overview

Based on the consolidation script (`create-complete-structure.ps1`), here's how 30+ original microservices are organized into 7 consolidated services with 36 domains:

| Consolidated Service           | Domains                                                                                                 | Original Services Mapped |
| ------------------------------ | ------------------------------------------------------------------------------------------------------- | ------------------------ |
| **core-platform**              | security, organization, audit, configuration, notification, integration                                 | 6 services               |
| **administration**             | hr, logistics-transportation, analytics-intelligence, project-management                                | 4 services               |
| **customer-relationship**      | crm, client, provider, subscription, promotion                                                          | 5 services               |
| **operations-service**         | field-service, scheduling, records, repair-rma                                                          | 4 services               |
| **commerce**                   | ecommerce, portal, communication, pos                                                                   | 4 services               |
| **financial-management**       | general-ledger, accounts-payable, accounts-receivable, asset-accounting, tax-engine, expense-management | 6 services               |
| **supply-chain-manufacturing** | production, quality, inventory, product-costing, procurement                                            | 5 services               |

---

## Service 1: Core Platform

**Package**: `com.chiro.erp.coreplatform`
**Schema**: `core_schema`
**Domains**: 6

### Domain 1: Security Domain

**Path**: `services/core-platform/src/main/kotlin/com/chiro/erp/coreplatform/security/`
**Original Service**: `service-security-framework`

#### Aggregates

**User (Aggregate Root)**

```kotlin
@Entity
@Table(name = "users", schema = "core_schema")
class User(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    var username: String,

    @Column(nullable = false, unique = true)
    var email: Email, // Value Object

    @Column(nullable = false)
    var passwordHash: String,

    @Enumerated(EnumType.STRING)
    var status: UserStatus,

    @Column(nullable = false)
    val tenantId: UUID,

    // Role assignments (within aggregate)
    @OneToMany(mappedBy = "user", cascade = [CascadeType.ALL])
    val roleAssignments: MutableSet<UserRoleAssignment> = mutableSetOf(),

    // Multi-factor authentication
    @Embedded
    var mfaSettings: MfaSettings?,

    // Security metadata
    @Embedded
    var securityMetadata: SecurityMetadata,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
) {
    fun assignRole(role: Role, assignedBy: UUID) {
        val assignment = UserRoleAssignment(
            userId = this.id,
            roleId = role.id,
            assignedBy = assignedBy,
            assignedAt = Instant.now()
        )
        roleAssignments.add(assignment)
        updatedAt = Instant.now()
    }

    fun removeRole(roleId: UUID) {
        roleAssignments.removeIf { it.roleId == roleId }
        updatedAt = Instant.now()
    }

    fun hasPermission(permission: String): Boolean {
        return roleAssignments
            .flatMap { it.role.permissions }
            .any { it.name == permission }
    }

    fun enableMfa(method: MfaMethod) {
        this.mfaSettings = MfaSettings(
            enabled = true,
            method = method,
            enabledAt = Instant.now()
        )
        updatedAt = Instant.now()
    }

    fun recordLoginAttempt(successful: Boolean, ipAddress: String) {
        securityMetadata = securityMetadata.recordAttempt(successful, ipAddress)
        updatedAt = Instant.now()
    }
}

enum class UserStatus {
    ACTIVE, INACTIVE, LOCKED, PENDING_VERIFICATION, SUSPENDED
}

@Embeddable
data class MfaSettings(
    val enabled: Boolean,
    @Enumerated(EnumType.STRING)
    val method: MfaMethod,
    val secret: String? = null,
    val enabledAt: Instant
)

enum class MfaMethod {
    TOTP, SMS, EMAIL, AUTHENTICATOR_APP
}

@Embeddable
data class SecurityMetadata(
    var lastLoginAt: Instant? = null,
    var lastLoginIp: String? = null,
    var failedLoginAttempts: Int = 0,
    var lastFailedLoginAt: Instant? = null,
    var accountLockedUntil: Instant? = null
) {
    fun recordAttempt(successful: Boolean, ipAddress: String): SecurityMetadata {
        return if (successful) {
            this.copy(
                lastLoginAt = Instant.now(),
                lastLoginIp = ipAddress,
                failedLoginAttempts = 0,
                accountLockedUntil = null
            )
        } else {
            this.copy(
                failedLoginAttempts = failedLoginAttempts + 1,
                lastFailedLoginAt = Instant.now(),
                accountLockedUntil = if (failedLoginAttempts >= 5)
                    Instant.now().plus(30, ChronoUnit.MINUTES)
                    else null
            )
        }
    }
}
```

**Role**

```kotlin
@Entity
@Table(name = "roles", schema = "core_schema")
class Role(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false)
    var name: String,

    @Column(length = 1000)
    var description: String?,

    @Column(nullable = false)
    val tenantId: UUID,

    @Enumerated(EnumType.STRING)
    var type: RoleType,

    @OneToMany(mappedBy = "role", cascade = [CascadeType.ALL])
    val permissions: MutableSet<RolePermission> = mutableSetOf(),

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now()
) {
    fun grantPermission(permission: Permission) {
        val rolePermission = RolePermission(
            roleId = this.id,
            permissionId = permission.id,
            grantedAt = Instant.now()
        )
        permissions.add(rolePermission)
        updatedAt = Instant.now()
    }

    fun revokePermission(permissionId: UUID) {
        permissions.removeIf { it.permissionId == permissionId }
        updatedAt = Instant.now()
    }
}

enum class RoleType {
    SYSTEM, CUSTOM, DEPARTMENT, PROJECT
}
```

**Permission**

```kotlin
@Entity
@Table(name = "permissions", schema = "core_schema")
class Permission(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val name: String,

    @Column(nullable = false)
    val resource: String,

    @Column(nullable = false)
    @Enumerated(EnumType.STRING)
    val action: PermissionAction,

    @Column(length = 1000)
    var description: String?,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now()
)

enum class PermissionAction {
    CREATE, READ, UPDATE, DELETE, EXECUTE, APPROVE, EXPORT
}
```

#### Value Objects

```kotlin
// Email Value Object
@Embeddable
data class Email(
    @Column(nullable = false)
    val address: String
) {
    init {
        require(address.matches(Regex("^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}\$"))) {
            "Invalid email format: $address"
        }
    }
}
```

#### Domain Events

```kotlin
data class UserCreatedEvent(
    val userId: UUID,
    val tenantId: UUID,
    val username: String,
    val email: String,
    val occurredAt: Instant = Instant.now()
) : DomainEvent

data class UserRoleAssignedEvent(
    val userId: UUID,
    val roleId: UUID,
    val assignedBy: UUID,
    val occurredAt: Instant = Instant.now()
) : DomainEvent

data class UserLoginEvent(
    val userId: UUID,
    val successful: Boolean,
    val ipAddress: String,
    val userAgent: String?,
    val occurredAt: Instant = Instant.now()
) : DomainEvent
```

---

### Domain 2: Organization Domain

**Path**: `services/core-platform/src/main/kotlin/com/chiro/erp/coreplatform/organization/`
**Original Service**: `service-organization-master`

#### Aggregates

**Organization (Aggregate Root)**

```kotlin
@Entity
@Table(name = "organizations", schema = "core_schema")
class Organization(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false)
    var name: String,

    @Column(unique = true)
    var code: String,

    @Embedded
    var address: Address,

    @Enumerated(EnumType.STRING)
    var type: OrganizationType,

    @Enumerated(EnumType.STRING)
    var status: OrganizationStatus,

    // Parent-child hierarchy
    @ManyToOne
    @JoinColumn(name = "parent_id")
    var parent: Organization? = null,

    @OneToMany(mappedBy = "parent")
    val children: MutableSet<Organization> = mutableSetOf(),

    // Departments
    @OneToMany(mappedBy = "organization", cascade = [CascadeType.ALL])
    val departments: MutableSet<Department> = mutableSetOf(),

    // Settings
    @Embedded
    var settings: OrganizationSettings,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
) {
    fun addDepartment(department: Department) {
        departments.add(department)
        department.organization = this
        updatedAt = Instant.now()
    }

    fun activate() {
        this.status = OrganizationStatus.ACTIVE
        updatedAt = Instant.now()
    }

    fun deactivate() {
        this.status = OrganizationStatus.INACTIVE
        updatedAt = Instant.now()
    }

    fun getFullHierarchyPath(): String {
        val path = mutableListOf<String>()
        var current: Organization? = this
        while (current != null) {
            path.add(0, current.name)
            current = current.parent
        }
        return path.joinToString(" > ")
    }
}

enum class OrganizationType {
    HEADQUARTERS, SUBSIDIARY, DIVISION, BRANCH, DEPARTMENT
}

enum class OrganizationStatus {
    ACTIVE, INACTIVE, PENDING, SUSPENDED
}

@Embeddable
data class OrganizationSettings(
    val timezone: String = "UTC",
    val defaultCurrency: String = "USD",
    val locale: String = "en_US",
    val fiscalYearStart: Int = 1 // January
)
```

**Department**

```kotlin
@Entity
@Table(name = "departments", schema = "core_schema")
class Department(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false)
    var name: String,

    @Column(unique = true)
    var code: String,

    @ManyToOne
    @JoinColumn(name = "organization_id", nullable = false)
    var organization: Organization,

    @ManyToOne
    @JoinColumn(name = "parent_department_id")
    var parentDepartment: Department? = null,

    @OneToMany(mappedBy = "parentDepartment")
    val subDepartments: MutableSet<Department> = mutableSetOf(),

    @ManyToOne
    @JoinColumn(name = "manager_id")
    var manager: User? = null,

    @Enumerated(EnumType.STRING)
    var status: DepartmentStatus,

    @Column(length = 1000)
    var description: String?,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now()
)

enum class DepartmentStatus {
    ACTIVE, INACTIVE, RESTRUCTURING
}
```

#### Value Objects

```kotlin
@Embeddable
data class Address(
    @Column(nullable = false)
    val street: String,

    val street2: String? = null,

    @Column(nullable = false)
    val city: String,

    val state: String? = null,

    @Column(nullable = false)
    val postalCode: String,

    @Column(nullable = false)
    val country: String
) {
    fun format(): String {
        val lines = mutableListOf<String>()
        lines.add(street)
        street2?.let { lines.add(it) }
        val cityLine = listOfNotNull(city, state, postalCode).joinToString(", ")
        lines.add(cityLine)
        lines.add(country)
        return lines.joinToString("\n")
    }
}
```

---

### Domain 3: Audit Domain

**Path**: `services/core-platform/src/main/kotlin/com/chiro/erp/coreplatform/audit/`
**Original Service**: `service-audit-logging`

#### Aggregates

**AuditLog (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "audit_logs",
    schema = "core_schema",
    indexes = [
        Index(name = "idx_audit_entity", columnList = "entityType,entityId"),
        Index(name = "idx_audit_user", columnList = "userId"),
        Index(name = "idx_audit_timestamp", columnList = "timestamp")
    ]
)
class AuditLog(
    @Id val id: UUID = UUID.randomUUID(),

    // Who
    @Column(nullable = false)
    val userId: UUID,

    val username: String,

    @Column(nullable = false)
    val tenantId: UUID,

    // What
    @Column(nullable = false)
    @Enumerated(EnumType.STRING)
    val action: AuditAction,

    @Column(nullable = false)
    val entityType: String,

    @Column(nullable = false)
    val entityId: UUID,

    // When
    @Column(nullable = false)
    val timestamp: Instant = Instant.now(),

    // Where
    @Column(nullable = false)
    val ipAddress: String,

    val userAgent: String?,

    // Details
    @Column(columnDefinition = "jsonb")
    val oldValues: String?, // JSON

    @Column(columnDefinition = "jsonb")
    val newValues: String?, // JSON

    @Column(length = 2000)
    val description: String?,

    @Enumerated(EnumType.STRING)
    val severity: AuditSeverity,

    @Enumerated(EnumType.STRING)
    val category: AuditCategory
)

enum class AuditAction {
    CREATE, READ, UPDATE, DELETE,
    LOGIN, LOGOUT, LOGIN_FAILED,
    PERMISSION_GRANTED, PERMISSION_REVOKED,
    EXPORT, IMPORT,
    APPROVE, REJECT,
    ACTIVATE, DEACTIVATE,
    ARCHIVE, RESTORE
}

enum class AuditSeverity {
    INFO, WARNING, CRITICAL
}

enum class AuditCategory {
    SECURITY, DATA, CONFIGURATION, BUSINESS, SYSTEM
}
```

---

### Domain 4: Configuration Domain

**Path**: `services/core-platform/src/main/kotlin/com/chiro/erp/coreplatform/configuration/`
**Original Service**: `service-configuration-management`

**Configuration (Aggregate Root)**

```kotlin
@Entity
@Table(name = "configurations", schema = "core_schema")
class Configuration(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val key: String,

    @Column(nullable = false, columnDefinition = "jsonb")
    var value: String, // JSON value

    @Enumerated(EnumType.STRING)
    val valueType: ConfigValueType,

    @Column(length = 1000)
    var description: String?,

    @Column(nullable = false)
    val tenantId: UUID?,

    @Column(nullable = false)
    val scope: ConfigScope,

    @Column(nullable = false)
    var isEncrypted: Boolean = false,

    @Column(nullable = false)
    var isReadOnly: Boolean = false,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
) {
    fun updateValue(newValue: String, updatedBy: UUID) {
        require(!isReadOnly) { "Configuration $key is read-only" }
        this.value = newValue
        this.updatedAt = Instant.now()
    }
}

enum class ConfigValueType {
    STRING, INTEGER, BOOLEAN, JSON, SECRET
}

enum class ConfigScope {
    GLOBAL, TENANT, ORGANIZATION, USER
}
```

---

### Domain 5: Notification Domain

**Path**: `services/core-platform/src/main/kotlin/com/chiro/erp/coreplatform/notification/`
**Original Service**: `service-notification-engine`

**Notification (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "notifications",
    schema = "core_schema",
    indexes = [
        Index(name = "idx_notif_recipient", columnList = "recipientId,status"),
        Index(name = "idx_notif_created", columnList = "createdAt")
    ]
)
class Notification(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false)
    val recipientId: UUID,

    @Column(nullable = false)
    val tenantId: UUID,

    @Enumerated(EnumType.STRING)
    val type: NotificationType,

    @Enumerated(EnumType.STRING)
    val channel: NotificationChannel,

    @Column(nullable = false)
    val title: String,

    @Column(length = 4000)
    val body: String,

    @Column(columnDefinition = "jsonb")
    val metadata: String?, // JSON

    @Enumerated(EnumType.STRING)
    var status: NotificationStatus = NotificationStatus.PENDING,

    @Enumerated(EnumType.STRING)
    val priority: NotificationPriority = NotificationPriority.NORMAL,

    var sentAt: Instant? = null,
    var readAt: Instant? = null,

    val expiresAt: Instant? = null,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
) {
    fun markAsSent() {
        this.status = NotificationStatus.SENT
        this.sentAt = Instant.now()
    }

    fun markAsRead() {
        this.status = NotificationStatus.READ
        this.readAt = Instant.now()
    }

    fun markAsFailed(errorMessage: String) {
        this.status = NotificationStatus.FAILED
    }

    fun isExpired(): Boolean {
        return expiresAt?.isBefore(Instant.now()) ?: false
    }
}

enum class NotificationType {
    SYSTEM, ALERT, INFO, WARNING, ERROR, PROMOTIONAL
}

enum class NotificationChannel {
    IN_APP, EMAIL, SMS, PUSH, WEBHOOK
}

enum class NotificationStatus {
    PENDING, SENT, DELIVERED, READ, FAILED, EXPIRED
}

enum class NotificationPriority {
    LOW, NORMAL, HIGH, URGENT
}
```

---

### Domain 6: Integration Domain

**Path**: `services/core-platform/src/main/kotlin/com/chiro/erp/coreplatform/integration/`
**Original Service**: `service-integration-platform`

#### Purpose

-   API Gateway patterns
-   Event-driven integration
-   Service mesh capabilities
-   Circuit breaker and resilience patterns

---

## Service 2: Customer Relationship

**Package**: `com.chiro.erp.customerrelationship`
**Schema**: `crm_schema`
**Domains**: 5

### Domain 1: CRM Domain

**Path**: `services/customer-relationship/src/main/kotlin/com/chiro/erp/customerrelationship/crm/`
**Original Service**: `service-crm`

#### Aggregates

**Customer (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "customers",
    schema = "crm_schema",
    indexes = [
        Index(name = "idx_customer_email", columnList = "email"),
        Index(name = "idx_customer_status", columnList = "status")
    ]
)
class Customer(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false)
    val customerNumber: String, // Auto-generated unique identifier

    @Embedded
    var personalInfo: PersonalInfo,

    @Embedded
    var contactInfo: ContactInfo,

    @Enumerated(EnumType.STRING)
    var type: CustomerType,

    @Enumerated(EnumType.STRING)
    var status: CustomerStatus,

    @Enumerated(EnumType.STRING)
    var segment: CustomerSegment,

    // Company info (for B2B)
    var companyName: String? = null,
    var companyTaxId: String? = null,

    // Preferences
    @Embedded
    var preferences: CustomerPreferences,

    // Credit management
    @Embedded
    var creditInfo: CreditInfo,

    // Lifecycle
    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
) {
    companion object {
        fun generateCustomerNumber(): String {
            return "CUST-${System.currentTimeMillis()}-${(1000..9999).random()}"
        }
    }

    fun activate() {
        this.status = CustomerStatus.ACTIVE
        this.updatedAt = Instant.now()
    }

    fun suspend(reason: String) {
        this.status = CustomerStatus.SUSPENDED
        this.updatedAt = Instant.now()
    }

    fun updateSegment(newSegment: CustomerSegment) {
        this.segment = newSegment
        this.updatedAt = Instant.now()
    }

    fun increaseCreditLimit(amount: BigDecimal, approvedBy: UUID) {
        require(amount > BigDecimal.ZERO) { "Amount must be positive" }
        creditInfo = creditInfo.increaseLimit(amount)
        updatedAt = Instant.now()
    }
}

enum class CustomerType {
    B2C, B2B, B2B2C
}

enum class CustomerStatus {
    PROSPECT, LEAD, ACTIVE, INACTIVE, SUSPENDED, CHURNED
}

enum class CustomerSegment {
    PREMIUM, STANDARD, BASIC, VIP, ENTERPRISE
}

@Embeddable
data class PersonalInfo(
    @Column(nullable = false)
    val firstName: String,

    @Column(nullable = false)
    val lastName: String,

    val middleName: String? = null,

    val salutation: String? = null,

    val dateOfBirth: LocalDate? = null,

    @Enumerated(EnumType.STRING)
    val gender: Gender? = null
) {
    fun fullName(): String = listOfNotNull(salutation, firstName, middleName, lastName)
        .joinToString(" ")
}

enum class Gender {
    MALE, FEMALE, OTHER, PREFER_NOT_TO_SAY
}

@Embeddable
data class ContactInfo(
    @Column(nullable = false, unique = true)
    val email: String,

    val phone: String? = null,

    val mobile: String? = null,

    val fax: String? = null,

    @Embedded
    @AttributeOverrides(
        AttributeOverride(name = "street", column = Column(name = "billing_street")),
        AttributeOverride(name = "street2", column = Column(name = "billing_street2")),
        AttributeOverride(name = "city", column = Column(name = "billing_city")),
        AttributeOverride(name = "state", column = Column(name = "billing_state")),
        AttributeOverride(name = "postalCode", column = Column(name = "billing_postal_code")),
        AttributeOverride(name = "country", column = Column(name = "billing_country"))
    )
    val billingAddress: Address?,

    @Embedded
    @AttributeOverrides(
        AttributeOverride(name = "street", column = Column(name = "shipping_street")),
        AttributeOverride(name = "street2", column = Column(name = "shipping_street2")),
        AttributeOverride(name = "city", column = Column(name = "shipping_city")),
        AttributeOverride(name = "state", column = Column(name = "shipping_state")),
        AttributeOverride(name = "postalCode", column = Column(name = "shipping_postal_code")),
        AttributeOverride(name = "country", column = Column(name = "shipping_country"))
    )
    val shippingAddress: Address?
)

@Embeddable
data class CustomerPreferences(
    val preferredLanguage: String = "en",
    val preferredCurrency: String = "USD",
    val timezone: String = "UTC",
    val emailOptIn: Boolean = true,
    val smsOptIn: Boolean = false,
    val marketingOptIn: Boolean = true
)

@Embeddable
data class CreditInfo(
    val creditLimit: BigDecimal = BigDecimal.ZERO,
    val availableCredit: BigDecimal = BigDecimal.ZERO,
    val paymentTermsDays: Int = 30,
    val creditRating: String? = null
) {
    fun increaseLimit(amount: BigDecimal): CreditInfo {
        return this.copy(
            creditLimit = creditLimit + amount,
            availableCredit = availableCredit + amount
        )
    }

    fun decreaseLimit(amount: BigDecimal): CreditInfo {
        require(creditLimit - amount >= BigDecimal.ZERO) {
            "Credit limit cannot be negative"
        }
        return this.copy(
            creditLimit = creditLimit - amount,
            availableCredit = (availableCredit - amount).coerceAtLeast(BigDecimal.ZERO)
        )
    }
}
```

**Lead (Aggregate Root)**

```kotlin
@Entity
@Table(name = "leads", schema = "crm_schema")
class Lead(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false)
    val leadNumber: String,

    @Embedded
    var contactInfo: LeadContactInfo,

    @Column(nullable = false)
    var companyName: String? = null,

    @Enumerated(EnumType.STRING)
    var status: LeadStatus,

    @Enumerated(EnumType.STRING)
    var source: LeadSource,

    @Enumerated(EnumType.STRING)
    var priority: Priority,

    @Column(nullable = false)
    var estimatedValue: BigDecimal? = null,

    @Column(nullable = false)
    val currency: String = "USD",

    @ManyToOne
    @JoinColumn(name = "assigned_to")
    var assignedTo: UUID? = null,

    var qualificationDate: Instant? = null,
    var conversionDate: Instant? = null,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now()
) {
    fun qualify() {
        require(status == LeadStatus.NEW || status == LeadStatus.CONTACTED) {
            "Lead can only be qualified from NEW or CONTACTED status"
        }
        this.status = LeadStatus.QUALIFIED
        this.qualificationDate = Instant.now()
        this.updatedAt = Instant.now()
    }

    fun convertToOpportunity(): UUID {
        require(status == LeadStatus.QUALIFIED) {
            "Lead must be qualified before conversion"
        }
        this.status = LeadStatus.CONVERTED
        this.conversionDate = Instant.now()
        this.updatedAt = Instant.now()
        return UUID.randomUUID() // Return new opportunity ID
    }

    fun disqualify(reason: String) {
        this.status = LeadStatus.DISQUALIFIED
        this.updatedAt = Instant.now()
    }
}

enum class LeadStatus {
    NEW, CONTACTED, QUALIFIED, CONVERTED, DISQUALIFIED, DEAD
}

enum class LeadSource {
    WEBSITE, REFERRAL, SOCIAL_MEDIA, EMAIL_CAMPAIGN, TRADE_SHOW, COLD_CALL, PARTNER, OTHER
}

enum class Priority {
    LOW, MEDIUM, HIGH, CRITICAL
}

@Embeddable
data class LeadContactInfo(
    @Column(nullable = false)
    val firstName: String,

    @Column(nullable = false)
    val lastName: String,

    @Column(nullable = false)
    val email: String,

    val phone: String? = null,

    val jobTitle: String? = null
)
```

**Opportunity (Aggregate Root)**

```kotlin
@Entity
@Table(name = "opportunities", schema = "crm_schema")
class Opportunity(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false)
    val opportunityNumber: String,

    @Column(nullable = false)
    var name: String,

    @ManyToOne
    @JoinColumn(name = "customer_id")
    val customer: Customer,

    @Enumerated(EnumType.STRING)
    var stage: OpportunityStage,

    @Column(nullable = false, precision = 19, scale = 2)
    var amount: BigDecimal,

    @Column(nullable = false)
    val currency: String = "USD",

    @Column(nullable = false)
    var probability: Int = 0, // 0-100%

    var expectedCloseDate: LocalDate,

    var actualCloseDate: LocalDate? = null,

    @Enumerated(EnumType.STRING)
    var type: OpportunityType,

    @ManyToOne
    @JoinColumn(name = "assigned_to")
    var owner: UUID,

    @Column(length = 2000)
    var description: String? = null,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
) {
    fun advanceStage() {
        val nextStage = when (stage) {
            OpportunityStage.QUALIFICATION -> OpportunityStage.NEEDS_ANALYSIS
            OpportunityStage.NEEDS_ANALYSIS -> OpportunityStage.PROPOSAL
            OpportunityStage.PROPOSAL -> OpportunityStage.NEGOTIATION
            OpportunityStage.NEGOTIATION -> OpportunityStage.CLOSED_WON
            else -> stage
        }
        this.stage = nextStage
        updateProbabilityBasedOnStage()
        this.updatedAt = Instant.now()
    }

    fun close(won: Boolean) {
        this.stage = if (won) OpportunityStage.CLOSED_WON else OpportunityStage.CLOSED_LOST
        this.actualCloseDate = LocalDate.now()
        this.probability = if (won) 100 else 0
        this.updatedAt = Instant.now()
    }

    private fun updateProbabilityBasedOnStage() {
        this.probability = when (stage) {
            OpportunityStage.QUALIFICATION -> 10
            OpportunityStage.NEEDS_ANALYSIS -> 25
            OpportunityStage.PROPOSAL -> 50
            OpportunityStage.NEGOTIATION -> 75
            OpportunityStage.CLOSED_WON -> 100
            OpportunityStage.CLOSED_LOST -> 0
        }
    }

    fun calculateWeightedValue(): BigDecimal {
        return amount.multiply(BigDecimal(probability)).divide(BigDecimal(100))
    }
}

enum class OpportunityStage {
    QUALIFICATION,
    NEEDS_ANALYSIS,
    PROPOSAL,
    NEGOTIATION,
    CLOSED_WON,
    CLOSED_LOST
}

enum class OpportunityType {
    NEW_BUSINESS, EXISTING_BUSINESS, RENEWAL, UPSELL, CROSS_SELL
}
```

---

### Domain 2: Client Domain

**Path**: `services/customer-relationship/src/main/kotlin/com/chiro/erp/customerrelationship/client/`
**Original Service**: `service-client-management`

#### Purpose

-   Customer master data management
-   Client segmentation and profiling
-   Customer preferences and settings

---

### Domain 3: Provider Domain

**Path**: `services/customer-relationship/src/main/kotlin/com/chiro/erp/customerrelationship/provider/`
**Original Service**: `service-provider-management`

#### Purpose

-   Vendor/supplier relationship management
-   Provider evaluation and ratings
-   Contract management with providers

---

### Domain 4: Subscription Domain

**Path**: `services/customer-relationship/src/main/kotlin/com/chiro/erp/customerrelationship/subscription/`
**Original Service**: `service-subscriptions`

#### Purpose

-   Subscription lifecycle management
-   Recurring billing and renewals
-   Subscription plans and tiers

---

### Domain 5: Promotion Domain

**Path**: `services/customer-relationship/src/main/kotlin/com/chiro/erp/customerrelationship/promotion/`
**Original Service**: `service-retail-promotions`

#### Purpose

-   Marketing campaigns and promotions
-   Discount rules and coupons
-   Loyalty programs

---

## Service 3: Operations Service

**Package**: `com.chiro.erp.operationsservice`
**Schema**: `operations_schema`
**Domains**: 4

### Domain 1: Field Service Domain

**Path**: `services/operations-service/src/main/kotlin/com/chiro/erp/operationsservice/field-service/`
**Original Service**: `service-field-service-management`

#### Purpose

-   Service dispatch and technician management
-   SLA tracking and compliance
-   Mobile workforce coordination

---

### Domain 2: Scheduling Domain

**Path**: `services/operations-service/src/main/kotlin/com/chiro/erp/operationsservice/scheduling/`
**Original Service**: `service-resource-scheduling`

#### Purpose

-   Resource scheduling and optimization
-   Capacity planning
-   Appointment management

---

### Domain 3: Records Domain

**Path**: `services/operations-service/src/main/kotlin/com/chiro/erp/operationsservice/records/`
**Original Service**: `service-records-management`

#### Purpose

-   Service history and records
-   Knowledge management
-   Documentation and compliance

---

### Domain 4: Repair RMA Domain

**Path**: `services/operations-service/src/main/kotlin/com/chiro/erp/operationsservice/repair-rma/`
**Original Service**: `service-repair-rma`

#### Purpose

-   Repair workflows and tracking
-   Return merchandise authorization
-   Warranty management

---

## Service 4: Commerce

**Package**: `com.chiro.erp.commerce`
**Schema**: `commerce_schema`
**Domains**: 4

### Domain 1: E-Commerce Domain

**Path**: `services/commerce/src/main/kotlin/com/chiro/erp/commerce/ecommerce/`
**Original Service**: `service-ecomm-storefront`

#### Purpose

-   Online storefront and product catalog
-   Shopping cart and checkout
-   Order management

---

### Domain 2: Portal Domain

**Path**: `services/commerce/src/main/kotlin/com/chiro/erp/commerce/portal/`
**Original Service**: `service-customer-portal`

#### Purpose

-   Customer self-service portal
-   Account management
-   Order tracking and history

---

### Domain 3: Communication Domain

**Path**: `services/commerce/src/main/kotlin/com/chiro/erp/commerce/communication/`
**Original Service**: `service-communication-portal`

#### Purpose

-   Customer communication hub
-   Multi-channel messaging
-   Communication preferences

---

### Domain 4: POS Domain

**Path**: `services/commerce/src/main/kotlin/com/chiro/erp/commerce/pos/`
**Original Service**: `service-point-of-sale`

#### Purpose

-   Point-of-sale transactions
-   In-store payment processing
-   Receipt and invoice generation

---

## Service 5: Financial Management

**Package**: `com.chiro.erp.financialmanagement`
**Schema**: `finance_schema`
**Domains**: 6 (SAP FI Module Alignment)

### Domain 1: General Ledger Domain

**Path**: `services/financial-management/src/main/kotlin/com/chiro/erp/financialmanagement/general-ledger/`
**Original Service**: `service-accounting-core`

#### Purpose

-   Chart of accounts management
-   Journal entries and postings
-   Financial statements and reporting
-   Single source of financial truth

---

### Domain 2: Accounts Payable Domain

**Path**: `services/financial-management/src/main/kotlin/com/chiro/erp/financialmanagement/accounts-payable/`
**Original Service**: `service-ap-automation`

#### Purpose

-   Vendor invoice processing
-   Payment processing and scheduling
-   Three-way matching (PO, receipt, invoice)
-   Vendor payment terms

---

### Domain 3: Accounts Receivable Domain

**Path**: `services/financial-management/src/main/kotlin/com/chiro/erp/financialmanagement/accounts-receivable/`
**Original Service**: `service-billing-invoicing`

#### Purpose

-   Customer invoicing
-   Payment collections
-   Credit management
-   Aging reports

---

### Domain 4: Asset Accounting Domain

**Path**: `services/financial-management/src/main/kotlin/com/chiro/erp/financialmanagement/asset-accounting/`
**Original Service**: `service-asset-management`

#### Purpose

-   Fixed assets management
-   Depreciation calculations
-   Asset lifecycle tracking
-   Asset valuation

---

### Domain 5: Tax Engine Domain

**Path**: `services/financial-management/src/main/kotlin/com/chiro/erp/financialmanagement/tax-engine/`
**Original Service**: `service-tax-compliance`

#### Purpose

-   Tax calculations (sales, VAT, GST)
-   Multi-jurisdiction tax compliance
-   Tax reporting and filings
-   Tax exemptions and rules

---

### Domain 6: Expense Management Domain

**Path**: `services/financial-management/src/main/kotlin/com/chiro/erp/financialmanagement/expense-management/`
**Original Service**: `service-expense-reports`

#### Purpose

-   Employee expense submissions
-   Approval workflows
-   Reimbursement processing
-   Expense policy enforcement

---

## Service 6: Supply Chain Manufacturing

**Package**: `com.chiro.erp.supplychainmanufacturing`
**Schema**: `supply_chain_schema`
**Domains**: 5 (SAP MM/CO Module Alignment)

### Domain 1: Production Domain

**Path**: `services/supply-chain-manufacturing/src/main/kotlin/com/chiro/erp/supplychainmanufacturing/production/`
**Original Service**: `service-mrp-production`

#### Purpose

-   Material requirements planning (MRP)
-   Manufacturing execution
-   Work orders and scheduling
-   Capacity planning

---

### Domain 2: Quality Domain

**Path**: `services/supply-chain-manufacturing/src/main/kotlin/com/chiro/erp/supplychainmanufacturing/quality/`
**Original Service**: `service-quality-management`

#### Purpose

-   Quality management system (QMS)
-   Testing and inspections
-   Corrective and preventive actions (CAPA)
-   Quality compliance

---

### Domain 3: Inventory Domain

**Path**: `services/supply-chain-manufacturing/src/main/kotlin/com/chiro/erp/supplychainmanufacturing/inventory/`
**Original Service**: `service-inventory-management`

#### Purpose

-   Stock management and tracking
-   Warehouse locations and zones
-   Inventory valuation methods
-   Stock movements and adjustments

---

### Domain 4: Product Costing Domain

**Path**: `services/supply-chain-manufacturing/src/main/kotlin/com/chiro/erp/supplychainmanufacturing/product-costing/`
**Original Service**: `service-cost-accounting`

#### Purpose (SAP CO Alignment)

-   Standard costing and actual costs
-   Cost variance analysis
-   Product cost calculations
-   Cost center accounting

---

### Domain 5: Procurement Domain

**Path**: `services/supply-chain-manufacturing/src/main/kotlin/com/chiro/erp/supplychainmanufacturing/procurement/`
**Original Service**: `service-procurement-management`

#### Purpose (SAP MM Alignment)

-   Strategic sourcing
-   Purchase orders and requisitions
-   Vendor management
-   Goods receipt and invoice verification

---

## Service 7: Administration

**Package**: `com.chiro.erp.administration`
**Schema**: `admin_schema`
**Domains**: 4

### Domain 1: HR Domain

**Path**: `services/administration/src/main/kotlin/com/chiro/erp/administration/hr/`
**Original Service**: `service-hr-management`

#### Purpose

-   Human resources management
-   Employee lifecycle
-   Payroll integration
-   Performance management

---

### Domain 2: Logistics & Transportation Domain

**Path**: `services/administration/src/main/kotlin/com/chiro/erp/administration/logistics-transportation/`
**Original Service**: `service-logistics-transportation`

#### Purpose

-   Fleet management
-   Transportation management
-   Route optimization
-   Carrier management

---

### Domain 3: Analytics & Intelligence Domain

**Path**: `services/administration/src/main/kotlin/com/chiro/erp/administration/analytics-intelligence/`
**Original Service**: `service-analytics-intelligence`

#### Purpose

-   Business intelligence and analytics
-   Data products and ETL
-   Machine learning and AI
-   Reporting and dashboards

---

### Domain 4: Project Management Domain

**Path**: `services/administration/src/main/kotlin/com/chiro/erp/administration/project-management/`
**Original Service**: `service-project-management`

#### Purpose

-   Project planning and tracking
-   Resource allocation
-   Budget management
-   Milestone tracking

---

## Migration Guide

### Step 1: Domain Identification

Review the script's domain mapping to identify which original service maps to which domain in the new structure.

### Step 2: Create Domain Structure

Run the `create-complete-structure.ps1` script to generate the hexagonal architecture directories for all domains.

### Step 3: Migrate Domain Models

For each domain:

1. Copy entity classes from `archived-original-structure/{original-service}/src/main/kotlin/`
2. Place in `services/{service-name}/src/main/kotlin/com/chiro/erp/{service-package}/{domain-name}/domain/models/`
3. Update package references
4. Apply multi-tenancy and audit patterns

### Step 4: Define Ports

1. Create inbound ports (use cases) in `domain/ports/inbound/`
2. Create outbound ports (repositories) in `domain/ports/outbound/`

### Step 5: Implement Application Layer

1. Implement use cases in `application/`
2. Coordinate domain services and repositories

### Step 6: Add Infrastructure Adapters

1. Implement JPA repositories in `infrastructure/persistence/`
2. Add Kafka event handlers in `infrastructure/messaging/`
3. Integrate external services in `infrastructure/external/`

### Step 7: Create REST APIs

1. Add REST controllers in `interfaces/rest/`
2. Create DTOs for request/response
3. Wire to application services

---

## Summary

This consolidated structure provides:

-   **7 Enterprise Services** (reduced from 30+ microservices)
-   **36 Bounded Domains** following DDD principles
-   **Hexagonal Architecture** for each domain
-   **Clear separation of concerns** (domain, application, infrastructure, interfaces)
-   **SAP-aligned patterns** for Financial Management (FI) and Supply Chain (MM/CO)
-   **Enterprise-grade security** and audit capabilities
-   **Scalable and maintainable** architecture

The structure follows world-class ERP patterns while maintaining microservices flexibility and modern architectural principles.
