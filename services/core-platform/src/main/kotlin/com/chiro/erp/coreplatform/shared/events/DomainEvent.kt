package com.chiro.erp.coreplatform.shared.events

import java.time.Instant

/** Base event class for all domain events */
data class DomainEvent(
        val eventId: String,
        val eventType: String,
        val serviceName: String,
        val timestamp: String = Instant.now().toString(),
        val payload: String,
)
