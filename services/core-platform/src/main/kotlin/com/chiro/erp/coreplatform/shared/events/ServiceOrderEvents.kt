package com.chiro.erp.coreplatform.shared.events

import java.math.BigDecimal
import java.time.Instant
import java.time.LocalDate
import java.util.UUID

/** Service Order events for field service and operations management. */

/** Published when a new service order is created. */
data class ServiceOrderCreatedEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "ServiceOrder",
        override val eventType: String = "ServiceOrderCreated",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val serviceOrderId: UUID,
        val serviceOrderNumber: String,
        val customerId: UUID,
        val serviceType: ServiceType,
        val priority: ServicePriority,
        val status: ServiceOrderStatus,
        val requestedDate: LocalDate,
        val description: String,
        val location: ServiceLocation
) : IntegrationEvent

/** Published when a service order is assigned to a technician. */
data class ServiceOrderAssignedEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "ServiceOrder",
        override val eventType: String = "ServiceOrderAssigned",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val serviceOrderId: UUID,
        val serviceOrderNumber: String,
        val technicianId: UUID,
        val technicianName: String,
        val assignedAt: Instant,
        val scheduledDate: LocalDate?,
        val estimatedDuration: Int? // in minutes
) : IntegrationEvent

/** Published when a service order is scheduled. */
data class ServiceOrderScheduledEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "ServiceOrder",
        override val eventType: String = "ServiceOrderScheduled",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val serviceOrderId: UUID,
        val serviceOrderNumber: String,
        val scheduledDate: LocalDate,
        val scheduledStartTime: Instant,
        val scheduledEndTime: Instant,
        val technicianId: UUID
) : IntegrationEvent

/** Published when work starts on a service order. */
data class ServiceOrderStartedEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "ServiceOrder",
        override val eventType: String = "ServiceOrderStarted",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val serviceOrderId: UUID,
        val serviceOrderNumber: String,
        val technicianId: UUID,
        val startedAt: Instant,
        val location: ServiceLocation
) : IntegrationEvent

/** Published when a service order is completed. */
data class ServiceOrderCompletedEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "ServiceOrder",
        override val eventType: String = "ServiceOrderCompleted",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val serviceOrderId: UUID,
        val serviceOrderNumber: String,
        val technicianId: UUID,
        val completedAt: Instant,
        val actualDuration: Int, // in minutes
        val workPerformed: String,
        val partsUsed: List<PartUsed>,
        val laborHours: BigDecimal,
        val totalCost: BigDecimal
) : IntegrationEvent

/** Published when a service order status changes. */
data class ServiceOrderStatusChangedEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "ServiceOrder",
        override val eventType: String = "ServiceOrderStatusChanged",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val serviceOrderId: UUID,
        val serviceOrderNumber: String,
        val previousStatus: ServiceOrderStatus,
        val newStatus: ServiceOrderStatus,
        val reason: String?
) : IntegrationEvent

/** Published when a service order is cancelled. */
data class ServiceOrderCancelledEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "ServiceOrder",
        override val eventType: String = "ServiceOrderCancelled",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val serviceOrderId: UUID,
        val serviceOrderNumber: String,
        val reason: String,
        val cancelledBy: UUID
) : IntegrationEvent

// Value Objects for Service Order Events

data class ServiceLocation(
        val address: String,
        val city: String,
        val state: String,
        val postalCode: String,
        val coordinates: GeoCoordinates?
)

data class GeoCoordinates(val latitude: Double, val longitude: Double)

data class PartUsed(
        val partId: UUID,
        val partCode: String,
        val partName: String,
        val quantity: BigDecimal,
        val unitCost: BigDecimal
)

enum class ServiceType {
    INSTALLATION,
    MAINTENANCE,
    REPAIR,
    INSPECTION,
    EMERGENCY,
    PREVENTIVE,
    CORRECTIVE,
    CONSULTATION
}

enum class ServicePriority {
    LOW,
    NORMAL,
    HIGH,
    URGENT,
    CRITICAL
}

enum class ServiceOrderStatus {
    NEW,
    SCHEDULED,
    DISPATCHED,
    IN_PROGRESS,
    ON_HOLD,
    COMPLETED,
    CANCELLED,
    AWAITING_PARTS,
    REQUIRES_APPROVAL
}
