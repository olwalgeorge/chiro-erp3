package com.chiro.erp.logisticstransportation.entity

import io.quarkus.hibernate.reactive.panache.kotlin.PanacheEntity
import jakarta.persistence.*
import java.math.BigDecimal
import java.time.LocalDateTime

@Entity
@Table(name = "shipments")
class Shipment : PanacheEntity() {
    
    @Column(nullable = false, unique = true)
    lateinit var trackingNumber: String
    
    @Column(nullable = false)
    lateinit var customerId: String
    
    @Column(nullable = false)
    lateinit var origin: String
    
    @Column(nullable = false)
    lateinit var destination: String
    
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    lateinit var status: ShipmentStatus
    
    @Column(nullable = false)
    lateinit var weight: BigDecimal
    
    @Column
    var dimensions: String? = null
    
    @Column
    var specialInstructions: String? = null
    
    @Column
    var currentLocation: String? = null
    
    @Column(nullable = false)
    lateinit var shipDate: LocalDateTime
    
    @Column
    var estimatedDelivery: LocalDateTime? = null
    
    @Column
    var actualDelivery: LocalDateTime? = null
    
    @Column(nullable = false)
    var createdAt: LocalDateTime = LocalDateTime.now()
    
    @Column(nullable = false)
    var updatedAt: LocalDateTime = LocalDateTime.now()
}

enum class ShipmentStatus {
    PENDING,
    PICKED_UP,
    IN_TRANSIT,
    OUT_FOR_DELIVERY,
    DELIVERED,
    DELAYED,
    CANCELLED
}
