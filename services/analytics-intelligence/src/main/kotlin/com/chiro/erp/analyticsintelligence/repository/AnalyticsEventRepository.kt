package com.chiro.erp.analyticsintelligence.repository

import com.chiro.erp.analyticsintelligence.entity.AnalyticsEvent
import io.quarkus.hibernate.reactive.panache.kotlin.PanacheRepository
import io.smallrye.mutiny.Uni
import jakarta.enterprise.context.ApplicationScoped
import java.time.LocalDateTime

@ApplicationScoped
class AnalyticsEventRepository : PanacheRepository<AnalyticsEvent> {
    fun findByEventType(eventType: String): Uni<List<AnalyticsEvent>> {
        return find("eventType", eventType).list()
    }

    fun findUnprocessed(): Uni<List<AnalyticsEvent>> {
        return find("processingStatus", "PENDING").list()
    }

    fun findBySourceSystem(sourceSystem: String): Uni<List<AnalyticsEvent>> {
        return find("sourceSystem", sourceSystem).list()
    }

    fun findCreatedAfter(dateTime: LocalDateTime): Uni<List<AnalyticsEvent>> {
        return find("createdAt > ?1", dateTime).list()
    }

    fun markAsProcessed(event: AnalyticsEvent): Uni<AnalyticsEvent> {
        event.processingStatus = "PROCESSED"
        event.processedAt = LocalDateTime.now()
        return persistAndFlush(event)
    }
}
