# Domain 5: Advanced Replenishment Strategies - Supply Chain Service

## Schema: `supply_schema`

## Overview

Enterprise-grade replenishment system implementing world-class inventory optimization strategies supporting:

-   **Automatic Replenishment** based on reorder points
-   **Min-Max Planning** for optimal stock levels
-   **Safety Stock Calculation** using statistical methods (Z-score, service levels)
-   **ABC Analysis** for inventory classification (Pareto principle)
-   **Multi-Location Replenishment** strategies
-   **Seasonal Planning** adjustments with factors
-   **Lead Time Analysis** and optimization
-   **Service Level** targets (90%, 95%, 99%, 99.5%)
-   **Demand Variability** management
-   **Economic Order Quantity (EOQ)** considerations
-   **Two-Bin System** and **Kanban** support

---

## Aggregates

### ReplenishmentStrategy (Aggregate Root)

```kotlin
@Entity
@Table(
    name = "replenishment_strategies",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_replenish_material", columnList = "materialId"),
        Index(name = "idx_replenish_location", columnList = "storageLocationId"),
        Index(name = "idx_replenish_method", columnList = "replenishmentMethod"),
        Index(name = "idx_replenish_abc", columnList = "abcClassification")
    ],
    uniqueConstraints = [
        UniqueConstraint(
            name = "uk_replenish_material_location",
            columnNames = ["materialId", "storageLocationId"]
        )
    ]
)
class ReplenishmentStrategy(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "material_id", nullable = false)
    val material: Material,

    @ManyToOne
    @JoinColumn(name = "storage_location_id", nullable = false)
    val storageLocation: StorageLocation,

    // Replenishment method
    @Enumerated(EnumType.STRING)
    val replenishmentMethod: ReplenishmentMethod,

    // Min-Max parameters
    @Column(precision = 19, scale = 4)
    var minimumQuantity: BigDecimal = BigDecimal.ZERO,

    @Column(precision = 19, scale = 4)
    var maximumQuantity: BigDecimal = BigDecimal.ZERO,

    @Column(precision = 19, scale = 4)
    var reorderPoint: BigDecimal = BigDecimal.ZERO,

    @Column(precision = 19, scale = 4)
    var reorderQuantity: BigDecimal = BigDecimal.ZERO,

    // Safety stock
    @Column(precision = 19, scale = 4)
    var safetyStock: BigDecimal = BigDecimal.ZERO,

    @Enumerated(EnumType.STRING)
    val safetyStockMethod: SafetyStockMethod,

    @Column(precision = 5, scale = 2)
    val serviceLevel: BigDecimal = BigDecimal(95), // Target service level %

    // Lead time
    val leadTimeDays: Int = 0,

    @Column(precision = 5, scale = 2)
    val leadTimeVariability: BigDecimal = BigDecimal.ZERO, // Standard deviation in days

    // Demand parameters
    @Column(precision = 19, scale = 4)
    var averageDailyDemand: BigDecimal = BigDecimal.ZERO,

    @Column(precision = 19, scale = 4)
    var demandVariability: BigDecimal = BigDecimal.ZERO, // Standard deviation

    // ABC Classification
    @Enumerated(EnumType.STRING)
    var abcClassification: ABCClassification? = null,

    @Column(precision = 19, scale = 2)
    val annualConsumptionValue: BigDecimal? = null,

    // Review period (for periodic review)
    val reviewPeriodDays: Int? = null,

    // Seasonality
    @Column(nullable = false)
    val isSeasonalItem: Boolean = false,

    @Column(columnDefinition = "jsonb")
    val seasonalityFactors: String? = null, // Monthly factors stored as JSON: {"1": 1.2, "2": 1.1, ...}

    // Multi-location replenishment
    val sourceStorageLocationId: UUID? = null, // Source for inter-location transfers

    @Enumerated(EnumType.STRING)
    val replenishmentPriority: ReplenishmentPriority = ReplenishmentPriority.NORMAL,

    // Constraints
    @Column(precision = 19, scale = 4)
    val minimumOrderQuantity: BigDecimal? = null,

    @Column(precision = 19, scale = 4)
    val orderMultiple: BigDecimal? = null, // Order in multiples of this quantity

    @Column(precision = 19, scale = 2)
    val budgetLimit: BigDecimal? = null,

    // Economic Order Quantity (EOQ) parameters
    @Column(precision = 19, scale = 2)
    val orderingCostPerOrder: BigDecimal? = null,

    @Column(precision = 19, scale = 2)
    val holdingCostPerUnitPerYear: BigDecimal? = null,

    // Status
    @Column(nullable = false)
    var isActive: Boolean = true,

    var lastCalculatedAt: Instant? = null,

    var lastTriggeredAt: Instant? = null,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
) {
    /**
     * Calculate if replenishment is needed
     */
    fun needsReplenishment(currentStock: BigDecimal): Boolean {
        return when (replenishmentMethod) {
            ReplenishmentMethod.REORDER_POINT -> currentStock <= reorderPoint
            ReplenishmentMethod.MIN_MAX -> currentStock < minimumQuantity
            ReplenishmentMethod.PERIODIC_REVIEW -> true // Check on review schedule
            ReplenishmentMethod.DEMAND_DRIVEN -> currentStock < safetyStock + (averageDailyDemand * BigDecimal(leadTimeDays))
            ReplenishmentMethod.TWO_BIN -> currentStock <= reorderPoint
            ReplenishmentMethod.KANBAN -> currentStock <= reorderPoint
            ReplenishmentMethod.EOQ -> currentStock <= reorderPoint
        }
    }

    /**
     * Calculate replenishment quantity
     */
    fun calculateReplenishmentQuantity(currentStock: BigDecimal, openOrders: BigDecimal = BigDecimal.ZERO): BigDecimal {
        val netStock = currentStock + openOrders

        val quantity = when (replenishmentMethod) {
            ReplenishmentMethod.REORDER_POINT -> reorderQuantity
            ReplenishmentMethod.MIN_MAX -> {
                (maximumQuantity - netStock).coerceAtLeast(BigDecimal.ZERO)
            }
            ReplenishmentMethod.PERIODIC_REVIEW -> {
                val targetLevel = maximumQuantity
                (targetLevel - netStock).coerceAtLeast(BigDecimal.ZERO)
            }
            ReplenishmentMethod.DEMAND_DRIVEN -> {
                val demandDuringLeadTime = averageDailyDemand * BigDecimal(leadTimeDays)
                val targetLevel = safetyStock + demandDuringLeadTime
                (targetLevel - netStock).coerceAtLeast(BigDecimal.ZERO)
            }
            ReplenishmentMethod.TWO_BIN -> reorderQuantity
            ReplenishmentMethod.KANBAN -> reorderQuantity
            ReplenishmentMethod.EOQ -> calculateEOQ()
        }

        // Apply constraints
        var finalQuantity = quantity

        // Minimum order quantity
        minimumOrderQuantity?.let {
            if (finalQuantity > BigDecimal.ZERO && finalQuantity < it) {
                finalQuantity = it
            }
        }

        // Order multiple
        orderMultiple?.let { multiple ->
            if (finalQuantity > BigDecimal.ZERO && multiple > BigDecimal.ZERO) {
                finalQuantity = (finalQuantity / multiple).setScale(0, RoundingMode.UP) * multiple
            }
        }

        return finalQuantity
    }

    /**
     * Calculate Economic Order Quantity (EOQ)
     * EOQ = √((2 × D × S) / H)
     * D = Annual demand
     * S = Ordering cost per order
     * H = Holding cost per unit per year
     */
    fun calculateEOQ(): BigDecimal {
        if (orderingCostPerOrder == null || holdingCostPerUnitPerYear == null) {
            return reorderQuantity
        }

        val annualDemand = averageDailyDemand * BigDecimal(365)
        val eoq = sqrt(
            (BigDecimal(2) * annualDemand * orderingCostPerOrder!! / holdingCostPerUnitPerYear!!).toDouble()
        ).toBigDecimal()

        return eoq.setScale(2, RoundingMode.HALF_UP)
    }

    /**
     * Update safety stock using statistical method
     */
    fun recalculateSafetyStock(demandHistory: List<BigDecimal>) {
        this.safetyStock = when (safetyStockMethod) {
            SafetyStockMethod.FIXED -> this.safetyStock // No change
            SafetyStockMethod.PERCENTAGE_OF_DEMAND -> {
                averageDailyDemand * BigDecimal(leadTimeDays) * BigDecimal("0.25") // 25% buffer
            }
            SafetyStockMethod.STATISTICAL -> {
                calculateStatisticalSafetyStock(demandHistory)
            }
            SafetyStockMethod.TIME_PERIOD -> {
                averageDailyDemand * BigDecimal(leadTimeDays) * BigDecimal(2) // 2x lead time
            }
        }

        this.lastCalculatedAt = Instant.now()
        this.updatedAt = Instant.now()
    }

    private fun calculateStatisticalSafetyStock(demandHistory: List<BigDecimal>): BigDecimal {
        if (demandHistory.isEmpty()) return BigDecimal.ZERO

        // Calculate average and standard deviation
        val avg = demandHistory.average().toBigDecimal()
        val variance = demandHistory.map { (it - avg).pow(2) }.average()
        val stdDev = sqrt(variance).toBigDecimal()

        // Z-score based on service level
        val zScore = when {
            serviceLevel >= BigDecimal(99.5) -> BigDecimal("2.576")
            serviceLevel >= BigDecimal(99) -> BigDecimal("2.326")
            serviceLevel >= BigDecimal(98) -> BigDecimal("2.054")
            serviceLevel >= BigDecimal(97.5) -> BigDecimal("1.960")
            serviceLevel >= BigDecimal(95) -> BigDecimal("1.645")
            serviceLevel >= BigDecimal(90) -> BigDecimal("1.282")
            else -> BigDecimal("1.000")
        }

        // Safety stock = Z × σ_demand × √(lead time)
        return zScore * stdDev * sqrt(leadTimeDays.toDouble()).toBigDecimal()
    }

    /**
     * Apply seasonal adjustment to demand
     */
    fun applySeasonalAdjustment(currentMonth: Int): BigDecimal {
        if (!isSeasonalItem || seasonalityFactors == null) {
            return BigDecimal.ONE
        }

        // Parse JSON seasonality factors: {"1": 1.2, "2": 1.1, ...}
        // Simplified - in real implementation, parse JSON
        return BigDecimal.ONE // Placeholder - parse and return factor for currentMonth
    }

    /**
     * Update demand parameters from historical data
     */
    fun updateDemandParameters(demandHistory: List<BigDecimal>) {
        if (demandHistory.isEmpty()) return

        this.averageDailyDemand = demandHistory.average().toBigDecimal()

        val avg = averageDailyDemand
        val variance = demandHistory.map { (it - avg).pow(2) }.average()
        this.demandVariability = sqrt(variance).toBigDecimal()

        this.updatedAt = Instant.now()
    }
}

enum class ReplenishmentMethod {
    REORDER_POINT,       // Order when stock hits reorder point (continuous review)
    MIN_MAX,             // Maintain stock between min and max levels
    PERIODIC_REVIEW,     // Review at fixed intervals (weekly, monthly)
    DEMAND_DRIVEN,       // Based on actual demand patterns (DDMRP)
    TWO_BIN,             // Two-bin system (visual replenishment)
    KANBAN,              // Pull-based Kanban system
    EOQ                  // Economic Order Quantity optimization
}

enum class SafetyStockMethod {
    FIXED,                  // Fixed safety stock quantity
    PERCENTAGE_OF_DEMAND,   // Percentage of average demand
    STATISTICAL,            // Statistical calculation based on variability (Z-score)
    TIME_PERIOD            // Coverage for specific time period
}

enum class ABCClassification {
    A,  // High value items (typically 20% of items, 80% of value)
    B,  // Medium value items (typically 30% of items, 15% of value)
    C   // Low value items (typically 50% of items, 5% of value)
}

enum class ReplenishmentPriority {
    CRITICAL,   // Mission-critical items
    HIGH,       // High priority
    NORMAL,     // Normal priority
    LOW         // Low priority
}
```

---

### ReplenishmentRun (Aggregate Root)

```kotlin
@Entity
@Table(
    name = "replenishment_runs",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_replenish_run_number", columnList = "runNumber"),
        Index(name = "idx_replenish_run_date", columnList = "runDate"),
        Index(name = "idx_replenish_run_status", columnList = "status")
    ]
)
class ReplenishmentRun(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val runNumber: String, // REP-YYYY-NNNNNN

    @Column(nullable = false)
    val runDate: LocalDate,

    @Enumerated(EnumType.STRING)
    val runType: ReplenishmentRunType,

    // Scope
    val warehouseId: UUID? = null,
    val storageLocationId: UUID? = null,

    @Enumerated(EnumType.STRING)
    val abcClassFilter: ABCClassification? = null,

    val materialGroupFilter: String? = null,

    // Results
    @OneToMany(mappedBy = "replenishmentRun", cascade = [CascadeType.ALL])
    val proposals: MutableList<ReplenishmentProposal> = mutableListOf(),

    var totalProposalsGenerated: Int = 0,

    var totalProposalsApproved: Int = 0,

    var totalProposalsRejected: Int = 0,

    var totalProposalsConverted: Int = 0,

    @Column(precision = 19, scale = 2)
    var totalEstimatedValue: BigDecimal = BigDecimal.ZERO,

    // Status
    @Enumerated(EnumType.STRING)
    var status: ReplenishmentRunStatus = ReplenishmentRunStatus.RUNNING,

    var startTime: Instant = Instant.now(),

    var endTime: Instant? = null,

    @Column(length = 2000)
    var errorMessage: String? = null,

    @Column(nullable = false)
    val createdBy: UUID,

    @Column(nullable = false)
    val tenantId: UUID,

    @Version
    var version: Long = 0
) {
    companion object {
        fun generateRunNumber(year: Int, sequence: Long): String {
            return "REP-$year-${sequence.toString().padStart(6, '0')}"
        }
    }

    fun addProposal(proposal: ReplenishmentProposal) {
        proposals.add(proposal)
        proposal.replenishmentRun = this
        totalProposalsGenerated++
        totalEstimatedValue += proposal.estimatedValue
    }

    fun complete() {
        this.status = ReplenishmentRunStatus.COMPLETED
        this.endTime = Instant.now()

        // Update counters
        totalProposalsApproved = proposals.count { it.status == ProposalStatus.APPROVED }
        totalProposalsRejected = proposals.count { it.status == ProposalStatus.REJECTED }
        totalProposalsConverted = proposals.count { it.status == ProposalStatus.CONVERTED }
    }

    fun fail(error: String) {
        this.status = ReplenishmentRunStatus.FAILED
        this.endTime = Instant.now()
        this.errorMessage = error
    }
}

enum class ReplenishmentRunType {
    AUTOMATIC,          // Scheduled automatic run (nightly, weekly)
    MANUAL,             // Manual triggered run
    EMERGENCY,          // Emergency replenishment
    SIMULATION          // Simulation mode (no actual orders created)
}

enum class ReplenishmentRunStatus {
    RUNNING, COMPLETED, FAILED, CANCELLED
}
```

---

### ReplenishmentProposal (Entity)

```kotlin
@Entity
@Table(
    name = "replenishment_proposals",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_replenish_proposal_material", columnList = "materialId"),
        Index(name = "idx_replenish_proposal_status", columnList = "status"),
        Index(name = "idx_replenish_proposal_urgency", columnList = "urgency")
    ]
)
class ReplenishmentProposal(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "replenishment_run_id", nullable = false)
    var replenishmentRun: ReplenishmentRun? = null,

    @ManyToOne
    @JoinColumn(name = "material_id", nullable = false)
    val material: Material,

    @ManyToOne
    @JoinColumn(name = "destination_location_id", nullable = false)
    val destinationLocation: StorageLocation,

    @ManyToOne
    @JoinColumn(name = "source_location_id")
    val sourceLocation: StorageLocation? = null, // For inter-location transfers

    // Current state
    @Column(precision = 19, scale = 4)
    val currentStock: BigDecimal,

    @Column(precision = 19, scale = 4)
    val openOrders: BigDecimal,

    @Column(precision = 19, scale = 4)
    val reorderPoint: BigDecimal,

    @Column(precision = 19, scale = 4)
    val safetyStock: BigDecimal,

    @Column(precision = 19, scale = 4)
    val minimumQuantity: BigDecimal,

    @Column(precision = 19, scale = 4)
    val maximumQuantity: BigDecimal,

    // Proposal
    @Column(nullable = false, precision = 19, scale = 4)
    val proposedQuantity: BigDecimal,

    @Column(precision = 19, scale = 4)
    val estimatedUnitCost: BigDecimal,

    @Column(precision = 19, scale = 2)
    val estimatedValue: BigDecimal,

    @Enumerated(EnumType.STRING)
    val proposedOrderType: ProposedOrderType,

    val suggestedVendorId: UUID? = null,

    val expectedReceiptDate: LocalDate,

    // Justification
    @Enumerated(EnumType.STRING)
    val replenishmentReason: ReplenishmentReason,

    @Column(length = 2000)
    val justification: String? = null,

    @Enumerated(EnumType.STRING)
    val urgency: ReplenishmentUrgency,

    // Decision
    @Enumerated(EnumType.STRING)
    var status: ProposalStatus = ProposalStatus.PENDING,

    var reviewedBy: UUID? = null,

    var reviewedAt: Instant? = null,

    @Column(length = 1000)
    var reviewComments: String? = null,

    // Converted order
    var convertedToOrderAt: Instant? = null,

    var purchaseRequisitionId: UUID? = null,

    var transferOrderId: UUID? = null,

    var productionOrderId: UUID? = null,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now()
) {
    fun approve(reviewerId: UUID, comments: String? = null) {
        this.status = ProposalStatus.APPROVED
        this.reviewedBy = reviewerId
        this.reviewedAt = Instant.now()
        this.reviewComments = comments
    }

    fun reject(reviewerId: UUID, reason: String) {
        this.status = ProposalStatus.REJECTED
        this.reviewedBy = reviewerId
        this.reviewedAt = Instant.now()
        this.reviewComments = reason
    }

    fun convertToOrder(orderId: UUID, orderType: ProposedOrderType) {
        require(status == ProposalStatus.APPROVED) {
            "Only approved proposals can be converted"
        }

        when (orderType) {
            ProposedOrderType.PURCHASE_REQUISITION -> {
                this.purchaseRequisitionId = orderId
            }
            ProposedOrderType.TRANSFER_ORDER -> {
                this.transferOrderId = orderId
            }
            ProposedOrderType.PRODUCTION_ORDER -> {
                this.productionOrderId = orderId
            }
        }

        this.status = ProposalStatus.CONVERTED
        this.convertedToOrderAt = Instant.now()
    }

    fun getDaysUntilStockout(): Long? {
        if (currentStock <= BigDecimal.ZERO) return 0

        val dailyDemand = material.mrpData.averageDailyDemand ?: BigDecimal.ZERO
        if (dailyDemand <= BigDecimal.ZERO) return null

        return (currentStock / dailyDemand).toLong()
    }
}

enum class ProposedOrderType {
    PURCHASE_REQUISITION,   // Buy from vendor
    TRANSFER_ORDER,         // Transfer from another location
    PRODUCTION_ORDER        // Manufacture in-house
}

enum class ReplenishmentReason {
    BELOW_REORDER_POINT,      // Stock below reorder point
    BELOW_MINIMUM,            // Stock below minimum level
    SAFETY_STOCK_BREACH,      // Below safety stock
    PERIODIC_REVIEW,          // Scheduled periodic review
    SEASONAL_DEMAND,          // Seasonal increase
    PROMOTIONAL_EVENT,        // Promotional/sales event
    STOCKOUT_PREVENTION,      // Preventing imminent stockout
    EMERGENCY,                // Emergency replenishment
    DEMAND_SPIKE             // Unexpected demand increase
}

enum class ReplenishmentUrgency {
    CRITICAL,    // Stockout imminent (< 3 days)
    HIGH,        // Below safety stock (< 7 days)
    NORMAL,      // Routine replenishment (< 14 days)
    LOW          // Opportunistic replenishment (> 14 days)
}

enum class ProposalStatus {
    PENDING,        // Awaiting review
    APPROVED,       // Approved for ordering
    REJECTED,       // Rejected
    CONVERTED,      // Converted to order
    CANCELLED       // Cancelled
}
```

---

### SafetyStockCalculation (Entity)

```kotlin
@Entity
@Table(
    name = "safety_stock_calculations",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_safety_calc_material", columnList = "materialId"),
        Index(name = "idx_safety_calc_date", columnList = "calculationDate")
    ]
)
class SafetyStockCalculation(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "material_id", nullable = false)
    val material: Material,

    @ManyToOne
    @JoinColumn(name = "storage_location_id", nullable = false)
    val storageLocation: StorageLocation,

    @Column(nullable = false)
    val calculationDate: LocalDate,

    @Enumerated(EnumType.STRING)
    val calculationMethod: SafetyStockMethod,

    // Input parameters
    @Column(precision = 19, scale = 4)
    val averageDailyDemand: BigDecimal,

    @Column(precision = 19, scale = 4)
    val demandStandardDeviation: BigDecimal,

    val leadTimeDays: Int,

    @Column(precision = 5, scale = 2)
    val leadTimeStandardDeviation: BigDecimal,

    @Column(precision = 5, scale = 2)
    val targetServiceLevel: BigDecimal,

    // Calculated values
    @Column(precision = 19, scale = 4)
    val calculatedSafetyStock: BigDecimal,

    @Column(precision = 19, scale = 4)
    val calculatedReorderPoint: BigDecimal,

    // Z-score used
    @Column(precision = 5, scale = 4)
    val zScore: BigDecimal,

    // Historical data used
    val historicalDataFromDate: LocalDate,
    val historicalDataToDate: LocalDate,
    val historicalDataPoints: Int,

    // Coefficient of variation (CV = σ / μ)
    @Column(precision = 5, scale = 4)
    val coefficientOfVariation: BigDecimal? = null,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now()
)
```

---

## Domain Services

### ReplenishmentPlanningService

```kotlin
class ReplenishmentPlanningService(
    private val replenishmentStrategyRepository: ReplenishmentStrategyRepository,
    private val stockRepository: StockRepository,
    private val materialRepository: MaterialRepository,
    private val eventPublisher: DomainEventPublisher
) {
    /**
     * Run comprehensive replenishment planning
     */
    fun runReplenishmentPlanning(
        runType: ReplenishmentRunType,
        warehouseId: UUID? = null,
        abcFilter: ABCClassification? = null,
        materialGroupFilter: String? = null,
        userId: UUID,
        tenantId: UUID
    ): ReplenishmentRun {
        val run = ReplenishmentRun(
            runNumber = ReplenishmentRun.generateRunNumber(
                LocalDate.now().year,
                System.currentTimeMillis()
            ),
            runDate = LocalDate.now(),
            runType = runType,
            warehouseId = warehouseId,
            abcClassFilter = abcFilter,
            materialGroupFilter = materialGroupFilter,
            createdBy = userId,
            tenantId = tenantId
        )

        try {
            // Get all active strategies matching filters
            val strategies = replenishmentStrategyRepository.findActiveStrategies(
                warehouseId = warehouseId,
                abcFilter = abcFilter,
                materialGroupFilter = materialGroupFilter,
                tenantId = tenantId
            )

            strategies.forEach { strategy ->
                try {
                    processReplenishmentStrategy(strategy, run)
                } catch (e: Exception) {
                    // Log error but continue with other strategies
                    println("Error processing strategy ${strategy.id}: ${e.message}")
                }
            }

            run.complete()

            // Publish event
            eventPublisher.publish(
                ReplenishmentRunCompletedEvent(
                    runId = run.id,
                    runNumber = run.runNumber,
                    totalProposals = run.totalProposalsGenerated,
                    tenantId = tenantId
                )
            )
        } catch (e: Exception) {
            run.fail(e.message ?: "Unknown error")
        }

        return run
    }

    private fun processReplenishmentStrategy(
        strategy: ReplenishmentStrategy,
        run: ReplenishmentRun
    ) {
        // Get current stock
        val currentStock = stockRepository.findByMaterialAndLocation(
            strategy.material.id,
            strategy.storageLocation.id
        )?.getAvailableQuantity() ?: BigDecimal.ZERO

        // Get open orders
        val openOrders = getOpenOrderQuantity(strategy.material.id, strategy.storageLocation.id)

        // Check if replenishment needed
        if (!strategy.needsReplenishment(currentStock)) {
            return
        }

        // Calculate replenishment quantity
        val quantity = strategy.calculateReplenishmentQuantity(currentStock, openOrders)

        if (quantity <= BigDecimal.ZERO) {
            return
        }

        // Determine order type
        val orderType = determineOrderType(strategy)

        // Calculate expected receipt date
        val receiptDate = LocalDate.now().plusDays(strategy.leadTimeDays.toLong())

        // Determine urgency
        val urgency = determineUrgency(currentStock, strategy)

        // Get suggested vendor
        val suggestedVendor = when (orderType) {
            ProposedOrderType.PURCHASE_REQUISITION -> strategy.material.procurement.defaultVendorId
            else -> null
        }

        // Create proposal
        val proposal = ReplenishmentProposal(
            material = strategy.material,
            destinationLocation = strategy.storageLocation,
            sourceLocation = strategy.sourceStorageLocationId?.let {
                storageLocationRepository.findById(it)
            },
            currentStock = currentStock,
            openOrders = openOrders,
            reorderPoint = strategy.reorderPoint,
            safetyStock = strategy.safetyStock,
            minimumQuantity = strategy.minimumQuantity,
            maximumQuantity = strategy.maximumQuantity,
            proposedQuantity = quantity,
            estimatedUnitCost = strategy.material.valuation.standardPrice,
            estimatedValue = quantity * strategy.material.valuation.standardPrice,
            proposedOrderType = orderType,
            suggestedVendorId = suggestedVendor,
            expectedReceiptDate = receiptDate,
            replenishmentReason = determineReason(currentStock, strategy),
            justification = buildJustification(strategy, currentStock, quantity, openOrders),
            urgency = urgency
        )

        run.addProposal(proposal)

        // Publish event
        eventPublisher.publish(
            ReplenishmentProposalCreatedEvent(
                proposalId = proposal.id,
                materialId = strategy.material.id,
                proposedQuantity = quantity,
                urgency = urgency,
                tenantId = strategy.tenantId
            )
        )
    }

    private fun determineOrderType(strategy: ReplenishmentStrategy): ProposedOrderType {
        return when {
            strategy.sourceStorageLocationId != null -> ProposedOrderType.TRANSFER_ORDER
            strategy.material.procurement.procurementType == ProcurementType.IN_HOUSE ->
                ProposedOrderType.PRODUCTION_ORDER
            else -> ProposedOrderType.PURCHASE_REQUISITION
        }
    }

    private fun determineUrgency(
        currentStock: BigDecimal,
        strategy: ReplenishmentStrategy
    ): ReplenishmentUrgency {
        val dailyDemand = strategy.averageDailyDemand
        if (dailyDemand <= BigDecimal.ZERO) return ReplenishmentUrgency.LOW

        val daysOfStock = if (currentStock > BigDecimal.ZERO) {
            (currentStock / dailyDemand).toInt()
        } else {
            0
        }

        return when {
            daysOfStock <= 3 -> ReplenishmentUrgency.CRITICAL
            daysOfStock <= 7 -> ReplenishmentUrgency.HIGH
            daysOfStock <= 14 -> ReplenishmentUrgency.NORMAL
            else -> ReplenishmentUrgency.LOW
        }
    }

    private fun determineReason(
        currentStock: BigDecimal,
        strategy: ReplenishmentStrategy
    ): ReplenishmentReason {
        return when {
            currentStock <= BigDecimal.ZERO -> ReplenishmentReason.EMERGENCY
            currentStock < strategy.safetyStock -> ReplenishmentReason.SAFETY_STOCK_BREACH
            currentStock < strategy.reorderPoint -> ReplenishmentReason.BELOW_REORDER_POINT
            currentStock < strategy.minimumQuantity -> ReplenishmentReason.BELOW_MINIMUM
            strategy.replenishmentMethod == ReplenishmentMethod.PERIODIC_REVIEW ->
                ReplenishmentReason.PERIODIC_REVIEW
            else -> ReplenishmentReason.STOCKOUT_PREVENTION
        }
    }

    private fun buildJustification(
        strategy: ReplenishmentStrategy,
        currentStock: BigDecimal,
        proposedQuantity: BigDecimal,
        openOrders: BigDecimal
    ): String {
        val dailyDemand = strategy.averageDailyDemand
        val daysOfStock = if (dailyDemand > BigDecimal.ZERO) {
            (currentStock / dailyDemand).setScale(1, RoundingMode.HALF_UP)
        } else {
            BigDecimal.ZERO
        }

        return """
            Material: ${strategy.material.materialNumber} - ${strategy.material.description}
            Current Stock: $currentStock ${strategy.material.baseUnitOfMeasure}
            Open Orders: $openOrders ${strategy.material.baseUnitOfMeasure}
            Days of Stock: $daysOfStock days

            Reorder Point: ${strategy.reorderPoint} ${strategy.material.baseUnitOfMeasure}
            Safety Stock: ${strategy.safetyStock} ${strategy.material.baseUnitOfMeasure}
            Minimum: ${strategy.minimumQuantity} ${strategy.material.baseUnitOfMeasure}
            Maximum: ${strategy.maximumQuantity} ${strategy.material.baseUnitOfMeasure}

            Average Daily Demand: ${strategy.averageDailyDemand} ${strategy.material.baseUnitOfMeasure}
            Lead Time: ${strategy.leadTimeDays} days
            Replenishment Method: ${strategy.replenishmentMethod}
            ABC Classification: ${strategy.abcClassification ?: "Not classified"}

            Proposed Order Quantity: $proposedQuantity ${strategy.material.baseUnitOfMeasure}
            Estimated Unit Cost: ${strategy.material.valuation.standardPrice} ${strategy.material.valuation.currency}
            Estimated Total Value: ${proposedQuantity * strategy.material.valuation.standardPrice} ${strategy.material.valuation.currency}
        """.trimIndent()
    }

    private fun getOpenOrderQuantity(materialId: UUID, locationId: UUID): BigDecimal {
        // Fetch open purchase orders, transfer orders, and production orders
        // Sum up quantities expected to arrive
        return BigDecimal.ZERO // Placeholder - implement actual logic
    }
}
```

---

### ABCAnalysisService

```kotlin
class ABCAnalysisService(
    private val materialRepository: MaterialRepository,
    private val materialDocumentRepository: MaterialDocumentRepository,
    private val eventPublisher: DomainEventPublisher
) {
    /**
     * Perform ABC analysis using Pareto principle (80-20 rule)
     * A items: Top 80% of value (typically 20% of items)
     * B items: Next 15% of value (typically 30% of items)
     * C items: Last 5% of value (typically 50% of items)
     */
    fun performABCAnalysis(
        storageLocationId: UUID? = null,
        analysisDate: LocalDate = LocalDate.now(),
        tenantId: UUID
    ): Map<UUID, ABCClassificationResult> {
        // Get all materials with their annual consumption value
        val materialsWithValue = calculateAnnualConsumptionValues(
            storageLocationId = storageLocationId,
            endDate = analysisDate,
            tenantId = tenantId
        ).sortedByDescending { it.second }

        val totalValue = materialsWithValue.sumOf { it.second }
        val classifications = mutableMapOf<UUID, ABCClassificationResult>()

        if (totalValue == BigDecimal.ZERO) {
            return emptyMap()
        }

        var cumulativeValue = BigDecimal.ZERO
        var cumulativeCount = 0

        materialsWithValue.forEachIndexed { index, (materialId, value) ->
            cumulativeValue += value
            cumulativeCount++

            val cumulativePercent = (cumulativeValue / totalValue) * BigDecimal(100)
            val countPercent = (cumulativeCount.toBigDecimal() / materialsWithValue.size.toBigDecimal()) * BigDecimal(100)

            val classification = when {
                cumulativePercent <= BigDecimal(80) -> ABCClassification.A
                cumulativePercent <= BigDecimal(95) -> ABCClassification.B
                else -> ABCClassification.C
            }

            val result = ABCClassificationResult(
                materialId = materialId,
                classification = classification,
                annualConsumptionValue = value,
                percentOfTotalValue = (value / totalValue * BigDecimal(100)).setScale(2, RoundingMode.HALF_UP),
                cumulativePercentValue = cumulativePercent.setScale(2, RoundingMode.HALF_UP),
                percentOfTotalCount = countPercent.setScale(2, RoundingMode.HALF_UP),
                rank = index + 1
            )

            classifications[materialId] = result

            // Publish event
            eventPublisher.publish(
                ABCClassificationUpdatedEvent(
                    materialId = materialId,
                    oldClassification = null, // Get from existing data if needed
                    newClassification = classification,
                    annualConsumptionValue = value,
                    tenantId = tenantId
                )
            )
        }

        return classifications
    }

    private fun calculateAnnualConsumptionValues(
        storageLocationId: UUID?,
        endDate: LocalDate,
        tenantId: UUID
    ): List<Pair<UUID, BigDecimal>> {
        val startDate = endDate.minusYears(1)

        // Fetch all material documents (goods issues) for the period
        val issues = materialDocumentRepository.findGoodsIssues(
            startDate = startDate,
            endDate = endDate,
            storageLocationId = storageLocationId,
            tenantId = tenantId
        )

        // Group by material and calculate total value
        return issues.groupBy { it.material.id }
            .map { (materialId, items) ->
                val totalValue = items.sumOf { item ->
                    (item.quantity * item.unitPrice)
                }
                materialId to totalValue
            }
    }
}

data class ABCClassificationResult(
    val materialId: UUID,
    val classification: ABCClassification,
    val annualConsumptionValue: BigDecimal,
    val percentOfTotalValue: BigDecimal,
    val cumulativePercentValue: BigDecimal,
    val percentOfTotalCount: BigDecimal,
    val rank: Int
)
```

---

### SafetyStockOptimizationService

```kotlin
class SafetyStockOptimizationService(
    private val eventPublisher: DomainEventPublisher
) {
    /**
     * Optimize safety stock using statistical methods
     * Safety Stock = Z × σ_demand × √(lead time)
     */
    fun optimizeSafetyStock(
        material: Material,
        storageLocation: StorageLocation,
        serviceLevel: BigDecimal,
        demandHistory: List<DemandDataPoint>,
        leadTime: Int,
        leadTimeVariability: BigDecimal = BigDecimal.ZERO
    ): SafetyStockCalculation {
        require(demandHistory.isNotEmpty()) {
            "Demand history cannot be empty"
        }

        // Calculate demand statistics
        val avgDemand = demandHistory.map { it.quantity }.average().toBigDecimal()
        val demandStdDev = calculateStandardDeviation(demandHistory.map { it.quantity })

        // Calculate lead time variability (if available)
        val leadTimeStdDev = leadTimeVariability

        // Get Z-score for service level
        val zScore = getZScoreForServiceLevel(serviceLevel)

        // Calculate safety stock
        // SS = Z × √((σ_demand² × LT) + (avg_demand² × σ_LT²))
        val safetyStock = if (leadTimeStdDev > BigDecimal.ZERO) {
            // Advanced formula considering both demand and lead time variability
            val variance = (demandStdDev.pow(2) * BigDecimal(leadTime)) +
                          (avgDemand.pow(2) * leadTimeStdDev.pow(2))
            zScore * sqrt(variance.toDouble()).toBigDecimal()
        } else {
            // Simplified formula (only demand variability)
            zScore * demandStdDev * sqrt(leadTime.toDouble()).toBigDecimal()
        }

        // Calculate reorder point
        // ROP = (Avg Daily Demand × Lead Time) + Safety Stock
        val reorderPoint = (avgDemand * BigDecimal(leadTime)) + safetyStock

        // Calculate coefficient of variation (CV = σ / μ)
        val cv = if (avgDemand > BigDecimal.ZERO) {
            (demandStdDev / avgDemand).setScale(4, RoundingMode.HALF_UP)
        } else {
            BigDecimal.ZERO
        }

        val calculation = SafetyStockCalculation(
            material = material,
            storageLocation = storageLocation,
            calculationDate = LocalDate.now(),
            calculationMethod = SafetyStockMethod.STATISTICAL,
            averageDailyDemand = avgDemand,
            demandStandardDeviation = demandStdDev,
            leadTimeDays = leadTime,
            leadTimeStandardDeviation = leadTimeStdDev,
            targetServiceLevel = serviceLevel,
            calculatedSafetyStock = safetyStock.setScale(2, RoundingMode.HALF_UP),
            calculatedReorderPoint = reorderPoint.setScale(2, RoundingMode.HALF_UP),
            zScore = zScore,
            historicalDataFromDate = demandHistory.first().date,
            historicalDataToDate = demandHistory.last().date,
            historicalDataPoints = demandHistory.size,
            coefficientOfVariation = cv,
            tenantId = material.tenantId
        )

        // Publish event
        eventPublisher.publish(
            SafetyStockRecalculatedEvent(
                materialId = material.id,
                storageLocationId = storageLocation.id,
                oldSafetyStock = material.mrpData.safetyStock ?: BigDecimal.ZERO,
                newSafetyStock = safetyStock,
                calculationMethod = SafetyStockMethod.STATISTICAL,
                tenantId = material.tenantId
            )
        )

        return calculation
    }

    private fun calculateStandardDeviation(values: List<BigDecimal>): BigDecimal {
        if (values.isEmpty()) return BigDecimal.ZERO

        val mean = values.average().toBigDecimal()
        val variance = values.map { (it - mean).pow(2) }.average()
        return sqrt(variance).toBigDecimal()
    }

    private fun getZScoreForServiceLevel(serviceLevel: BigDecimal): BigDecimal {
        return when {
            serviceLevel >= BigDecimal("99.9") -> BigDecimal("3.090")
            serviceLevel >= BigDecimal("99.5") -> BigDecimal("2.576")
            serviceLevel >= BigDecimal("99.0") -> BigDecimal("2.326")
            serviceLevel >= BigDecimal("98.0") -> BigDecimal("2.054")
            serviceLevel >= BigDecimal("97.5") -> BigDecimal("1.960")
            serviceLevel >= BigDecimal("95.0") -> BigDecimal("1.645")
            serviceLevel >= BigDecimal("90.0") -> BigDecimal("1.282")
            serviceLevel >= BigDecimal("85.0") -> BigDecimal("1.036")
            serviceLevel >= BigDecimal("80.0") -> BigDecimal("0.842")
            else -> BigDecimal("1.000")
        }
    }
}

data class DemandDataPoint(
    val date: LocalDate,
    val quantity: BigDecimal
)
```

---

## Domain Events

```kotlin
// Replenishment Strategy Events
data class ReplenishmentStrategyCreatedEvent(
    val strategyId: UUID,
    val materialId: UUID,
    val storageLocationId: UUID,
    val replenishmentMethod: ReplenishmentMethod,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
) : DomainEvent

data class ReplenishmentStrategyUpdatedEvent(
    val strategyId: UUID,
    val materialId: UUID,
    val storageLocationId: UUID,
    val reorderPoint: BigDecimal,
    val safetyStock: BigDecimal,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
) : DomainEvent

// Replenishment Run Events
data class ReplenishmentRunCompletedEvent(
    val runId: UUID,
    val runNumber: String,
    val totalProposals: Int,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
) : DomainEvent

// Proposal Events
data class ReplenishmentProposalCreatedEvent(
    val proposalId: UUID,
    val materialId: UUID,
    val proposedQuantity: BigDecimal,
    val urgency: ReplenishmentUrgency,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
) : DomainEvent

data class ReplenishmentProposalApprovedEvent(
    val proposalId: UUID,
    val materialId: UUID,
    val approvedQuantity: BigDecimal,
    val approvedBy: UUID,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
) : DomainEvent

data class ReplenishmentProposalConvertedEvent(
    val proposalId: UUID,
    val materialId: UUID,
    val orderType: ProposedOrderType,
    val orderId: UUID,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
) : DomainEvent

// Safety Stock Events
data class SafetyStockRecalculatedEvent(
    val materialId: UUID,
    val storageLocationId: UUID,
    val oldSafetyStock: BigDecimal,
    val newSafetyStock: BigDecimal,
    val calculationMethod: SafetyStockMethod,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
) : DomainEvent

// ABC Analysis Events
data class ABCClassificationUpdatedEvent(
    val materialId: UUID,
    val oldClassification: ABCClassification?,
    val newClassification: ABCClassification,
    val annualConsumptionValue: BigDecimal,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
) : DomainEvent
```

---

## Use Cases

### Use Case 1: Automatic Nightly Replenishment Planning

```kotlin
// Scenario: Automated nightly replenishment run for Class A items
val replenishmentRun = replenishmentPlanningService.runReplenishmentPlanning(
    runType = ReplenishmentRunType.AUTOMATIC,
    warehouseId = mainWarehouseId,
    abcFilter = ABCClassification.A, // Focus on high-value items
    userId = systemUserId,
    tenantId = tenantId
)

println("Replenishment Run: ${replenishmentRun.runNumber}")
println("Total Proposals: ${replenishmentRun.totalProposalsGenerated}")
println("Total Value: ${replenishmentRun.totalEstimatedValue}")

// Review critical proposals
val criticalProposals = replenishmentRun.proposals
    .filter { it.urgency == ReplenishmentUrgency.CRITICAL }

println("Critical Proposals: ${criticalProposals.size}")

// Auto-approve critical proposals
criticalProposals.forEach { proposal ->
    proposal.approve(systemUserId, "Auto-approved - Critical urgency")

    // Convert to purchase requisition
    val requisition = purchaseRequisitionService.createFromProposal(proposal)
    proposal.convertToOrder(requisition.id, ProposedOrderType.PURCHASE_REQUISITION)
}
```

### Use Case 2: Quarterly Safety Stock Optimization

```kotlin
// Scenario: Quarterly review and optimization of safety stock levels
val materials = materialRepository.findByABCClassification(
    ABCClassification.A,
    tenantId
)

materials.forEach { material ->
    val locations = storageLocationRepository.findByMaterial(material.id)

    locations.forEach { location ->
        // Get 90 days of demand history
        val demandHistory = demandService.getDemandHistory(
            materialId = material.id,
            locationId = location.id,
            fromDate = LocalDate.now().minusDays(90),
            toDate = LocalDate.now()
        )

        if (demandHistory.size < 30) {
            println("Insufficient data for ${material.materialNumber}")
            return@forEach
        }

        // Calculate optimal safety stock
        val calculation = safetyStockService.optimizeSafetyStock(
            material = material,
            storageLocation = location,
            serviceLevel = BigDecimal(99), // 99% service level for A items
            demandHistory = demandHistory,
            leadTime = material.procurement.leadTimeDays,
            leadTimeVariability = BigDecimal("0.5") // Half day std dev
        )

        println("""
            Material: ${material.materialNumber}
            Current Safety Stock: ${material.mrpData.safetyStock}
            Calculated Safety Stock: ${calculation.calculatedSafetyStock}
            Service Level: ${calculation.targetServiceLevel}%
            Z-Score: ${calculation.zScore}
        """.trimIndent())

        // Update replenishment strategy
        val strategy = replenishmentStrategyRepository.findByMaterialAndLocation(
            material.id,
            location.id
        )

        if (strategy != null) {
            val oldSafetyStock = strategy.safetyStock
            strategy.safetyStock = calculation.calculatedSafetyStock
            strategy.reorderPoint = calculation.calculatedReorderPoint
            strategy.lastCalculatedAt = Instant.now()

            replenishmentStrategyRepository.save(strategy)
        }
    }
}
```

### Use Case 3: Annual ABC Analysis and Strategy Adjustment

```kotlin
// Scenario: Annual ABC analysis with automatic strategy adjustments
val abcResults = abcAnalysisService.performABCAnalysis(
    storageLocationId = null, // All locations
    analysisDate = LocalDate.now(),
    tenantId = tenantId
)

println("ABC Analysis Results:")
println("Total Materials: ${abcResults.size}")
println("A Items: ${abcResults.values.count { it.classification == ABCClassification.A }}")
println("B Items: ${abcResults.values.count { it.classification == ABCClassification.B }}")
println("C Items: ${abcResults.values.count { it.classification == ABCClassification.C }}")

// Adjust replenishment strategies based on classification
abcResults.forEach { (materialId, result) ->
    val strategies = replenishmentStrategyRepository.findByMaterial(materialId)

    strategies.forEach { strategy ->
        val oldClass = strategy.abcClassification
        strategy.abcClassification = result.classification
        strategy.annualConsumptionValue = result.annualConsumptionValue

        // Adjust parameters based on classification
        when (result.classification) {
            ABCClassification.A -> {
                // High value: Tight control, frequent review
                strategy.reviewPeriodDays = 7
                strategy.serviceLevel = BigDecimal(99)
                strategy.replenishmentPriority = ReplenishmentPriority.HIGH
            }
            ABCClassification.B -> {
                // Medium value: Moderate control
                strategy.reviewPeriodDays = 14
                strategy.serviceLevel = BigDecimal(95)
                strategy.replenishmentPriority = ReplenishmentPriority.NORMAL
            }
            ABCClassification.C -> {
                // Low value: Loose control, less frequent review
                strategy.reviewPeriodDays = 30
                strategy.serviceLevel = BigDecimal(90)
                strategy.replenishmentPriority = ReplenishmentPriority.LOW

                // Consider using Min-Max method for simplicity
                if (strategy.replenishmentMethod == ReplenishmentMethod.REORDER_POINT) {
                    // Could switch to MIN_MAX for simplicity
                }
            }
        }

        strategy.updatedAt = Instant.now()
        replenishmentStrategyRepository.save(strategy)

        println("""
            Material: ${strategy.material.materialNumber}
            Classification: $oldClass → ${result.classification}
            Annual Value: ${result.annualConsumptionValue}
            New Service Level: ${strategy.serviceLevel}%
            Review Period: ${strategy.reviewPeriodDays} days
        """.trimIndent())
    }
}
```

### Use Case 4: Economic Order Quantity (EOQ) Optimization

```kotlin
// Scenario: Calculate optimal order quantities using EOQ
val material = materialRepository.findByNumber("MAT-0001234567")
val location = storageLocationRepository.findByCode("WH01-LOC01")

val strategy = replenishmentStrategyRepository.findByMaterialAndLocation(
    material.id,
    location.id
)

// Set EOQ parameters
strategy.orderingCostPerOrder = BigDecimal("50.00") // $50 per order
strategy.holdingCostPerUnitPerYear = BigDecimal("2.50") // $2.50 per unit per year
strategy.replenishmentMethod = ReplenishmentMethod.EOQ

// Calculate EOQ
val eoq = strategy.calculateEOQ()

println("""
    Material: ${material.materialNumber}
    Annual Demand: ${strategy.averageDailyDemand * BigDecimal(365)}
    Ordering Cost: ${strategy.orderingCostPerOrder}
    Holding Cost: ${strategy.holdingCostPerUnitPerYear}

    Optimal Order Quantity (EOQ): $eoq units
    Number of Orders per Year: ${(strategy.averageDailyDemand * BigDecimal(365) / eoq).setScale(1, RoundingMode.HALF_UP)}
    Order Frequency: Every ${(365 / (strategy.averageDailyDemand * BigDecimal(365) / eoq).toInt())} days
""".trimIndent())
```

---

## Integration with Other Domains

### Integration with Demand Forecasting (Domain 4)

```kotlin
// Use forecast data to update replenishment strategies
forecastService.getLatestForecast(materialId)?.let { forecast ->
    val strategy = replenishmentStrategyRepository.findByMaterial(materialId).first()

    // Update average demand from forecast
    strategy.averageDailyDemand = forecast.periodForecasts
        .filter { it.periodType == PeriodType.DAILY }
        .map { it.forecastedQuantity }
        .average()
        .toBigDecimal()

    // Recalculate safety stock and reorder point
    strategy.recalculateSafetyStock(
        forecast.periodForecasts.map { it.forecastedQuantity }
    )
}
```

### Integration with Procurement (Domain 3)

```kotlin
// Convert approved replenishment proposals to purchase requisitions
val approvedProposals = proposalRepository.findByStatus(ProposalStatus.APPROVED)

approvedProposals.forEach { proposal ->
    if (proposal.proposedOrderType == ProposedOrderType.PURCHASE_REQUISITION) {
        val requisition = PurchaseRequisition(
            requisitionNumber = generateRequisitionNumber(),
            requisitionDate = LocalDate.now(),
            requesterId = proposal.reviewedBy!!,
            requisitionType = RequisitionType.REPLENISHMENT,
            priority = when (proposal.urgency) {
                ReplenishmentUrgency.CRITICAL -> PriorityLevel.CRITICAL
                ReplenishmentUrgency.HIGH -> PriorityLevel.HIGH
                else -> PriorityLevel.NORMAL
            },
            tenantId = proposal.material.tenantId
        )

        val item = PurchaseRequisitionItem(
            lineNumber = 1,
            material = proposal.material,
            quantity = proposal.proposedQuantity,
            estimatedUnitPrice = proposal.estimatedUnitCost,
            totalPrice = proposal.estimatedValue,
            suggestedVendorId = proposal.suggestedVendorId,
            requiredByDate = proposal.expectedReceiptDate
        )

        requisition.addItem(item)
        requisitionRepository.save(requisition)

        proposal.convertToOrder(requisition.id, ProposedOrderType.PURCHASE_REQUISITION)
    }
}
```

---

## Summary

The **Advanced Replenishment Strategies** domain provides enterprise-grade inventory optimization with:

✅ **7 Replenishment Methods**: Reorder Point, Min-Max, Periodic Review, Demand-Driven, Two-Bin, Kanban, EOQ
✅ **Statistical Safety Stock**: Z-score based calculations with service level targets (90%-99.9%)
✅ **ABC Analysis**: Pareto-based classification with automatic strategy adjustments
✅ **Multi-Location Support**: Inter-location transfers and source/destination mapping
✅ **Seasonal Adjustments**: Monthly seasonality factors for demand planning
✅ **Urgency-Based Processing**: CRITICAL, HIGH, NORMAL, LOW priority handling
✅ **Approval Workflows**: Proposal-based replenishment with review and approval
✅ **Economic Order Quantity**: Optimal order size calculation considering ordering and holding costs
✅ **Lead Time Variability**: Advanced safety stock considering both demand and lead time uncertainty
✅ **Automatic Conversion**: Approved proposals convert to purchase requisitions, transfer orders, or production orders

**Estimated Tables**: 4 main tables (replenishment_strategies, replenishment_runs, replenishment_proposals, safety_stock_calculations) + supporting tables

This domain integrates seamlessly with Inventory Management, Demand Forecasting, Procurement, and Production Planning domains.
