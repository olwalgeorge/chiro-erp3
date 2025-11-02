# Domain Models - Logistics & Transportation Service

## Schema: `logistics_schema`

This service implements **world-class logistics and transportation management** patterns following SAP TM (Transportation Management) and WMS (Warehouse Management System) principles.

---

## Overview

The Logistics & Transportation service manages the complete supply chain execution from warehouse operations through final delivery, including fleet management, transportation planning, and warehouse operations.

### Key Responsibilities

-   Fleet management and vehicle tracking
-   Transportation planning and execution
-   Warehouse management and inventory control
-   Shipping and delivery coordination
-   Route optimization and dispatch
-   Freight cost management
-   Carrier and driver management

---

## Domain 1: Fleet Management

### Aggregates

**Vehicle (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "vehicles",
    schema = "logistics_schema",
    indexes = [
        Index(name = "idx_vehicle_registration", columnList = "registrationNumber"),
        Index(name = "idx_vehicle_status", columnList = "status"),
        Index(name = "idx_vehicle_type", columnList = "vehicleType")
    ]
)
class Vehicle(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val vehicleNumber: String, // VEH-YYYY-NNNN

    @Column(nullable = false, unique = true)
    val registrationNumber: String,

    @Column(nullable = false)
    val vin: String, // Vehicle Identification Number

    @Enumerated(EnumType.STRING)
    val vehicleType: VehicleType,

    // Vehicle specifications
    @Column(nullable = false)
    val make: String,

    @Column(nullable = false)
    val model: String,

    @Column(nullable = false)
    val year: Int,

    val color: String? = null,

    @Embedded
    var capacity: VehicleCapacity,

    // Registration & Insurance
    @Embedded
    var registration: VehicleRegistration,

    @Embedded
    var insurance: VehicleInsurance,

    // Operational details
    @Enumerated(EnumType.STRING)
    var status: VehicleStatus,

    @Enumerated(EnumType.STRING)
    var condition: VehicleCondition,

    // Current assignment
    val currentDriverId: UUID? = null,
    val homeLocationId: UUID? = null,

    // Tracking
    @Embedded
    var location: VehicleLocation?,

    @Column(precision = 10, scale = 2)
    var currentMileage: BigDecimal = BigDecimal.ZERO,

    @Column(precision = 10, scale = 2)
    var fuelLevel: BigDecimal? = null, // Percentage

    // Maintenance
    var lastMaintenanceDate: LocalDate? = null,
    var nextMaintenanceDate: LocalDate? = null,

    @Column(precision = 10, scale = 2)
    var maintenanceMileage: BigDecimal? = null,

    @Column(length = 2000)
    var notes: String? = null,

    // Audit & Multi-tenancy
    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val organizationId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
) {
    fun assignDriver(driverId: UUID) {
        require(status == VehicleStatus.AVAILABLE) { "Vehicle must be available for assignment" }
        // Implementation
    }

    fun updateLocation(latitude: BigDecimal, longitude: BigDecimal, timestamp: Instant) {
        this.location = VehicleLocation(latitude, longitude, timestamp)
        this.updatedAt = Instant.now()
    }

    fun scheduleMaintenance(scheduledDate: LocalDate) {
        this.nextMaintenanceDate = scheduledDate
        this.status = VehicleStatus.MAINTENANCE_SCHEDULED
        this.updatedAt = Instant.now()
    }

    fun needsMaintenance(): Boolean {
        return nextMaintenanceDate?.let { LocalDate.now() >= it } ?: false
    }
}

enum class VehicleType {
    TRUCK, VAN, CARGO_VAN, BOX_TRUCK, FLATBED, REFRIGERATED, TANKER, TRAILER
}

enum class VehicleStatus {
    AVAILABLE, IN_USE, MAINTENANCE, OUT_OF_SERVICE, RETIRED
}

enum class VehicleCondition {
    EXCELLENT, GOOD, FAIR, POOR, NEEDS_REPAIR
}

@Embeddable
data class VehicleCapacity(
    @Column(precision = 10, scale = 2)
    val weightCapacityKg: BigDecimal,

    @Column(precision = 10, scale = 3)
    val volumeCapacityM3: BigDecimal,

    val palletCapacity: Int? = null
)

@Embeddable
data class VehicleRegistration(
    val registrationExpiry: LocalDate,
    val registrationState: String,
    val licensePlate: String
)

@Embeddable
data class VehicleInsurance(
    val insuranceProvider: String,
    val policyNumber: String,
    val policyExpiry: LocalDate,
    val coverageAmount: BigDecimal
)

@Embeddable
data class VehicleLocation(
    @Column(precision = 10, scale = 7)
    val latitude: BigDecimal,

    @Column(precision = 10, scale = 7)
    val longitude: BigDecimal,

    val lastUpdated: Instant
)
```

**Driver (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "drivers",
    schema = "logistics_schema",
    indexes = [
        Index(name = "idx_driver_employee", columnList = "employeeId"),
        Index(name = "idx_driver_license", columnList = "licenseNumber"),
        Index(name = "idx_driver_status", columnList = "status")
    ]
)
class Driver(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val driverNumber: String, // DRV-YYYY-NNNN

    @Column(nullable = false)
    val employeeId: UUID, // Reference to HR domain

    // License information
    @Column(nullable = false, unique = true)
    val licenseNumber: String,

    @Enumerated(EnumType.STRING)
    val licenseClass: LicenseClass,

    val licenseExpiry: LocalDate,

    val licenseState: String,

    // Certifications
    @OneToMany(mappedBy = "driver", cascade = [CascadeType.ALL])
    val certifications: MutableList<DriverCertification> = mutableListOf(),

    // Availability
    @Enumerated(EnumType.STRING)
    var status: DriverStatus,

    @Embedded
    var availability: DriverAvailability,

    // Current assignment
    val currentVehicleId: UUID? = null,
    val currentRouteId: UUID? = null,

    // Performance metrics
    @Column(precision = 10, scale = 2)
    var totalMilesDriven: BigDecimal = BigDecimal.ZERO,

    var totalDeliveries: Int = 0,

    @Column(precision = 5, scale = 2)
    var averageRating: BigDecimal? = null,

    // Safety record
    var lastSafetyCheckDate: LocalDate? = null,
    var accidentCount: Int = 0,
    var violationCount: Int = 0,

    @Column(length = 2000)
    var notes: String? = null,

    // Audit
    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
) {
    fun isAvailableForAssignment(): Boolean {
        return status == DriverStatus.AVAILABLE &&
               licenseExpiry.isAfter(LocalDate.now())
    }

    fun assignToRoute(routeId: UUID, vehicleId: UUID) {
        require(isAvailableForAssignment()) { "Driver not available" }
        // Implementation
    }
}

enum class LicenseClass {
    CLASS_A, CLASS_B, CLASS_C, COMMERCIAL, HAZMAT
}

enum class DriverStatus {
    AVAILABLE, ON_ROUTE, OFF_DUTY, ON_BREAK, UNAVAILABLE, SUSPENDED
}

@Embeddable
data class DriverAvailability(
    val availableFrom: LocalTime,
    val availableTo: LocalTime,
    val workingDays: String // e.g., "MTWTF"
)
```

**DriverCertification (Entity)**

```kotlin
@Entity
@Table(name = "driver_certifications", schema = "logistics_schema")
class DriverCertification(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "driver_id", nullable = false)
    val driver: Driver,

    @Enumerated(EnumType.STRING)
    val certificationType: CertificationType,

    @Column(nullable = false)
    val certificationNumber: String,

    @Column(nullable = false)
    val issuedDate: LocalDate,

    @Column(nullable = false)
    val expiryDate: LocalDate,

    val issuingAuthority: String? = null,

    @Enumerated(EnumType.STRING)
    var status: CertificationStatus
)

enum class CertificationType {
    HAZMAT, TANKER, DOUBLES_TRIPLES, PASSENGER, FORKLIFT, REFRIGERATED
}

enum class CertificationStatus {
    ACTIVE, EXPIRED, SUSPENDED, REVOKED
}
```

---

## Domain 2: Transportation Management

### Aggregates

**Shipment (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "shipments",
    schema = "logistics_schema",
    indexes = [
        Index(name = "idx_shipment_number", columnList = "shipmentNumber"),
        Index(name = "idx_shipment_status", columnList = "status"),
        Index(name = "idx_shipment_dates", columnList = "pickupDate,deliveryDate")
    ]
)
class Shipment(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val shipmentNumber: String, // SHP-YYYY-NNNNNN

    // Reference to sales order or purchase order
    val salesOrderId: UUID? = null,
    val purchaseOrderId: UUID? = null,

    // Customer & Vendor
    val customerId: UUID? = null,
    val vendorId: UUID? = null,

    // Addresses
    @Embedded
    var originAddress: ShippingAddress,

    @Embedded
    var destinationAddress: ShippingAddress,

    // Dates
    @Column(nullable = false)
    val pickupDate: LocalDate,

    val requestedDeliveryDate: LocalDate? = null,

    var actualPickupDate: LocalDate? = null,
    var actualDeliveryDate: LocalDate? = null,

    // Shipment details
    @Enumerated(EnumType.STRING)
    val shipmentType: ShipmentType,

    @Enumerated(EnumType.STRING)
    val serviceLevel: ServiceLevel,

    // Line items
    @OneToMany(mappedBy = "shipment", cascade = [CascadeType.ALL])
    val items: MutableList<ShipmentItem> = mutableListOf(),

    // Dimensions & Weight
    @Column(nullable = false, precision = 10, scale = 2)
    var totalWeight: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false, precision = 10, scale = 3)
    var totalVolume: BigDecimal = BigDecimal.ZERO,

    val packageCount: Int = 0,

    // Carrier & Route
    val carrierId: UUID? = null,
    val routeId: UUID? = null,
    val vehicleId: UUID? = null,
    val driverId: UUID? = null,

    // Tracking
    val trackingNumber: String? = null,

    @Enumerated(EnumType.STRING)
    var status: ShipmentStatus,

    // Costs
    @Column(precision = 19, scale = 2)
    var estimatedCost: BigDecimal? = null,

    @Column(precision = 19, scale = 2)
    var actualCost: BigDecimal? = null,

    @Column(nullable = false)
    val currency: String = "USD",

    // Special requirements
    val requiresRefrigeration: Boolean = false,
    val requiresHazmatHandling: Boolean = false,
    val requiresSignature: Boolean = true,

    @Column(length = 2000)
    var specialInstructions: String? = null,

    @Column(length = 2000)
    var notes: String? = null,

    // Audit
    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val organizationId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
) {
    fun dispatch(routeId: UUID, vehicleId: UUID, driverId: UUID) {
        require(status == ShipmentStatus.PENDING) { "Only pending shipments can be dispatched" }
        // Implementation
    }

    fun markPickedUp(timestamp: Instant) {
        this.status = ShipmentStatus.IN_TRANSIT
        this.actualPickupDate = LocalDate.now()
        this.updatedAt = timestamp
    }

    fun markDelivered(timestamp: Instant, signature: String?) {
        this.status = ShipmentStatus.DELIVERED
        this.actualDeliveryDate = LocalDate.now()
        this.updatedAt = timestamp
    }

    fun isDelayed(): Boolean {
        val expected = requestedDeliveryDate ?: return false
        return status == ShipmentStatus.IN_TRANSIT && LocalDate.now().isAfter(expected)
    }
}

enum class ShipmentType {
    INBOUND, OUTBOUND, TRANSFER, RETURN
}

enum class ServiceLevel {
    STANDARD, EXPRESS, OVERNIGHT, SAME_DAY, TWO_DAY
}

enum class ShipmentStatus {
    PENDING, SCHEDULED, DISPATCHED, IN_TRANSIT, OUT_FOR_DELIVERY,
    DELIVERED, DELAYED, FAILED, CANCELLED, RETURNED
}

@Embeddable
data class ShippingAddress(
    @Column(nullable = false)
    val recipientName: String,

    val companyName: String? = null,

    @Column(nullable = false)
    val addressLine1: String,

    val addressLine2: String? = null,

    @Column(nullable = false)
    val city: String,

    @Column(nullable = false)
    val state: String,

    @Column(nullable = false)
    val postalCode: String,

    @Column(nullable = false)
    val country: String,

    val phoneNumber: String? = null,

    val email: String? = null,

    @Column(precision = 10, scale = 7)
    val latitude: BigDecimal? = null,

    @Column(precision = 10, scale = 7)
    val longitude: BigDecimal? = null
)
```

**ShipmentItem (Entity)**

```kotlin
@Entity
@Table(name = "shipment_items", schema = "logistics_schema")
class ShipmentItem(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "shipment_id", nullable = false)
    var shipment: Shipment? = null,

    @Column(nullable = false)
    val lineNumber: Int,

    val productId: UUID? = null,

    @Column(nullable = false)
    val description: String,

    @Column(nullable = false, precision = 10, scale = 4)
    val quantity: BigDecimal,

    @Column(nullable = false)
    val unitOfMeasure: String,

    // Dimensions per unit
    @Column(precision = 10, scale = 2)
    val weightPerUnit: BigDecimal? = null,

    @Column(precision = 10, scale = 3)
    val volumePerUnit: BigDecimal? = null,

    // Inventory reference
    val inventoryLocationId: UUID? = null,
    val lotNumber: String? = null,
    val serialNumber: String? = null,

    // Packaging
    val packageType: String? = null,
    val packageCount: Int = 1
)
```

**Route (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "routes",
    schema = "logistics_schema",
    indexes = [
        Index(name = "idx_route_number", columnList = "routeNumber"),
        Index(name = "idx_route_date", columnList = "routeDate"),
        Index(name = "idx_route_status", columnList = "status")
    ]
)
class Route(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val routeNumber: String, // RTE-YYYY-NNNNNN

    @Column(nullable = false)
    val routeDate: LocalDate,

    @Column(nullable = false)
    val plannedStartTime: LocalTime,

    @Column(nullable = false)
    val plannedEndTime: LocalTime,

    var actualStartTime: Instant? = null,
    var actualEndTime: Instant? = null,

    // Assignments
    @Column(nullable = false)
    val vehicleId: UUID,

    @Column(nullable = false)
    val driverId: UUID,

    // Route optimization
    @Embedded
    var routeMetrics: RouteMetrics,

    // Stops
    @OneToMany(mappedBy = "route", cascade = [CascadeType.ALL])
    val stops: MutableList<RouteStop> = mutableListOf(),

    @Enumerated(EnumType.STRING)
    var status: RouteStatus,

    @Column(length = 2000)
    var notes: String? = null,

    // Audit
    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
) {
    fun addStop(stop: RouteStop) {
        stops.add(stop)
        stop.route = this
        recalculateMetrics()
    }

    private fun recalculateMetrics() {
        // Recalculate total distance, estimated time, etc.
    }

    fun start() {
        require(status == RouteStatus.SCHEDULED) { "Only scheduled routes can be started" }
        this.status = RouteStatus.IN_PROGRESS
        this.actualStartTime = Instant.now()
        this.updatedAt = Instant.now()
    }

    fun complete() {
        require(status == RouteStatus.IN_PROGRESS) { "Only in-progress routes can be completed" }
        require(stops.all { it.status == StopStatus.COMPLETED }) { "All stops must be completed" }

        this.status = RouteStatus.COMPLETED
        this.actualEndTime = Instant.now()
        this.updatedAt = Instant.now()
    }
}

enum class RouteStatus {
    DRAFT, SCHEDULED, IN_PROGRESS, COMPLETED, CANCELLED
}

@Embeddable
data class RouteMetrics(
    @Column(precision = 10, scale = 2)
    var totalDistance: BigDecimal = BigDecimal.ZERO, // in km

    var estimatedDuration: Int = 0, // in minutes

    var stopCount: Int = 0,

    @Column(precision = 10, scale = 2)
    var totalWeight: BigDecimal = BigDecimal.ZERO,

    @Column(precision = 10, scale = 3)
    var totalVolume: BigDecimal = BigDecimal.ZERO
)
```

**RouteStop (Entity)**

```kotlin
@Entity
@Table(
    name = "route_stops",
    schema = "logistics_schema",
    indexes = [
        Index(name = "idx_route_stop_route", columnList = "route_id,sequenceNumber")
    ]
)
class RouteStop(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "route_id", nullable = false)
    var route: Route? = null,

    @Column(nullable = false)
    val sequenceNumber: Int,

    @Column(nullable = false)
    val shipmentId: UUID,

    @Enumerated(EnumType.STRING)
    val stopType: StopType,

    // Address
    @Embedded
    val address: ShippingAddress,

    // Timing
    val plannedArrivalTime: LocalTime,
    val plannedDepartureTime: LocalTime,

    var actualArrivalTime: Instant? = null,
    var actualDepartureTime: Instant? = null,

    val estimatedServiceTime: Int = 15, // minutes

    // Status
    @Enumerated(EnumType.STRING)
    var status: StopStatus = StopStatus.PENDING,

    // Proof of delivery
    var signature: String? = null,
    var photoUrl: String? = null,

    @Column(length = 1000)
    var notes: String? = null
) {
    fun arrive(timestamp: Instant) {
        this.actualArrivalTime = timestamp
        this.status = StopStatus.ARRIVED
    }

    fun complete(signature: String?, notes: String?) {
        require(status == StopStatus.ARRIVED) { "Stop must be arrived before completing" }

        this.actualDepartureTime = Instant.now()
        this.signature = signature
        this.notes = notes
        this.status = StopStatus.COMPLETED
    }

    fun fail(reason: String) {
        this.status = StopStatus.FAILED
        this.notes = "Failed: $reason"
    }
}

enum class StopType {
    PICKUP, DELIVERY, BOTH
}

enum class StopStatus {
    PENDING, EN_ROUTE, ARRIVED, COMPLETED, FAILED, SKIPPED
}
```

---

## Domain 3: Warehouse Management

### Aggregates

**Warehouse (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "warehouses",
    schema = "logistics_schema",
    indexes = [
        Index(name = "idx_warehouse_code", columnList = "warehouseCode"),
        Index(name = "idx_warehouse_status", columnList = "status")
    ]
)
class Warehouse(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val warehouseCode: String,

    @Column(nullable = false)
    var name: String,

    @Enumerated(EnumType.STRING)
    val warehouseType: WarehouseType,

    // Address
    @Embedded
    var address: WarehouseAddress,

    // Capacity
    @Embedded
    var capacity: WarehouseCapacity,

    // Operating hours
    @Embedded
    var operatingHours: OperatingHours,

    // Zones
    @OneToMany(mappedBy = "warehouse", cascade = [CascadeType.ALL])
    val zones: MutableList<WarehouseZone> = mutableListOf(),

    @Enumerated(EnumType.STRING)
    var status: WarehouseStatus,

    // Manager
    val managerId: UUID? = null,

    @Column(length = 2000)
    var notes: String? = null,

    // Audit
    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val organizationId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
)

enum class WarehouseType {
    DISTRIBUTION_CENTER, FULFILLMENT_CENTER, COLD_STORAGE,
    CROSS_DOCK, RETAIL_STOCKROOM, MANUFACTURING
}

enum class WarehouseStatus {
    ACTIVE, INACTIVE, UNDER_CONSTRUCTION, CLOSED
}

@Embeddable
data class WarehouseAddress(
    @Column(nullable = false)
    val addressLine1: String,

    val addressLine2: String? = null,

    @Column(nullable = false)
    val city: String,

    @Column(nullable = false)
    val state: String,

    @Column(nullable = false)
    val postalCode: String,

    @Column(nullable = false)
    val country: String,

    @Column(precision = 10, scale = 7)
    val latitude: BigDecimal? = null,

    @Column(precision = 10, scale = 7)
    val longitude: BigDecimal? = null
)

@Embeddable
data class WarehouseCapacity(
    @Column(precision = 15, scale = 2)
    val totalAreaSqM: BigDecimal,

    @Column(precision = 15, scale = 3)
    val totalVolumeM3: BigDecimal,

    val palletPositions: Int? = null,

    @Column(precision = 12, scale = 2)
    val maxWeightCapacityKg: BigDecimal
)

@Embeddable
data class OperatingHours(
    val openTime: LocalTime,
    val closeTime: LocalTime,
    val operatingDays: String, // e.g., "MTWTFSS"
    val timezone: String = "UTC"
)
```

**WarehouseZone (Entity)**

```kotlin
@Entity
@Table(name = "warehouse_zones", schema = "logistics_schema")
class WarehouseZone(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "warehouse_id", nullable = false)
    val warehouse: Warehouse,

    @Column(nullable = false)
    val zoneCode: String,

    @Column(nullable = false)
    var zoneName: String,

    @Enumerated(EnumType.STRING)
    val zoneType: ZoneType,

    // Temperature control
    val temperatureControlled: Boolean = false,

    @Column(precision = 5, scale = 2)
    val minTemperature: BigDecimal? = null,

    @Column(precision = 5, scale = 2)
    val maxTemperature: BigDecimal? = null,

    // Capacity
    @Column(precision = 10, scale = 2)
    val areaSize: BigDecimal,

    val aisleCount: Int? = null,
    val baysPerAisle: Int? = null,
    val levelsPerBay: Int? = null,

    @Enumerated(EnumType.STRING)
    var status: ZoneStatus
)

enum class ZoneType {
    RECEIVING, STORAGE, PICKING, PACKING, SHIPPING, STAGING, RETURNS, QUARANTINE
}

enum class ZoneStatus {
    ACTIVE, INACTIVE, MAINTENANCE, FULL
}
```

**InventoryLocation (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "inventory_locations",
    schema = "logistics_schema",
    indexes = [
        Index(name = "idx_location_warehouse", columnList = "warehouseId"),
        Index(name = "idx_location_code", columnList = "locationCode")
    ],
    uniqueConstraints = [
        UniqueConstraint(name = "uk_location", columnNames = ["warehouseId", "locationCode"])
    ]
)
class InventoryLocation(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false)
    val warehouseId: UUID,

    val zoneId: UUID? = null,

    @Column(nullable = false)
    val locationCode: String, // e.g., "A-01-03-02" (Aisle-Bay-Level-Position)

    @Enumerated(EnumType.STRING)
    val locationType: LocationType,

    // Physical dimensions
    @Column(precision = 8, scale = 2)
    val width: BigDecimal? = null,

    @Column(precision = 8, scale = 2)
    val depth: BigDecimal? = null,

    @Column(precision = 8, scale = 2)
    val height: BigDecimal? = null,

    @Column(precision = 10, scale = 2)
    val maxWeight: BigDecimal? = null,

    // Inventory on hand
    @OneToMany(mappedBy = "location", cascade = [CascadeType.ALL])
    val inventory: MutableList<InventoryOnHand> = mutableListOf(),

    @Enumerated(EnumType.STRING)
    var status: LocationStatus,

    // Audit
    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now()
)

enum class LocationType {
    FLOOR, RACK, SHELF, BIN, PALLET, DOCK_DOOR
}

enum class LocationStatus {
    AVAILABLE, OCCUPIED, RESERVED, BLOCKED, DAMAGED
}
```

**InventoryOnHand (Entity)**

```kotlin
@Entity
@Table(
    name = "inventory_on_hand",
    schema = "logistics_schema",
    indexes = [
        Index(name = "idx_inventory_product", columnList = "productId"),
        Index(name = "idx_inventory_location", columnList = "locationId")
    ],
    uniqueConstraints = [
        UniqueConstraint(
            name = "uk_inventory_product_location",
            columnNames = ["productId", "locationId", "lotNumber"]
        )
    ]
)
class InventoryOnHand(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "location_id", nullable = false)
    val location: InventoryLocation,

    @Column(nullable = false)
    val productId: UUID,

    @Column(nullable = false, precision = 15, scale = 4)
    var quantityOnHand: BigDecimal,

    @Column(nullable = false, precision = 15, scale = 4)
    var quantityReserved: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false, precision = 15, scale = 4)
    var quantityAvailable: BigDecimal,

    @Column(nullable = false)
    val unitOfMeasure: String,

    // Lot tracking
    val lotNumber: String? = null,
    val serialNumber: String? = null,
    val expiryDate: LocalDate? = null,

    // Received date
    val receivedDate: LocalDate,

    // Audit
    @Column(nullable = false)
    val updatedAt: Instant = Instant.now()
) {
    init {
        recalculateAvailable()
    }

    private fun recalculateAvailable() {
        quantityAvailable = quantityOnHand - quantityReserved
    }

    fun reserve(quantity: BigDecimal) {
        require(quantity <= quantityAvailable) { "Insufficient quantity available" }
        quantityReserved += quantity
        recalculateAvailable()
    }

    fun releaseReservation(quantity: BigDecimal) {
        require(quantity <= quantityReserved) { "Cannot release more than reserved" }
        quantityReserved -= quantity
        recalculateAvailable()
    }

    fun pick(quantity: BigDecimal) {
        require(quantity <= quantityOnHand) { "Insufficient quantity on hand" }
        quantityOnHand -= quantity
        if (quantity <= quantityReserved) {
            quantityReserved -= quantity
        }
        recalculateAvailable()
    }
}
```

---

## Domain Events

### Fleet Management Events

```kotlin
data class VehicleAssignedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val vehicleId: UUID,
    val driverId: UUID,
    val routeId: UUID?,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)

data class VehicleMaintenanceScheduledEvent(
    val eventId: UUID = UUID.randomUUID(),
    val vehicleId: UUID,
    val scheduledDate: LocalDate,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)
```

### Transportation Events

```kotlin
data class ShipmentDispatchedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val shipmentId: UUID,
    val routeId: UUID,
    val vehicleId: UUID,
    val driverId: UUID,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)

data class ShipmentDeliveredEvent(
    val eventId: UUID = UUID.randomUUID(),
    val shipmentId: UUID,
    val deliveryDate: LocalDate,
    val signature: String?,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)

data class RouteCompletedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val routeId: UUID,
    val driverId: UUID,
    val vehicleId: UUID,
    val completedStops: Int,
    val totalDistance: BigDecimal,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)
```

### Warehouse Events

```kotlin
data class InventoryReceivedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val productId: UUID,
    val warehouseId: UUID,
    val locationId: UUID,
    val quantity: BigDecimal,
    val lotNumber: String?,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)

data class InventoryPickedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val productId: UUID,
    val locationId: UUID,
    val quantity: BigDecimal,
    val shipmentId: UUID?,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)
```

---

## Integration Points

### With Supply Chain Service

**Inventory Synchronization:**

-   Warehouse inventory updates
-   Stock level monitoring
-   Replenishment triggers

### With Sales & CRM Service

**Order Fulfillment:**

-   Sales order shipments
-   Customer delivery tracking
-   Return processing

### With Financial Management Service

**Cost Accounting:**

-   Freight cost allocation
-   Warehouse operating costs
-   Vehicle maintenance expenses

### With HR Service (Administration)

**Driver Management:**

-   Driver employee records
-   Time and attendance
-   Performance tracking

---

## Business Rules

### Fleet Management

1. Vehicle must have valid registration and insurance
2. Driver must have valid license for vehicle class
3. Vehicle maintenance cannot be skipped
4. Regular safety inspections required
5. Fuel level monitoring for optimal routing

### Transportation

1. Shipments must have valid pickup and delivery addresses
2. Route optimization considers traffic and delivery windows
3. Driver hours of service regulations must be enforced
4. Temperature-sensitive goods require refrigerated vehicles
5. Proof of delivery required for completion

### Warehouse Management

1. Inventory locations must have sufficient capacity
2. FIFO/FEFO rules for perishable goods
3. Cycle counting for accuracy
4. Quarantine for damaged goods
5. Temperature monitoring for controlled environments

---

## Summary

The Logistics & Transportation service provides comprehensive supply chain execution capabilities:

### Three Core Domains:

1. **Fleet Management** - Vehicle and driver management with maintenance tracking
2. **Transportation Management** - Shipment planning, routing, and delivery execution
3. **Warehouse Management** - Inventory location, storage, and warehouse operations

### Key Features:

-   Real-time vehicle and shipment tracking
-   Route optimization and dispatch
-   Multi-warehouse inventory management
-   Driver assignment and performance tracking
-   Proof of delivery with signature capture
-   Temperature-controlled shipping support
-   Cost tracking and freight management

This foundation enables efficient logistics operations following SAP TM and WMS best practices.

---

**Status:** ✅ Complete
**Next:** DOMAIN-MODELS-OPERATIONS.md
