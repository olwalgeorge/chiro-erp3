package com.chiro.erp.coreplatform.shared.events

import java.math.BigDecimal
import java.time.Instant
import java.util.UUID

/**
 * Customer aggregate events. These events are published when changes occur to Customer entities.
 */

/**
 * Published when a new customer is created in the CRM system. This is an integration event that
 * other services should subscribe to.
 */
data class CustomerCreatedEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "Customer",
        override val eventType: String = "CustomerCreated",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,

        // Customer-specific payload
        val customerId: UUID,
        val customerNumber: String,
        val customerType: CustomerType,
        val status: CustomerStatus,
        val personalInfo: CustomerPersonalInfo,
        val contactInfo: CustomerContactInfo,
        val businessInfo: CustomerBusinessInfo? = null
) : IntegrationEvent

/**
 * Published when customer's credit limit is changed. Important for financial management and order
 * processing.
 */
data class CustomerCreditLimitChangedEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "Customer",
        override val eventType: String = "CustomerCreditLimitChanged",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val customerId: UUID,
        val previousLimit: BigDecimal,
        val newLimit: BigDecimal,
        val reason: String,
        val approvedBy: UUID
) : IntegrationEvent

/** Published when customer status changes (Active, Suspended, Inactive, etc.). */
data class CustomerStatusChangedEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "Customer",
        override val eventType: String = "CustomerStatusChanged",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val customerId: UUID,
        val previousStatus: CustomerStatus,
        val newStatus: CustomerStatus,
        val reason: String?
) : IntegrationEvent

/** Published when customer contact information is updated. */
data class CustomerContactUpdatedEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "Customer",
        override val eventType: String = "CustomerContactUpdated",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val customerId: UUID,
        val contactInfo: CustomerContactInfo
) : IntegrationEvent

/** Published when customer is assigned to a new account manager or sales rep. */
data class CustomerAssignedEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "Customer",
        override val eventType: String = "CustomerAssigned",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val customerId: UUID,
        val assignedTo: UUID,
        val assignedToName: String,
        val role: String // "AccountManager", "SalesRep"
) : IntegrationEvent

// Value Objects for Customer Events

data class CustomerPersonalInfo(
        val firstName: String,
        val lastName: String,
        val fullName: String,
        val email: String
)

data class CustomerContactInfo(
        val primaryEmail: String,
        val primaryPhone: String,
        val secondaryPhone: String? = null,
        val address: CustomerAddress? = null
)

data class CustomerAddress(
        val street: String,
        val city: String,
        val state: String,
        val postalCode: String,
        val country: String
)

data class CustomerBusinessInfo(
        val companyName: String,
        val taxId: String?,
        val industry: String?,
        val employeeCount: Int?
)

enum class CustomerType {
    B2C, // Business to Consumer
    B2B, // Business to Business
    GOVERNMENT,
    RESELLER,
    PARTNER
}

enum class CustomerStatus {
    ACTIVE,
    INACTIVE,
    SUSPENDED,
    PENDING_APPROVAL,
    BLOCKED
}
