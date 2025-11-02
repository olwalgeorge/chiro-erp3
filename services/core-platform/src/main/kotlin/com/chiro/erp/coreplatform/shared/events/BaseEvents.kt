package com.chiro.erp.coreplatform.shared.events

import java.time.Instant
import java.util.UUID

/**
 * Base interface for all domain events in the system. Domain events represent something that
 * happened in the domain that is of interest to domain experts.
 */
sealed interface DomainEvent {
    /** Unique identifier for this event instance */
    val eventId: UUID

    /** The ID of the aggregate that this event is related to */
    val aggregateId: UUID

    /** The type of aggregate (e.g., "Customer", "Order", "Invoice") */
    val aggregateType: String

    /** The specific type of this event (e.g., "CustomerCreated", "OrderPlaced") */
    val eventType: String

    /** When this event occurred */
    val occurredAt: Instant

    /** The tenant this event belongs to (for multi-tenancy) */
    val tenantId: UUID

    /** Additional metadata about this event */
    val metadata: EventMetadata
}

/**
 * Integration events are published across bounded contexts/services. They represent a subset of
 * domain events that other services need to know about.
 */
sealed interface IntegrationEvent : DomainEvent

/** Metadata associated with every domain event for traceability and debugging. */
data class EventMetadata(
        /** The ID of the event that caused this event (for event chains) */
        val causationId: UUID? = null,

        /** Correlation ID to track related events across the system */
        val correlationId: UUID,

        /** The user who triggered this event */
        val userId: UUID,

        /** The service/bounded context that published this event */
        val source: String,

        /** Event schema version for evolution handling */
        val version: Int = 1,

        /** Additional custom metadata */
        val additionalData: Map<String, String> = emptyMap()
)

/** Base implementation for domain events with common fields. */
abstract class BaseDomainEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String,
        override val eventType: String,
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata
) : DomainEvent

/** Base implementation for integration events. */
abstract class BaseIntegrationEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String,
        override val eventType: String,
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata
) : IntegrationEvent
