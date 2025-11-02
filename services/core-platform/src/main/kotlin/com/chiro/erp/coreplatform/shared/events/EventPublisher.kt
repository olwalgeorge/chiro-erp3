package com.chiro.erp.coreplatform.shared.events

import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.databind.SerializationFeature
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule
import jakarta.enterprise.context.ApplicationScoped
import jakarta.enterprise.inject.Produces
import jakarta.inject.Inject
import org.eclipse.microprofile.reactive.messaging.Channel
import org.eclipse.microprofile.reactive.messaging.Emitter
import org.jboss.logging.Logger

/**
 * Centralized event publisher for domain events. Handles serialization and routing of events to
 * appropriate Kafka topics.
 */
@ApplicationScoped
class EventPublisher(
        @Channel("domain-events-out") private val domainEventsEmitter: Emitter<String>
) {

    @Inject private lateinit var objectMapper: ObjectMapper

    private val logger = Logger.getLogger(EventPublisher::class.java)

    /** Publishes a domain event to the appropriate Kafka topic. */
    fun publish(event: DomainEvent) {
        try {
            val topic = getTopicForEvent(event)
            val eventJson = serializeEvent(event)

            // Send event to Kafka
            domainEventsEmitter.send(eventJson)

            logger.info(
                    "Published event: ${event.eventType} " +
                            "for aggregate: ${event.aggregateType}/${event.aggregateId} " +
                            "to topic: $topic"
            )
        } catch (e: Exception) {
            logger.error("Failed to publish event: ${event.eventType}", e)
            throw EventPublishingException("Failed to publish event: ${event.eventType}", e)
        }
    }

    /** Publishes multiple events in order. */
    fun publishAll(events: List<DomainEvent>) {
        events.forEach { publish(it) }
    }

    /** Determines the Kafka topic based on the event type. */
    private fun getTopicForEvent(event: DomainEvent): String {
        return when (event) {
            // Customer events
            is CustomerCreatedEvent,
            is CustomerCreditLimitChangedEvent,
            is CustomerStatusChangedEvent,
            is CustomerContactUpdatedEvent,
            is CustomerAssignedEvent -> "crm.customer.events"

            // Order events
            is OrderCreatedEvent,
            is OrderConfirmedEvent,
            is OrderStatusChangedEvent,
            is OrderCancelledEvent,
            is OrderShippedEvent,
            is OrderDeliveredEvent -> "commerce.order.events"

            // Invoice events
            is InvoiceCreatedEvent,
            is InvoiceSentEvent,
            is InvoicePaymentReceivedEvent,
            is InvoicePaidEvent,
            is InvoiceOverdueEvent,
            is InvoiceCancelledEvent,
            is CreditNoteIssuedEvent -> "finance.invoice.events"

            // Inventory events
            is ProductCreatedEvent,
            is InventoryAdjustedEvent,
            is InventoryAllocatedEvent,
            is InventoryReleasedEvent,
            is InventoryLowStockEvent,
            is InventoryOutOfStockEvent,
            is GoodsReceivedEvent,
            is MaterialTransferredEvent -> "supply.inventory.events"

            // Service Order events
            is ServiceOrderCreatedEvent,
            is ServiceOrderAssignedEvent,
            is ServiceOrderScheduledEvent,
            is ServiceOrderStartedEvent,
            is ServiceOrderCompletedEvent,
            is ServiceOrderStatusChangedEvent,
            is ServiceOrderCancelledEvent -> "operations.service-order.events"

            // User events
            is UserCreatedEvent,
            is UserUpdatedEvent,
            is UserActivatedEvent,
            is UserDeactivatedEvent,
            is UserRoleAssignedEvent,
            is UserRoleRevokedEvent -> "platform.user.events"

            // Internal events (not integration events)
            is UserLoggedInEvent,
            is UserPasswordChangedEvent -> "platform.internal.events"

            // Default for unknown events
            else -> "domain.events"
        }
    }

    /** Serializes an event to JSON. */
    private fun serializeEvent(event: DomainEvent): String {
        return objectMapper.writeValueAsString(event)
    }
}

/** Exception thrown when event publishing fails. */
class EventPublishingException(message: String, cause: Throwable? = null) :
        RuntimeException(message, cause)

/** Configuration for Jackson ObjectMapper to handle domain events. */
@ApplicationScoped
class EventSerializationConfig {

    @Produces
    @ApplicationScoped
    fun objectMapper(): ObjectMapper {
        val mapper = ObjectMapper()
        mapper.registerModule(JavaTimeModule())
        mapper.disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS)
        mapper.enable(SerializationFeature.INDENT_OUTPUT)
        return mapper
    }
}
