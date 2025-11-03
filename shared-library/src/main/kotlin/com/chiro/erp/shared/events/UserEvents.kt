package com.chiro.erp.shared.events

import java.time.Instant
import java.util.UUID

/** User and Identity Management events. */

/** Published when a new user is created in the system. */
data class UserCreatedEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "User",
        override val eventType: String = "UserCreated",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val userId: UUID,
        val username: String,
        val email: String,
        val firstName: String,
        val lastName: String,
        val roles: List<String>,
        val status: UserStatus
) : IntegrationEvent

/** Published when a user's profile is updated. */
data class UserUpdatedEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "User",
        override val eventType: String = "UserUpdated",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val userId: UUID,
        val changes: Map<String, String>
) : IntegrationEvent

/** Published when a user is activated. */
data class UserActivatedEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "User",
        override val eventType: String = "UserActivated",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val userId: UUID,
        val username: String,
        val activatedBy: UUID
) : IntegrationEvent

/** Published when a user is deactivated. */
data class UserDeactivatedEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "User",
        override val eventType: String = "UserDeactivated",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val userId: UUID,
        val username: String,
        val reason: String?,
        val deactivatedBy: UUID
) : IntegrationEvent

/** Published when a user's role is assigned. */
data class UserRoleAssignedEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "User",
        override val eventType: String = "UserRoleAssigned",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val userId: UUID,
        val username: String,
        val roleId: UUID,
        val roleName: String,
        val assignedBy: UUID
) : IntegrationEvent

/** Published when a user's role is revoked. */
data class UserRoleRevokedEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "User",
        override val eventType: String = "UserRoleRevoked",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val userId: UUID,
        val username: String,
        val roleId: UUID,
        val roleName: String,
        val revokedBy: UUID
) : IntegrationEvent

/** Published when a user successfully logs in. */
data class UserLoggedInEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "User",
        override val eventType: String = "UserLoggedIn",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val userId: UUID,
        val username: String,
        val ipAddress: String?,
        val userAgent: String?
) : DomainEvent // Not an integration event - internal only

/** Published when a user password is changed. */
data class UserPasswordChangedEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "User",
        override val eventType: String = "UserPasswordChanged",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val userId: UUID,
        val username: String,
        val changedBy: UUID // Could be self or admin
) : DomainEvent // Not an integration event - internal only

enum class UserStatus {
    ACTIVE,
    INACTIVE,
    LOCKED,
    PENDING_ACTIVATION,
    SUSPENDED
}
