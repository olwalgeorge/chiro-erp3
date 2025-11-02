package com.chiro.erp.administration.shared.messaging

import jakarta.enterprise.context.ApplicationScoped
import java.time.Instant
import java.util.UUID
import org.eclipse.microprofile.reactive.messaging.Channel
import org.eclipse.microprofile.reactive.messaging.Emitter
import org.eclipse.microprofile.reactive.messaging.Incoming
import org.jboss.logging.Logger

@ApplicationScoped
class AdministrationEventProducer(
        @Channel("administration-events-out") private val eventEmitter: Emitter<String>
) {
    private val logger = Logger.getLogger(AdministrationEventProducer::class.java)

    fun publishEvent(eventType: String, payload: String) {
        val eventId = UUID.randomUUID().toString()
        val timestamp = Instant.now().toString()

        val message =
                """{"eventId":"$eventId","eventType":"$eventType","serviceName":"administration","timestamp":"$timestamp","payload":"$payload"}"""

        eventEmitter.send(message)
        logger.info("Published event: $eventType with ID: $eventId")
    }
}

@ApplicationScoped
class AdministrationEventConsumer {
    private val logger = Logger.getLogger(AdministrationEventConsumer::class.java)

    @Incoming("administration-events-in")
    fun consumeEvent(message: String) {
        logger.info("Administration received event: $message")
    }

    @Incoming("shared-events")
    fun consumeSharedEvent(message: String) {
        logger.info("Administration received shared event: $message")
    }
}
