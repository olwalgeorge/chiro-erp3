package com.chiro.erp.coreplatform.shared.messaging

import com.chiro.erp.coreplatform.shared.events.DomainEvent
import jakarta.enterprise.context.ApplicationScoped
import java.util.UUID
import org.eclipse.microprofile.reactive.messaging.Channel
import org.eclipse.microprofile.reactive.messaging.Emitter
import org.eclipse.microprofile.reactive.messaging.Incoming
import org.jboss.logging.Logger

/** Kafka event producer for Core Platform service */
@ApplicationScoped
class CorePlatformEventProducer(
        @Channel("core-platform-events-out") private val eventEmitter: Emitter<String>
) {
    private val logger = Logger.getLogger(CorePlatformEventProducer::class.java)

    fun publishEvent(eventType: String, payload: String) {
        val event =
                DomainEvent(
                        eventId = UUID.randomUUID().toString(),
                        eventType = eventType,
                        serviceName = "core-platform",
                        payload = payload
                )

        val message =
                """{"eventId":"${event.eventId}","eventType":"${event.eventType}","serviceName":"${event.serviceName}","timestamp":"${event.timestamp}","payload":"${event.payload}"}"""

        eventEmitter.send(message)
        logger.info("Published event: $eventType with ID: ${event.eventId}")
    }
}

/** Kafka event consumer for Core Platform service */
@ApplicationScoped
class CorePlatformEventConsumer {
    private val logger = Logger.getLogger(CorePlatformEventConsumer::class.java)

    @Incoming("core-platform-events-in")
    fun consumeEvent(message: String) {
        logger.info("Core Platform received event: $message")
        // Process the event here
    }

    @Incoming("shared-events")
    fun consumeSharedEvent(message: String) {
        logger.info("Core Platform received shared event: $message")
        // Process shared events from other services
    }
}
