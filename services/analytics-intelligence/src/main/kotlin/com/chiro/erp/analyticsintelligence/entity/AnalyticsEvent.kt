package com.chiro.erp.analyticsintelligence.entity

import io.quarkus.hibernate.reactive.panache.kotlin.PanacheEntity
import jakarta.persistence.Entity
import jakarta.persistence.Table
import jakarta.persistence.Column
import java.time.LocalDateTime

@Entity
@Table(name = "analytics_events")
class AnalyticsEvent : PanacheEntity() {
    
    @Column(name = "event_type", nullable = false)
    lateinit var eventType: String
    
    @Column(name = "event_data", columnDefinition = "TEXT")
    var eventData: String? = null
    
    @Column(name = "source_system", nullable = false)
    lateinit var sourceSystem: String
    
    @Column(name = "created_at", nullable = false)
    var createdAt: LocalDateTime = LocalDateTime.now()
    
    @Column(name = "processed_at")
    var processedAt: LocalDateTime? = null
    
    @Column(name = "processing_status", nullable = false)
    var processingStatus: String = "PENDING"
    

}
