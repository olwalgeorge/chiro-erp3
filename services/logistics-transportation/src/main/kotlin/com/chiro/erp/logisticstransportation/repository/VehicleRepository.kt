package com.chiro.erp.logisticstransportation.repository

import com.chiro.erp.logisticstransportation.entity.Vehicle
import com.chiro.erp.logisticstransportation.entity.VehicleStatus
import com.chiro.erp.logisticstransportation.entity.VehicleType
import io.quarkus.hibernate.reactive.panache.kotlin.PanacheRepository
import io.smallrye.mutiny.Uni
import jakarta.enterprise.context.ApplicationScoped

@ApplicationScoped
class VehicleRepository : PanacheRepository<Vehicle> {

    fun findByVehicleNumber(vehicleNumber: String): Uni<Vehicle?> =
        find("vehicleNumber", vehicleNumber).firstResult()

    fun findByLicensePlate(licensePlate: String): Uni<Vehicle?> =
        find("licensePlate", licensePlate).firstResult()

    fun findByStatus(status: VehicleStatus): Uni<List<Vehicle>> =
        find("status", status).list()

    fun findByType(type: VehicleType): Uni<List<Vehicle>> =
        find("type", type).list()

    fun findByDriverId(driverId: String): Uni<List<Vehicle>> =
        find("driverId", driverId).list()

    fun findAvailableVehicles(): Uni<List<Vehicle>> =
        find("status", VehicleStatus.AVAILABLE).list()

    fun findAvailableVehiclesByType(type: VehicleType): Uni<List<Vehicle>> =
        find("status = ?1 AND type = ?2", VehicleStatus.AVAILABLE, type).list()
}
