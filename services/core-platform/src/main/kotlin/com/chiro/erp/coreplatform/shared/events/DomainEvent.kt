package com.chiro.erp.coreplatform.shared.events

import java.time.Instant

/**
 * Legacy simple event class for testing and backward compatibility. For new domain events, use the
 * types defined in BaseEvents.kt and specific event files.
 *
 * @see BaseEvents.kt for new domain event types
 * @deprecated Use strongly-typed domain events instead
 */
@Deprecated("Use strongly-typed domain events from BaseEvents.kt")
data class SimpleEvent(
        val eventId: String,
        val eventType: String,
        val serviceName: String,
        val timestamp: String = Instant.now().toString(),
        val payload: String,
)
