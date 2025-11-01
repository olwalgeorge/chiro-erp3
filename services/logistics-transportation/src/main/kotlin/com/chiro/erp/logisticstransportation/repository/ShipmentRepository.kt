package com.chiro.erp.logisticstransportation.repository

import com.chiro.erp.logisticstransportation.entity.Shipment
import com.chiro.erp.logisticstransportation.entity.ShipmentStatus
import io.quarkus.hibernate.reactive.panache.kotlin.PanacheRepository
import io.smallrye.mutiny.Uni
import jakarta.enterprise.context.ApplicationScoped

@ApplicationScoped
class ShipmentRepository : PanacheRepository<Shipment> {
    fun findByTrackingNumber(trackingNumber: String): Uni<Shipment?> =
        find("trackingNumber", trackingNumber).firstResult()

    fun findByCustomerId(customerId: String): Uni<List<Shipment>> = find("customerId", customerId).list()

    fun findByStatus(status: ShipmentStatus): Uni<List<Shipment>> = find("status", status).list()

    fun findByOrigin(origin: String): Uni<List<Shipment>> = find("origin", origin).list()

    fun findByDestination(destination: String): Uni<List<Shipment>> = find("destination", destination).list()

    fun findActiveShipments(): Uni<List<Shipment>> =
        find(
            "status IN (?1, ?2, ?3, ?4)",
            ShipmentStatus.PENDING,
            ShipmentStatus.PICKED_UP,
            ShipmentStatus.IN_TRANSIT,
            ShipmentStatus.OUT_FOR_DELIVERY,
        ).list()

    fun findDelayedShipments(): Uni<List<Shipment>> = find("status = ?1", ShipmentStatus.DELAYED).list()
}
