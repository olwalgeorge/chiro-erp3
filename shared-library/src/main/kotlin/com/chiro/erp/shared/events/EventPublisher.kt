package com.chiro.erp.shared.events

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
 *
 * Each service should configure the necessary Kafka channels in application.properties. The
 * publisher routes events to the correct topic-specific channel.
 */
@ApplicationScoped
class EventPublisher {

    @Inject private lateinit var objectMapper: ObjectMapper

    private val logger = Logger.getLogger(EventPublisher::class.java)

    // Topic-specific emitters - services only need to configure the topics they publish to
    @Inject
    @Channel("crm-customer-events")
    private lateinit var customerEventsEmitter: Emitter<String>

    @Inject
    @Channel("commerce-order-events")
    private lateinit var orderEventsEmitter: Emitter<String>

    @Inject
    @Channel("finance-invoice-events")
    private lateinit var invoiceEventsEmitter: Emitter<String>

    @Inject
    @Channel("supply-inventory-events")
    private lateinit var inventoryEventsEmitter: Emitter<String>

    @Inject
    @Channel("operations-service-order-events")
    private lateinit var serviceOrderEventsEmitter: Emitter<String>

    @Inject @Channel("platform-user-events") private lateinit var userEventsEmitter: Emitter<String>

    @Inject
    @Channel("platform-internal-events")
    private lateinit var internalEventsEmitter: Emitter<String>

    /** Publishes a domain event to the appropriate Kafka topic. */
    fun publish(event: DomainEvent) {
        try {
            val emitter = getEmitterForEvent(event)
            val topic = getTopicForEvent(event)
            val eventJson = serializeEvent(event)

            // Send event to Kafka via the appropriate channel
            emitter.send(eventJson)

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

    /** Gets the appropriate emitter for an event. */
    private fun getEmitterForEvent(event: DomainEvent): Emitter<String> {
        return when (event) {
            // Customer events
            is CustomerCreatedEvent,
            is CustomerCreditLimitChangedEvent,
            is CustomerStatusChangedEvent,
            is CustomerContactUpdatedEvent,
            is CustomerAssignedEvent -> customerEventsEmitter

            // Order events
            is OrderCreatedEvent,
            is OrderConfirmedEvent,
            is OrderStatusChangedEvent,
            is OrderCancelledEvent,
            is OrderShippedEvent,
            is OrderDeliveredEvent -> orderEventsEmitter

            // Invoice events
            is InvoiceCreatedEvent,
            is InvoiceSentEvent,
            is InvoicePaymentReceivedEvent,
            is InvoicePaidEvent,
            is InvoiceOverdueEvent,
            is InvoiceCancelledEvent,
            is CreditNoteIssuedEvent -> invoiceEventsEmitter

            // Inventory events
            is ProductCreatedEvent,
            is InventoryAdjustedEvent,
            is InventoryAllocatedEvent,
            is InventoryReleasedEvent,
            is InventoryLowStockEvent,
            is InventoryOutOfStockEvent,
            is GoodsReceivedEvent,
            is MaterialTransferredEvent -> inventoryEventsEmitter

            // Service Order events
            is ServiceOrderCreatedEvent,
            is ServiceOrderAssignedEvent,
            is ServiceOrderScheduledEvent,
            is ServiceOrderStartedEvent,
            is ServiceOrderCompletedEvent,
            is ServiceOrderStatusChangedEvent,
            is ServiceOrderCancelledEvent -> serviceOrderEventsEmitter

            // User events (Integration Events)
            is UserCreatedEvent,
            is UserUpdatedEvent,
            is UserActivatedEvent,
            is UserDeactivatedEvent,
            is UserRoleAssignedEvent,
            is UserRoleRevokedEvent -> userEventsEmitter

            // Platform internal events (Domain Events only)
            is UserLoggedInEvent,
            is UserPasswordChangedEvent -> internalEventsEmitter

            // Default for unknown events
            else -> internalEventsEmitter
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
