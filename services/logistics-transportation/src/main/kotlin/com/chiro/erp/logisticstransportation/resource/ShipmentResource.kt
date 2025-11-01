package com.chiro.erp.logisticstransportation.resource

import com.chiro.erp.logisticstransportation.entity.Shipment
import com.chiro.erp.logisticstransportation.entity.ShipmentStatus
import com.chiro.erp.logisticstransportation.repository.ShipmentRepository
import io.quarkus.hibernate.reactive.panache.common.WithTransaction
import io.smallrye.mutiny.Uni
import jakarta.inject.Inject
import jakarta.ws.rs.*
import jakarta.ws.rs.core.MediaType
import jakarta.ws.rs.core.Response
import java.time.LocalDateTime

@Path("/api/shipments")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
class ShipmentResource {
    @Inject
    lateinit var shipmentRepository: ShipmentRepository

    @GET
    fun getAllShipments(): Uni<List<Shipment>> = shipmentRepository.listAll()

    @GET
    @Path("/{id}")
    fun getShipment(
        @PathParam("id") id: Long,
    ): Uni<Response> {
        return shipmentRepository.findById(id)
            .onItem().transform { shipment ->
                if (shipment != null) {
                    Response.ok(shipment).build()
                } else {
                    Response.status(Response.Status.NOT_FOUND).build()
                }
            }
    }

    @GET
    @Path("/tracking/{trackingNumber}")
    fun trackShipment(
        @PathParam("trackingNumber") trackingNumber: String,
    ): Uni<Response> {
        return shipmentRepository.findByTrackingNumber(trackingNumber)
            .onItem().transform { shipment ->
                if (shipment != null) {
                    Response.ok(shipment).build()
                } else {
                    Response.status(Response.Status.NOT_FOUND).build()
                }
            }
    }

    @GET
    @Path("/customer/{customerId}")
    fun getShipmentsByCustomer(
        @PathParam("customerId") customerId: String,
    ): Uni<List<Shipment>> = shipmentRepository.findByCustomerId(customerId)

    @GET
    @Path("/status/{status}")
    fun getShipmentsByStatus(
        @PathParam("status") status: ShipmentStatus,
    ): Uni<List<Shipment>> = shipmentRepository.findByStatus(status)

    @GET
    @Path("/active")
    fun getActiveShipments(): Uni<List<Shipment>> = shipmentRepository.findActiveShipments()

    @GET
    @Path("/delayed")
    fun getDelayedShipments(): Uni<List<Shipment>> = shipmentRepository.findDelayedShipments()

    @POST
    @WithTransaction
    fun createShipment(shipment: Shipment): Uni<Response> {
        shipment.createdAt = LocalDateTime.now()
        shipment.updatedAt = LocalDateTime.now()
        return shipmentRepository.persist(shipment)
            .onItem().transform { Response.status(Response.Status.CREATED).entity(it).build() }
    }

    @PUT
    @Path("/{id}")
    @WithTransaction
    fun updateShipment(
        @PathParam("id") id: Long,
        shipment: Shipment,
    ): Uni<Response> {
        return shipmentRepository.findById(id)
            .onItem().transformToUni { existingShipment ->
                if (existingShipment != null) {
                    existingShipment.status = shipment.status
                    existingShipment.currentLocation = shipment.currentLocation
                    existingShipment.estimatedDelivery = shipment.estimatedDelivery
                    existingShipment.actualDelivery = shipment.actualDelivery
                    existingShipment.specialInstructions = shipment.specialInstructions
                    existingShipment.updatedAt = LocalDateTime.now()
                    shipmentRepository.persist(existingShipment)
                        .onItem().transform { Response.ok(it).build() }
                } else {
                    Uni.createFrom().item(Response.status(Response.Status.NOT_FOUND).build())
                }
            }
    }

    @DELETE
    @Path("/{id}")
    @WithTransaction
    fun deleteShipment(
        @PathParam("id") id: Long,
    ): Uni<Response> {
        return shipmentRepository.deleteById(id)
            .onItem().transform { deleted ->
                if (deleted) {
                    Response.noContent().build()
                } else {
                    Response.status(Response.Status.NOT_FOUND).build()
                }
            }
    }
}
