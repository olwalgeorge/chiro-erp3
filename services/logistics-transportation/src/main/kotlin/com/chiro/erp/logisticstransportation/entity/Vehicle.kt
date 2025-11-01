package com.chiro.erp.logisticstransportation.entity

import io.quarkus.hibernate.reactive.panache.kotlin.PanacheEntity
import jakarta.persistence.*
import java.time.LocalDateTime

@Entity
@Table(name = "vehicles")
class Vehicle : PanacheEntity() {
    
    @Column(nullable = false, unique = true)
    lateinit var vehicleNumber: String
    
    @Column(nullable = false)
    lateinit var licensePlate: String
    
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    lateinit var type: VehicleType
    
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    lateinit var status: VehicleStatus
    
    @Column
    var driverId: String? = null
    
    @Column
    var capacity: String? = null
    
    @Column
    var currentLocation: String? = null
    
    @Column
    var lastMaintenance: LocalDateTime? = null
    
    @Column
    var nextMaintenance: LocalDateTime? = null
    
    @Column(nullable = false)
    var createdAt: LocalDateTime = LocalDateTime.now()
    
    @Column(nullable = false)
    var updatedAt: LocalDateTime = LocalDateTime.now()
}

enum class VehicleType {
    TRUCK,
    VAN,
    MOTORCYCLE,
    BICYCLE,
    CARGO_PLANE,
    SHIP
}

enum class VehicleStatus {
    AVAILABLE,
    IN_USE,
    MAINTENANCE,
    OUT_OF_SERVICE
}
