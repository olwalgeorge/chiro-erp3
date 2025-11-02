# Domain Models - Product Costing & Cost Analysis (SAP CO-PC Pattern)

## Schema: `costing_schema`

This service implements **SAP CO-PC (Controlling - Product Costing)** patterns following world-class ERP standards for comprehensive cost management, variance analysis, and profitability tracking.

---

## Overview

Product Costing provides:

-   **Standard Cost Estimation** - Calculate standard costs for materials
-   **Material Ledger** - Actual costing with multiple valuation approaches
-   **Cost Component Split** - Detailed breakdown of product costs
-   **Variance Analysis** - Price, quantity, and efficiency variances
-   **Product Cost Planning** - Future cost estimation and simulation
-   **Cost of Goods Manufactured (COGM)** tracking
-   **Profitability Analysis** integration

---

## Domain 1: Cost Estimation & Standard Costing

### Overview

Calculate and maintain standard costs for materials following SAP CO-PC principles with detailed cost component breakdowns.

### Aggregates

**CostEstimate (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "cost_estimates",
    schema = "costing_schema",
    indexes = [
        Index(name = "idx_cost_estimate_material", columnList = "materialId"),
        Index(name = "idx_cost_estimate_version", columnList = "costingVersion"),
        Index(name = "idx_cost_estimate_date", columnList = "validFrom")
    ]
)
class CostEstimate(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val estimateNumber: String, // CE-YYYY-NNNNNN

    @Column(nullable = false)
    val materialId: UUID,

    @Column(nullable = false)
    val materialNumber: String,

    @Column(nullable = false)
    val plantId: UUID,

    // Costing version (allows multiple cost estimates)
    @Column(nullable = false)
    val costingVersion: String, // "STANDARD", "PLANNED", "FUTURE"

    // Quantity for costing (costing lot size)
    @Column(nullable = false, precision = 19, scale = 4)
    val costingLotSize: BigDecimal,

    @Column(nullable = false)
    val unitOfMeasure: String,

    // Validity period
    @Column(nullable = false)
    val validFrom: LocalDate,

    val validTo: LocalDate? = null,

    // Total cost
    @Column(nullable = false, precision = 19, scale = 4)
    var totalCost: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false, precision = 19, scale = 4)
    var unitCost: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false)
    val currency: String = "USD",

    // Cost component split
    @OneToMany(mappedBy = "costEstimate", cascade = [CascadeType.ALL])
    val costComponents: MutableList<CostComponent> = mutableListOf(),

    // Itemization (detailed breakdown)
    @OneToMany(mappedBy = "costEstimate", cascade = [CascadeType.ALL])
    val itemization: MutableList<CostEstimateItem> = mutableListOf(),

    // BOM reference
    val bomId: UUID? = null,
    val bomVersion: String? = null,

    // Routing reference
    val routingId: UUID? = null,
    val routingVersion: String? = null,

    // Costing sheet (overhead calculation template)
    val costingSheetId: UUID? = null,

    // Status
    @Enumerated(EnumType.STRING)
    var status: CostEstimateStatus = CostEstimateStatus.DRAFT,

    var releasedAt: Instant? = null,
    val releasedBy: UUID? = null,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @Column(nullable = false)
    val createdBy: UUID,

    @Version
    var version: Long = 0
) {
    companion object {
        fun generateEstimateNumber(year: Int, sequence: Long): String {
            return "CE-$year-${sequence.toString().padStart(6, '0')}"
        }
    }

    fun addCostComponent(
        componentType: CostComponentType,
        amount: BigDecimal,
        isFixed: Boolean = false
    ) {
        val component = CostComponent(
            costEstimate = this,
            componentType = componentType,
            totalAmount = amount,
            unitAmount = if (costingLotSize > BigDecimal.ZERO) amount / costingLotSize else BigDecimal.ZERO,
            currency = currency,
            isFixed = isFixed
        )
        costComponents.add(component)
        recalculateTotalCost()
    }

    fun addEstimateItem(
        itemType: CostEstimateItemType,
        resourceId: UUID?,
        description: String,
        quantity: BigDecimal,
        unitPrice: BigDecimal,
        componentType: CostComponentType
    ) {
        val item = CostEstimateItem(
            costEstimate = this,
            lineNumber = itemization.size + 1,
            itemType = itemType,
            resourceId = resourceId,
            description = description,
            quantity = quantity,
            unitOfMeasure = unitOfMeasure,
            unitPrice = unitPrice,
            totalPrice = quantity * unitPrice,
            currency = currency,
            componentType = componentType
        )
        itemization.add(item)
        recalculateTotalCost()
    }

    fun recalculateTotalCost() {
        totalCost = costComponents.sumOf { it.totalAmount }
        unitCost = if (costingLotSize > BigDecimal.ZERO) {
            totalCost / costingLotSize
        } else {
            BigDecimal.ZERO
        }
        updatedAt = Instant.now()
    }

    fun release() {
        require(status == CostEstimateStatus.DRAFT) {
            "Only draft estimates can be released"
        }
        require(costComponents.isNotEmpty()) {
            "Cannot release estimate without cost components"
        }

        status = CostEstimateStatus.RELEASED
        releasedAt = Instant.now()
        updatedAt = Instant.now()
    }

    fun markStandard() {
        require(status == CostEstimateStatus.RELEASED) {
            "Only released estimates can be marked as standard"
        }

        status = CostEstimateStatus.STANDARD
        updatedAt = Instant.now()
    }

    fun getCostComponentSplit(): Map<CostComponentType, BigDecimal> {
        return costComponents.groupBy { it.componentType }
            .mapValues { (_, components) -> components.sumOf { it.totalAmount } }
    }

    fun getMaterialCost(): BigDecimal {
        return costComponents
            .filter { it.componentType == CostComponentType.RAW_MATERIAL }
            .sumOf { it.totalAmount }
    }

    fun getLaborCost(): BigDecimal {
        return costComponents
            .filter { it.componentType == CostComponentType.DIRECT_LABOR }
            .sumOf { it.totalAmount }
    }

    fun getOverheadCost(): BigDecimal {
        return costComponents
            .filter {
                it.componentType in listOf(
                    CostComponentType.MANUFACTURING_OVERHEAD,
                    CostComponentType.MATERIAL_OVERHEAD,
                    CostComponentType.GENERAL_OVERHEAD
                )
            }
            .sumOf { it.totalAmount }
    }
}

enum class CostEstimateStatus {
    DRAFT,          // Being created/edited
    RELEASED,       // Released for use
    STANDARD,       // Marked as standard cost
    ARCHIVED        // Historical/archived
}

enum class CostEstimateItemType {
    MATERIAL,       // Raw material
    OPERATION,      // Production operation
    OVERHEAD,       // Overhead allocation
    EXTERNAL,       // External processing
    MISCELLANEOUS   // Other costs
}
```

**CostComponent (Entity)**

```kotlin
@Entity
@Table(
    name = "cost_components",
    schema = "costing_schema",
    indexes = [
        Index(name = "idx_cost_comp_estimate", columnList = "costEstimateId"),
        Index(name = "idx_cost_comp_type", columnList = "componentType")
    ]
)
class CostComponent(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "cost_estimate_id", nullable = false)
    var costEstimate: CostEstimate,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    val componentType: CostComponentType,

    @Column(nullable = false, precision = 19, scale = 4)
    val totalAmount: BigDecimal,

    @Column(nullable = false, precision = 19, scale = 4)
    val unitAmount: BigDecimal,

    @Column(nullable = false)
    val currency: String = "USD",

    // Fixed vs. Variable
    @Column(nullable = false)
    val isFixed: Boolean = false,

    // For variance analysis
    @Column(precision = 19, scale = 4)
    val fixedPortion: BigDecimal? = null,

    @Column(precision = 19, scale = 4)
    val variablePortion: BigDecimal? = null,

    // Cost element (for accounting)
    val costElementId: UUID? = null,

    @Column(length = 1000)
    var description: String? = null,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now()
)

enum class CostComponentType {
    // Material costs
    RAW_MATERIAL,
    SEMI_FINISHED,
    PURCHASED_PARTS,
    MATERIAL_OVERHEAD,

    // Labor costs
    DIRECT_LABOR,
    INDIRECT_LABOR,

    // Manufacturing costs
    MACHINE_COST,
    SETUP_COST,
    MANUFACTURING_OVERHEAD,

    // External costs
    EXTERNAL_PROCESSING,
    FREIGHT,
    CUSTOMS_DUTY,

    // Overhead costs
    GENERAL_OVERHEAD,
    ADMIN_OVERHEAD,

    // Other
    SCRAP,
    REWORK,
    QUALITY,
    MISCELLANEOUS
}
```

**CostEstimateItem (Entity)**

```kotlin
@Entity
@Table(
    name = "cost_estimate_items",
    schema = "costing_schema",
    indexes = [
        Index(name = "idx_cost_item_estimate", columnList = "costEstimateId")
    ]
)
class CostEstimateItem(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "cost_estimate_id", nullable = false)
    var costEstimate: CostEstimate,

    @Column(nullable = false)
    val lineNumber: Int,

    @Enumerated(EnumType.STRING)
    val itemType: CostEstimateItemType,

    // Resource reference (Material, Work Center, etc.)
    val resourceId: UUID?,

    @Column(nullable = false)
    val description: String,

    @Column(nullable = false, precision = 19, scale = 4)
    val quantity: BigDecimal,

    @Column(nullable = false)
    val unitOfMeasure: String,

    @Column(nullable = false, precision = 19, scale = 4)
    val unitPrice: BigDecimal,

    @Column(nullable = false, precision = 19, scale = 4)
    val totalPrice: BigDecimal,

    @Column(nullable = false)
    val currency: String = "USD",

    // Cost component mapping
    @Enumerated(EnumType.STRING)
    val componentType: CostComponentType,

    // Scrap/waste
    @Column(precision = 5, scale = 2)
    val scrapPercent: BigDecimal? = null,

    @Column(precision = 19, scale = 4)
    val scrapCost: BigDecimal? = null,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now()
)
```

**CostingVersion (Configuration)**

```kotlin
@Entity
@Table(
    name = "costing_versions",
    schema = "costing_schema",
    indexes = [
        Index(name = "idx_costing_ver_code", columnList = "versionCode")
    ]
)
class CostingVersion(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val versionCode: String, // "STD", "PLN1", "FUT1"

    @Column(nullable = false)
    var name: String,

    @Lob
    var description: String? = null,

    @Enumerated(EnumType.STRING)
    val versionType: CostingVersionType,

    // Validity
    @Column(nullable = false)
    val validFrom: LocalDate,

    val validTo: LocalDate? = null,

    // Controls
    val allowNewEstimates: Boolean = true,
    val allowChanges: Boolean = true,
    val lockedForReleases: Boolean = false,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now()
)

enum class CostingVersionType {
    STANDARD,       // Current standard costs
    PLANNED,        // Planned costs for next period
    FUTURE,         // Future planning scenarios
    SIMULATION      // What-if scenarios
}
```

---

## Domain 2: Material Ledger & Actual Costing

### Overview

Track actual costs with Material Ledger following SAP principles, supporting multiple valuation approaches and period-end closing.

### Aggregates

**MaterialLedgerEntry (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "material_ledger_entries",
    schema = "costing_schema",
    indexes = [
        Index(name = "idx_ml_material", columnList = "materialId"),
        Index(name = "idx_ml_period", columnList = "fiscalYear, fiscalPeriod"),
        Index(name = "idx_ml_document", columnList = "sourceDocumentType, sourceDocumentNumber")
    ]
)
class MaterialLedgerEntry(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val entryNumber: String, // MLE-YYYY-NNNNNN

    // Material reference
    @Column(nullable = false)
    val materialId: UUID,

    @Column(nullable = false)
    val materialNumber: String,

    @Column(nullable = false)
    val plantId: UUID,

    val valuationAreaId: UUID? = null,

    // Fiscal period
    @Column(nullable = false)
    val fiscalYear: Int,

    @Column(nullable = false)
    val fiscalPeriod: Int,

    @Column(nullable = false)
    val postingDate: LocalDate,

    @Column(nullable = false)
    val documentDate: LocalDate,

    // Transaction details
    @Enumerated(EnumType.STRING)
    val transactionType: MaterialLedgerTransactionType,

    @Enumerated(EnumType.STRING)
    val movementType: String, // "GR", "GI", "TRANSFER", etc.

    val sourceDocumentType: String,
    val sourceDocumentNumber: String,

    // Quantity
    @Column(nullable = false, precision = 19, scale = 4)
    val quantity: BigDecimal,

    @Column(nullable = false)
    val unitOfMeasure: String,

    @Enumerated(EnumType.STRING)
    val quantityMovement: QuantityMovement, // INCREASE or DECREASE

    // Valuation (multiple currencies/valuation approaches)
    @OneToMany(mappedBy = "ledgerEntry", cascade = [CascadeType.ALL])
    val valuations: MutableList<MaterialLedgerValuation> = mutableListOf(),

    // Standard price at time of posting
    @Column(precision = 19, scale = 4)
    val standardPrice: BigDecimal? = null,

    // Cost component split
    @Column(columnDefinition = "jsonb")
    val costComponentSplit: String? = null,

    // Actual vs. Standard variance
    @Column(precision = 19, scale = 2)
    val priceVariance: BigDecimal? = null,

    // Period closing flags
    var periodClosed: Boolean = false,
    var actualCostCalculated: Boolean = false,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    val createdBy: UUID,

    @Version
    var version: Long = 0
) {
    companion object {
        fun generateEntryNumber(year: Int, sequence: Long): String {
            return "MLE-$year-${sequence.toString().padStart(6, '0')}"
        }
    }

    fun addValuation(
        valuationType: ValuationType,
        currency: String,
        totalValue: BigDecimal,
        unitPrice: BigDecimal
    ) {
        val valuation = MaterialLedgerValuation(
            ledgerEntry = this,
            valuationType = valuationType,
            currency = currency,
            totalValue = totalValue,
            unitPrice = unitPrice
        )
        valuations.add(valuation)
    }

    fun getValuation(type: ValuationType): MaterialLedgerValuation? {
        return valuations.firstOrNull { it.valuationType == type }
    }
}

enum class MaterialLedgerTransactionType {
    GOODS_RECEIPT,
    GOODS_ISSUE,
    TRANSFER_POSTING,
    PRODUCTION_RECEIPT,
    PRODUCTION_CONSUMPTION,
    INVOICE_RECEIPT,
    PHYSICAL_INVENTORY,
    REVALUATION,
    PRICE_CHANGE
}

enum class QuantityMovement {
    INCREASE, DECREASE
}
```

**MaterialLedgerValuation (Entity)**

```kotlin
@Entity
@Table(
    name = "material_ledger_valuations",
    schema = "costing_schema",
    indexes = [
        Index(name = "idx_ml_val_entry", columnList = "ledgerEntryId"),
        Index(name = "idx_ml_val_type", columnList = "valuationType")
    ]
)
class MaterialLedgerValuation(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "ledger_entry_id", nullable = false)
    var ledgerEntry: MaterialLedgerEntry,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    val valuationType: ValuationType,

    @Column(nullable = false)
    val currency: String,

    @Column(nullable = false, precision = 19, scale = 2)
    val totalValue: BigDecimal,

    @Column(nullable = false, precision = 19, scale = 4)
    val unitPrice: BigDecimal,

    // Exchange rate (if multiple currencies)
    @Column(precision = 19, scale = 6)
    val exchangeRate: BigDecimal? = null,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now()
)

enum class ValuationType {
    LEGAL_VALUATION,        // Legal/tax valuation
    GROUP_VALUATION,        // Group/consolidated valuation
    PROFIT_CENTER_VALUATION,// Profit center valuation
    STANDARD_PRICE,         // Standard price
    MOVING_AVERAGE,         // Moving average price
    ACTUAL_COST             // Actual cost after period close
}
```

**MaterialPrice (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "material_prices",
    schema = "costing_schema",
    indexes = [
        Index(name = "idx_mat_price_material", columnList = "materialId"),
        Index(name = "idx_mat_price_date", columnList = "validFrom")
    ],
    uniqueConstraints = [
        UniqueConstraint(
            name = "uk_material_price",
            columnNames = ["materialId", "plantId", "priceType", "validFrom"]
        )
    ]
)
class MaterialPrice(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false)
    val materialId: UUID,

    @Column(nullable = false)
    val plantId: UUID,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    val priceType: MaterialPriceType,

    @Column(nullable = false, precision = 19, scale = 4)
    var price: BigDecimal,

    @Column(nullable = false)
    val currency: String = "USD",

    val priceUnit: Int = 1, // Price per X units

    // Validity period
    @Column(nullable = false)
    val validFrom: LocalDate,

    val validTo: LocalDate? = null,

    // Cost component split
    @OneToMany(mappedBy = "materialPrice", cascade = [CascadeType.ALL])
    val costComponentSplit: MutableList<MaterialPriceCostComponent> = mutableListOf(),

    // Control flags
    val isPriceControlManual: Boolean = false,
    val isPriceFixed: Boolean = false,

    // Audit
    @Column(nullable = false)
    val createdBy: UUID,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
) {
    fun updatePrice(newPrice: BigDecimal, updatedBy: UUID) {
        require(newPrice > BigDecimal.ZERO) { "Price must be positive" }
        require(!isPriceFixed) { "Cannot update fixed price" }

        this.price = newPrice
        this.updatedAt = Instant.now()
    }

    fun addCostComponentSplit(componentType: CostComponentType, amount: BigDecimal) {
        val component = MaterialPriceCostComponent(
            materialPrice = this,
            componentType = componentType,
            amount = amount,
            currency = currency
        )
        costComponentSplit.add(component)
    }
}

enum class MaterialPriceType {
    STANDARD_PRICE,         // Standard cost
    MOVING_AVERAGE_PRICE,   // Moving average
    PLANNED_PRICE_1,        // Future planned price 1
    PLANNED_PRICE_2,        // Future planned price 2
    TAX_PRICE,             // Tax-based price
    COMMERCIAL_PRICE       // Commercial price
}
```

**MaterialPriceCostComponent (Entity)**

```kotlin
@Entity
@Table(
    name = "material_price_cost_components",
    schema = "costing_schema"
)
class MaterialPriceCostComponent(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "material_price_id", nullable = false)
    var materialPrice: MaterialPrice,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    val componentType: CostComponentType,

    @Column(nullable = false, precision = 19, scale = 4)
    val amount: BigDecimal,

    @Column(nullable = false)
    val currency: String,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now()
)
```

**PeriodCloseRun (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "period_close_runs",
    schema = "costing_schema",
    indexes = [
        Index(name = "idx_period_close_period", columnList = "fiscalYear, fiscalPeriod")
    ]
)
class PeriodCloseRun(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val runNumber: String, // PCR-YYYY-MM-NNNN

    @Column(nullable = false)
    val fiscalYear: Int,

    @Column(nullable = false)
    val fiscalPeriod: Int,

    @Column(nullable = false)
    val plantId: UUID,

    // Run details
    @Column(nullable = false)
    val startedAt: Instant,

    var completedAt: Instant? = null,

    @Enumerated(EnumType.STRING)
    var status: PeriodCloseStatus = PeriodCloseStatus.RUNNING,

    // Steps completed
    var actualCostCalculated: Boolean = false,
    var variancesCalculated: Boolean = false,
    var wipCalculated: Boolean = false,
    var settlementPosted: Boolean = false,

    // Statistics
    var materialsProcessed: Int = 0,
    var entriesProcessed: Int = 0,
    var variancesDetected: Int = 0,

    @Column(precision = 19, scale = 2)
    var totalVarianceAmount: BigDecimal = BigDecimal.ZERO,

    // Log
    @Column(columnDefinition = "text")
    var logMessages: String? = null,

    @Column(columnDefinition = "text")
    var errorMessages: String? = null,

    @Column(nullable = false)
    val runBy: UUID,

    @Column(nullable = false)
    val tenantId: UUID,

    @Version
    var version: Long = 0
) {
    companion object {
        fun generateRunNumber(year: Int, period: Int, sequence: Int): String {
            return "PCR-$year-${period.toString().padStart(2, '0')}-${sequence.toString().padStart(4, '0')}"
        }
    }

    fun complete() {
        this.status = PeriodCloseStatus.COMPLETED
        this.completedAt = Instant.now()
    }

    fun fail(errorMessage: String) {
        this.status = PeriodCloseStatus.FAILED
        this.errorMessages = errorMessage
        this.completedAt = Instant.now()
    }
}

enum class PeriodCloseStatus {
    RUNNING, COMPLETED, FAILED, CANCELLED
}
```

---

## Domain 3: Variance Analysis

### Overview

Comprehensive variance tracking and analysis comparing standard costs vs. actual costs.

### Aggregates

**CostVariance (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "cost_variances",
    schema = "costing_schema",
    indexes = [
        Index(name = "idx_variance_material", columnList = "materialId"),
        Index(name = "idx_variance_period", columnList = "fiscalYear, fiscalPeriod"),
        Index(name = "idx_variance_type", columnList = "varianceType")
    ]
)
class CostVariance(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val varianceNumber: String, // VAR-YYYY-MM-NNNNNN

    // Material and location
    @Column(nullable = false)
    val materialId: UUID,

    @Column(nullable = false)
    val materialNumber: String,

    @Column(nullable = false)
    val plantId: UUID,

    // Period
    @Column(nullable = false)
    val fiscalYear: Int,

    @Column(nullable = false)
    val fiscalPeriod: Int,

    @Column(nullable = false)
    val postingDate: LocalDate,

    // Variance type
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    val varianceType: VarianceType,

    @Enumerated(EnumType.STRING)
    val varianceCategory: VarianceCategory,

    // Source transaction
    val sourceDocumentType: String,
    val sourceDocumentNumber: String,
    val sourceLineItem: Int? = null,

    // Quantities
    @Column(nullable = false, precision = 19, scale = 4)
    val standardQuantity: BigDecimal,

    @Column(precision = 19, scale = 4)
    val actualQuantity: BigDecimal? = null,

    @Column(precision = 19, scale = 4)
    val quantityVariance: BigDecimal? = null,

    // Prices
    @Column(nullable = false, precision = 19, scale = 4)
    val standardPrice: BigDecimal,

    @Column(precision = 19, scale = 4)
    val actualPrice: BigDecimal? = null,

    @Column(precision = 19, scale = 4)
    val priceVariance: BigDecimal? = null,

    // Total variance
    @Column(nullable = false, precision = 19, scale = 2)
    val totalVarianceAmount: BigDecimal,

    @Column(nullable = false)
    val currency: String = "USD",

    // Is favorable or unfavorable
    @Enumerated(EnumType.STRING)
    val varianceImpact: VarianceImpact,

    // Cost component affected
    @Enumerated(EnumType.STRING)
    val costComponent: CostComponentType,

    // Analysis
    @Lob
    var analysisNotes: String? = null,

    @Lob
    var correctionActions: String? = null,

    // Settlement
    var settled: Boolean = false,
    var settlementDocumentId: UUID? = null,
    var settledAt: Instant? = null,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
) {
    companion object {
        fun generateVarianceNumber(year: Int, period: Int, sequence: Long): String {
            return "VAR-$year-${period.toString().padStart(2, '0')}-${sequence.toString().padStart(6, '0')}"
        }

        fun calculateVarianceImpact(standardAmount: BigDecimal, actualAmount: BigDecimal): VarianceImpact {
            return if (actualAmount < standardAmount) {
                VarianceImpact.FAVORABLE
            } else {
                VarianceImpact.UNFAVORABLE
            }
        }
    }

    fun settle(settlementDocumentId: UUID) {
        require(!settled) { "Variance already settled" }

        this.settled = true
        this.settlementDocumentId = settlementDocumentId
        this.settledAt = Instant.now()
        this.updatedAt = Instant.now()
    }

    fun addAnalysisNotes(notes: String) {
        this.analysisNotes = if (this.analysisNotes.isNullOrBlank()) {
            notes
        } else {
            "${this.analysisNotes}\n\n[${Instant.now()}]\n$notes"
        }
        this.updatedAt = Instant.now()
    }
}

enum class VarianceType {
    PRICE_VARIANCE,         // Price difference (standard vs. actual)
    QUANTITY_VARIANCE,      // Quantity/usage difference
    EFFICIENCY_VARIANCE,    // Efficiency/productivity variance
    RATE_VARIANCE,          // Labor/overhead rate variance
    VOLUME_VARIANCE,        // Production volume variance
    MIX_VARIANCE,           // Material mix variance
    YIELD_VARIANCE,         // Production yield variance
    OVERHEAD_VARIANCE,      // Overhead absorption variance
    EXCHANGE_RATE_VARIANCE  // Currency exchange variance
}

enum class VarianceCategory {
    MATERIAL,       // Material-related
    LABOR,          // Labor-related
    OVERHEAD,       // Overhead-related
    PRODUCTION,     // Production process
    PROCUREMENT,    // Procurement/purchasing
    OTHER           // Other categories
}

enum class VarianceImpact {
    FAVORABLE,      // Actual cost less than standard (good)
    UNFAVORABLE     // Actual cost more than standard (bad)
}
```

**VarianceAnalysisReport (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "variance_analysis_reports",
    schema = "costing_schema",
    indexes = [
        Index(name = "idx_var_report_period", columnList = "fiscalYear, fiscalPeriod")
    ]
)
class VarianceAnalysisReport(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val reportNumber: String, // VAR-RPT-YYYY-MM-NNNN

    @Column(nullable = false)
    val reportName: String,

    @Column(nullable = false)
    val fiscalYear: Int,

    @Column(nullable = false)
    val fiscalPeriod: Int,

    val plantId: UUID? = null, // Null for all plants

    // Generation details
    @Column(nullable = false)
    val generatedAt: Instant,

    @Column(nullable = false)
    val generatedBy: UUID,

    // Summary statistics
    var totalVarianceCount: Int = 0,

    @Column(precision = 19, scale = 2)
    var totalVarianceAmount: BigDecimal = BigDecimal.ZERO,

    @Column(precision = 19, scale = 2)
    var favorableVarianceAmount: BigDecimal = BigDecimal.ZERO,

    @Column(precision = 19, scale = 2)
    var unfavorableVarianceAmount: BigDecimal = BigDecimal.ZERO,

    @Column(precision = 19, scale = 2)
    var materialVarianceAmount: BigDecimal = BigDecimal.ZERO,

    @Column(precision = 19, scale = 2)
    var laborVarianceAmount: BigDecimal = BigDecimal.ZERO,

    @Column(precision = 19, scale = 2)
    var overheadVarianceAmount: BigDecimal = BigDecimal.ZERO,

    // Breakdown by type
    @Column(columnDefinition = "jsonb")
    var varianceBreakdownByType: String? = null,

    // Top variances
    @Column(columnDefinition = "jsonb")
    var topUnfavorableVariances: String? = null,

    @Column(columnDefinition = "jsonb")
    var topFavorableVariances: String? = null,

    // Report file
    val reportFileUrl: String? = null,

    @Column(nullable = false)
    val currency: String = "USD",

    @Column(nullable = false)
    val tenantId: UUID,

    @Version
    var version: Long = 0
) {
    companion object {
        fun generateReportNumber(year: Int, period: Int, sequence: Int): String {
            return "VAR-RPT-$year-${period.toString().padStart(2, '0')}-${sequence.toString().padStart(4, '0')}"
        }
    }
}
```

---

## Domain 4: Product Cost Planning

### Overview

Future cost planning, simulation, and "what-if" analysis for strategic decision making.

### Aggregates

**CostPlanningScenario (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "cost_planning_scenarios",
    schema = "costing_schema",
    indexes = [
        Index(name = "idx_scenario_code", columnList = "scenarioCode")
    ]
)
class CostPlanningScenario(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val scenarioCode: String, // SCENARIO-YYYY-NNNN

    @Column(nullable = false)
    var scenarioName: String,

    @Lob
    var description: String? = null,

    @Enumerated(EnumType.STRING)
    val scenarioType: ScenarioType,

    // Planning period
    @Column(nullable = false)
    val planningYear: Int,

    val planningQuarter: Int? = null,

    // Base scenario (for comparison)
    val baseScenarioId: UUID? = null,

    // Assumptions (stored as JSON for flexibility)
    @Column(columnDefinition = "jsonb")
    var assumptions: String? = null,

    // Example assumptions:
    // - Material price changes (%)
    // - Labor rate changes (%)
    // - Overhead rate changes
    // - Production volume changes
    // - Exchange rates

    // Planning parameters
    @Column(precision = 5, scale = 2)
    var materialPriceInflation: BigDecimal? = null,

    @Column(precision = 5, scale = 2)
    var laborRateIncrease: BigDecimal? = null,

    @Column(precision = 5, scale = 2)
    var overheadRateChange: BigDecimal? = null,

    @Column(precision = 5, scale = 2)
    var productionVolumeChange: BigDecimal? = null,

    // Planned costs
    @OneToMany(mappedBy = "scenario", cascade = [CascadeType.ALL])
    val plannedCosts: MutableList<PlannedMaterialCost> = mutableListOf(),

    // Status
    @Enumerated(EnumType.STRING)
    var status: ScenarioStatus = ScenarioStatus.DRAFT,

    @Column(nullable = false)
    val createdBy: UUID,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
) {
    companion object {
        fun generateScenarioCode(year: Int, sequence: Long): String {
            return "SCENARIO-$year-${sequence.toString().padStart(4, '0')}"
        }
    }

    fun activate() {
        this.status = ScenarioStatus.ACTIVE
        this.updatedAt = Instant.now()
    }

    fun archive() {
        this.status = ScenarioStatus.ARCHIVED
        this.updatedAt = Instant.now()
    }

    fun addPlannedCost(plannedCost: PlannedMaterialCost) {
        plannedCosts.add(plannedCost)
        plannedCost.scenario = this
        updatedAt = Instant.now()
    }
}

enum class ScenarioType {
    BASELINE,           // Baseline/current state
    BUDGET,             // Budget planning
    FORECAST,           // Forecast scenario
    WHAT_IF,            // What-if analysis
    OPTIMIZATION,       // Cost optimization
    STRATEGIC           // Strategic planning
}

enum class ScenarioStatus {
    DRAFT, ACTIVE, APPROVED, ARCHIVED
}
```

**PlannedMaterialCost (Entity)**

```kotlin
@Entity
@Table(
    name = "planned_material_costs",
    schema = "costing_schema",
    indexes = [
        Index(name = "idx_planned_cost_scenario", columnList = "scenarioId"),
        Index(name = "idx_planned_cost_material", columnList = "materialId")
    ]
)
class PlannedMaterialCost(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "scenario_id", nullable = false)
    var scenario: CostPlanningScenario,

    @Column(nullable = false)
    val materialId: UUID,

    @Column(nullable = false)
    val materialNumber: String,

    @Column(nullable = false)
    val plantId: UUID,

    // Current cost (baseline)
    @Column(precision = 19, scale = 4)
    val currentUnitCost: BigDecimal,

    // Planned cost
    @Column(precision = 19, scale = 4)
    var plannedUnitCost: BigDecimal,

    @Column(precision = 19, scale = 2)
    var costChange: BigDecimal,

    @Column(precision = 5, scale = 2)
    var costChangePercent: BigDecimal,

    @Column(nullable = false)
    val currency: String = "USD",

    // Cost component breakdown
    @Column(columnDefinition = "jsonb")
    var costComponentBreakdown: String? = null,

    // Planning notes
    @Lob
    var planningNotes: String? = null,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now()
) {
    fun updatePlannedCost(newPlannedCost: BigDecimal) {
        this.plannedUnitCost = newPlannedCost
        this.costChange = newPlannedCost - currentUnitCost
        this.costChangePercent = if (currentUnitCost > BigDecimal.ZERO) {
            (costChange / currentUnitCost) * BigDecimal(100)
        } else {
            BigDecimal.ZERO
        }
        this.updatedAt = Instant.now()
    }
}
```

---

## Domain 5: Work-in-Process (WIP) Costing

### Overview

Track costs of partially completed production orders (work-in-process).

### Aggregates

**WIPPosition (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "wip_positions",
    schema = "costing_schema",
    indexes = [
        Index(name = "idx_wip_order", columnList = "productionOrderId"),
        Index(name = "idx_wip_period", columnList = "fiscalYear, fiscalPeriod")
    ]
)
class WIPPosition(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val positionNumber: String, // WIP-YYYY-MM-NNNNNN

    // Production order reference
    @Column(nullable = false)
    val productionOrderId: UUID,

    @Column(nullable = false)
    val productionOrderNumber: String,

    @Column(nullable = false)
    val materialId: UUID,

    @Column(nullable = false)
    val plantId: UUID,

    // Period
    @Column(nullable = false)
    val fiscalYear: Int,

    @Column(nullable = false)
    val fiscalPeriod: Int,

    @Column(nullable = false)
    val valuationDate: LocalDate,

    // Production quantity
    @Column(precision = 19, scale = 4)
    val targetQuantity: BigDecimal,

    @Column(precision = 19, scale = 4)
    val confirmedQuantity: BigDecimal,

    @Column(precision = 19, scale = 4)
    val deliveredQuantity: BigDecimal,

    @Column(precision = 19, scale = 4)
    val wipQuantity: BigDecimal, // Still in process

    @Column(nullable = false)
    val unitOfMeasure: String,

    // WIP value (cost accumulated)
    @Column(nullable = false, precision = 19, scale = 2)
    var wipValue: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false)
    val currency: String = "USD",

    // Cost accumulation
    @OneToMany(mappedBy = "wipPosition", cascade = [CascadeType.ALL])
    val costAccumulation: MutableList<WIPCostAccumulation> = mutableListOf(),

    // Settlement
    var settled: Boolean = false,
    var settlementDate: LocalDate? = null,
    var settlementDocumentId: UUID? = null,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
) {
    companion object {
        fun generatePositionNumber(year: Int, period: Int, sequence: Long): String {
            return "WIP-$year-${period.toString().padStart(2, '0')}-${sequence.toString().padStart(6, '0')}"
        }
    }

    fun addCostAccumulation(
        costComponent: CostComponentType,
        amount: BigDecimal
    ) {
        val accumulation = WIPCostAccumulation(
            wipPosition = this,
            costComponent = costComponent,
            accumulatedAmount = amount,
            currency = currency
        )
        costAccumulation.add(accumulation)
        recalculateWIPValue()
    }

    fun recalculateWIPValue() {
        wipValue = costAccumulation.sumOf { it.accumulatedAmount }
        updatedAt = Instant.now()
    }

    fun settle(settlementDocumentId: UUID) {
        require(!settled) { "WIP already settled" }

        this.settled = true
        this.settlementDate = LocalDate.now()
        this.settlementDocumentId = settlementDocumentId
        this.updatedAt = Instant.now()
    }
}
```

**WIPCostAccumulation (Entity)**

```kotlin
@Entity
@Table(
    name = "wip_cost_accumulation",
    schema = "costing_schema"
)
class WIPCostAccumulation(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "wip_position_id", nullable = false)
    var wipPosition: WIPPosition,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    val costComponent: CostComponentType,

    @Column(nullable = false, precision = 19, scale = 2)
    val accumulatedAmount: BigDecimal,

    @Column(nullable = false)
    val currency: String,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now()
)
```

---

## Domain 6: Cost Centers & Activity Types

### Overview

Cost center accounting and activity-based costing support.

### Aggregates

**CostCenter (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "cost_centers",
    schema = "costing_schema",
    indexes = [
        Index(name = "idx_cost_center_code", columnList = "costCenterCode")
    ]
)
class CostCenter(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val costCenterCode: String,

    @Column(nullable = false)
    var name: String,

    @Lob
    var description: String? = null,

    @Enumerated(EnumType.STRING)
    val costCenterCategory: CostCenterCategory,

    // Hierarchy
    val parentCostCenterId: UUID? = null,

    // Organizational assignment
    val plantId: UUID? = null,
    val departmentId: UUID? = null,

    // Responsible person
    val responsiblePersonId: UUID? = null,

    // Validity
    @Column(nullable = false)
    val validFrom: LocalDate,

    val validTo: LocalDate? = null,

    // Control
    val lockedForPosting: Boolean = false,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now()
)

enum class CostCenterCategory {
    PRODUCTION,         // Direct production
    MANUFACTURING,      // Manufacturing support
    QUALITY,           // Quality assurance
    MAINTENANCE,       // Maintenance
    LOGISTICS,         // Logistics/warehouse
    ADMINISTRATION,    // Administration
    SALES,            // Sales & distribution
    RESEARCH,         // R&D
    SERVICE           // Service
}
```

**ActivityType (Entity)**

```kotlin
@Entity
@Table(
    name = "activity_types",
    schema = "costing_schema",
    indexes = [
        Index(name = "idx_activity_type_code", columnList = "activityTypeCode")
    ]
)
class ActivityType(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val activityTypeCode: String,

    @Column(nullable = false)
    var name: String,

    @Lob
    var description: String? = null,

    // Unit of measure for activity
    @Column(nullable = false)
    val unitOfMeasure: String, // e.g., "HOUR", "SETUP", "RUN"

    // Activity rate (cost per unit)
    @Column(precision = 19, scale = 4)
    var standardRate: BigDecimal,

    @Column(nullable = false)
    val currency: String = "USD",

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now()
)
```

---

## Domain 7: Landed Cost Calculation

### Overview

Calculate total landed costs for purchased materials including all costs to get products to their destination (freight, insurance, customs duties, handling fees, etc.).

### Aggregates

**LandedCostDocument (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "landed_cost_documents",
    schema = "costing_schema",
    indexes = [
        Index(name = "idx_lc_doc_number", columnList = "documentNumber"),
        Index(name = "idx_lc_doc_po", columnList = "purchaseOrderId"),
        Index(name = "idx_lc_doc_shipment", columnList = "shipmentId")
    ]
)
class LandedCostDocument(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val documentNumber: String, // LC-YYYY-NNNNNN

    @Column(nullable = false)
    var documentDate: LocalDate,

    // Reference documents
    val purchaseOrderId: UUID? = null,
    val purchaseOrderNumber: String? = null,

    val shipmentId: UUID? = null,
    val shipmentNumber: String? = null,

    val goodsReceiptId: UUID? = null,
    val goodsReceiptNumber: String? = null,

    // Vendor information
    val vendorId: UUID,
    val vendorName: String,

    // Origin and destination
    @Embedded
    var originAddress: ShippingAddress,

    @Embedded
    var destinationAddress: ShippingAddress,

    // Incoterms
    @Enumerated(EnumType.STRING)
    val incoterms: Incoterms,

    // Materials/Items covered
    @OneToMany(mappedBy = "landedCostDocument", cascade = [CascadeType.ALL])
    val materials: MutableList<LandedCostMaterial> = mutableListOf(),

    // Cost components (freight, duty, insurance, etc.)
    @OneToMany(mappedBy = "landedCostDocument", cascade = [CascadeType.ALL])
    val costComponents: MutableList<LandedCostComponent> = mutableListOf(),

    // Totals
    @Column(precision = 19, scale = 2)
    var totalMaterialCost: BigDecimal = BigDecimal.ZERO,

    @Column(precision = 19, scale = 2)
    var totalLandedCost: BigDecimal = BigDecimal.ZERO,

    @Column(precision = 19, scale = 2)
    var totalAdditionalCosts: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false)
    val currency: String = "USD",

    // Allocation method
    @Enumerated(EnumType.STRING)
    var allocationMethod: CostAllocationMethod = CostAllocationMethod.BY_VALUE,

    // Status
    @Enumerated(EnumType.STRING)
    var status: LandedCostStatus = LandedCostStatus.DRAFT,

    var calculatedAt: Instant? = null,
    var postedAt: Instant? = null,

    @Column(nullable = false)
    val createdBy: UUID,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
) {
    companion object {
        fun generateDocumentNumber(year: Int, sequence: Long): String {
            return "LC-$year-${sequence.toString().padStart(6, '0')}"
        }
    }

    fun addMaterial(
        materialId: UUID,
        materialNumber: String,
        quantity: BigDecimal,
        unitPrice: BigDecimal,
        unitOfMeasure: String
    ): LandedCostMaterial {
        val material = LandedCostMaterial(
            landedCostDocument = this,
            lineNumber = materials.size + 1,
            materialId = materialId,
            materialNumber = materialNumber,
            quantity = quantity,
            unitOfMeasure = unitOfMeasure,
            unitPrice = unitPrice,
            totalPrice = quantity * unitPrice,
            currency = currency
        )
        materials.add(material)
        recalculateTotals()
        return material
    }

    fun addCostComponent(
        costType: LandedCostType,
        costDescription: String,
        amount: BigDecimal,
        vendorId: UUID? = null
    ): LandedCostComponent {
        val component = LandedCostComponent(
            landedCostDocument = this,
            costType = costType,
            costDescription = costDescription,
            totalAmount = amount,
            currency = currency,
            serviceProviderId = vendorId
        )
        costComponents.add(component)
        recalculateTotals()
        return component
    }

    fun calculateLandedCosts() {
        require(materials.isNotEmpty()) { "Cannot calculate without materials" }
        require(status == LandedCostStatus.DRAFT) { "Can only calculate draft documents" }

        // Allocate additional costs to materials
        when (allocationMethod) {
            CostAllocationMethod.BY_VALUE -> allocateByValue()
            CostAllocationMethod.BY_QUANTITY -> allocateByQuantity()
            CostAllocationMethod.BY_WEIGHT -> allocateByWeight()
            CostAllocationMethod.BY_VOLUME -> allocateByVolume()
            CostAllocationMethod.MANUAL -> {} // Manual allocation already done
        }

        calculatedAt = Instant.now()
        status = LandedCostStatus.CALCULATED
        updatedAt = Instant.now()
    }

    private fun allocateByValue() {
        val totalMaterialValue = materials.sumOf { it.totalPrice }

        costComponents.forEach { costComponent ->
            materials.forEach { material ->
                val allocationRatio = if (totalMaterialValue > BigDecimal.ZERO) {
                    material.totalPrice / totalMaterialValue
                } else {
                    BigDecimal.ZERO
                }

                val allocatedAmount = costComponent.totalAmount * allocationRatio
                material.addAllocatedCost(costComponent.costType, allocatedAmount)
            }
        }
    }

    private fun allocateByQuantity() {
        val totalQuantity = materials.sumOf { it.quantity }

        costComponents.forEach { costComponent ->
            materials.forEach { material ->
                val allocationRatio = if (totalQuantity > BigDecimal.ZERO) {
                    material.quantity / totalQuantity
                } else {
                    BigDecimal.ZERO
                }

                val allocatedAmount = costComponent.totalAmount * allocationRatio
                material.addAllocatedCost(costComponent.costType, allocatedAmount)
            }
        }
    }

    private fun allocateByWeight() {
        val totalWeight = materials.sumOf { it.weight ?: BigDecimal.ZERO }

        costComponents.forEach { costComponent ->
            materials.forEach { material ->
                val weight = material.weight ?: BigDecimal.ZERO
                val allocationRatio = if (totalWeight > BigDecimal.ZERO) {
                    weight / totalWeight
                } else {
                    BigDecimal.ZERO
                }

                val allocatedAmount = costComponent.totalAmount * allocationRatio
                material.addAllocatedCost(costComponent.costType, allocatedAmount)
            }
        }
    }

    private fun allocateByVolume() {
        val totalVolume = materials.sumOf { it.volume ?: BigDecimal.ZERO }

        costComponents.forEach { costComponent ->
            materials.forEach { material ->
                val volume = material.volume ?: BigDecimal.ZERO
                val allocationRatio = if (totalVolume > BigDecimal.ZERO) {
                    volume / totalVolume
                } else {
                    BigDecimal.ZERO
                }

                val allocatedAmount = costComponent.totalAmount * allocationRatio
                material.addAllocatedCost(costComponent.costType, allocatedAmount)
            }
        }
    }

    private fun recalculateTotals() {
        totalMaterialCost = materials.sumOf { it.totalPrice }
        totalAdditionalCosts = costComponents.sumOf { it.totalAmount }
        totalLandedCost = totalMaterialCost + totalAdditionalCosts
        updatedAt = Instant.now()
    }

    fun post() {
        require(status == LandedCostStatus.CALCULATED) {
            "Can only post calculated documents"
        }

        status = LandedCostStatus.POSTED
        postedAt = Instant.now()
        updatedAt = Instant.now()
    }

    fun getLandedCostPerUnit(materialId: UUID): BigDecimal? {
        val material = materials.firstOrNull { it.materialId == materialId }
        return material?.getLandedCostPerUnit()
    }
}

enum class LandedCostStatus {
    DRAFT,          // Being created
    CALCULATED,     // Costs allocated to materials
    POSTED,         // Posted to material ledger
    CANCELLED       // Cancelled
}

enum class CostAllocationMethod {
    BY_VALUE,       // Allocate based on material value
    BY_QUANTITY,    // Allocate based on quantity
    BY_WEIGHT,      // Allocate based on weight
    BY_VOLUME,      // Allocate based on volume
    MANUAL          // Manual allocation
}

enum class Incoterms {
    EXW,    // Ex Works
    FCA,    // Free Carrier
    CPT,    // Carriage Paid To
    CIP,    // Carriage and Insurance Paid To
    DAP,    // Delivered At Place
    DPU,    // Delivered at Place Unloaded
    DDP,    // Delivered Duty Paid
    FAS,    // Free Alongside Ship
    FOB,    // Free On Board
    CFR,    // Cost and Freight
    CIF     // Cost, Insurance and Freight
}
```

**LandedCostMaterial (Entity)**

```kotlin
@Entity
@Table(
    name = "landed_cost_materials",
    schema = "costing_schema",
    indexes = [
        Index(name = "idx_lc_mat_document", columnList = "landedCostDocumentId"),
        Index(name = "idx_lc_mat_material", columnList = "materialId")
    ]
)
class LandedCostMaterial(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "landed_cost_document_id", nullable = false)
    var landedCostDocument: LandedCostDocument,

    @Column(nullable = false)
    val lineNumber: Int,

    @Column(nullable = false)
    val materialId: UUID,

    @Column(nullable = false)
    val materialNumber: String,

    @Column(nullable = false, precision = 19, scale = 4)
    val quantity: BigDecimal,

    @Column(nullable = false)
    val unitOfMeasure: String,

    // Base price (from PO/invoice)
    @Column(nullable = false, precision = 19, scale = 4)
    val unitPrice: BigDecimal,

    @Column(nullable = false, precision = 19, scale = 2)
    val totalPrice: BigDecimal,

    @Column(nullable = false)
    val currency: String,

    // Physical properties for allocation
    @Column(precision = 19, scale = 4)
    val weight: BigDecimal? = null,

    val weightUnit: String? = null,

    @Column(precision = 19, scale = 4)
    val volume: BigDecimal? = null,

    val volumeUnit: String? = null,

    // Allocated costs
    @OneToMany(mappedBy = "material", cascade = [CascadeType.ALL])
    val allocatedCosts: MutableList<AllocatedLandedCost> = mutableListOf(),

    // Totals
    @Column(precision = 19, scale = 2)
    var totalAllocatedCost: BigDecimal = BigDecimal.ZERO,

    @Column(precision = 19, scale = 2)
    var totalLandedCost: BigDecimal = BigDecimal.ZERO,

    @Column(precision = 19, scale = 4)
    var landedCostPerUnit: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now()
) {
    fun addAllocatedCost(costType: LandedCostType, amount: BigDecimal) {
        val allocated = AllocatedLandedCost(
            material = this,
            costType = costType,
            allocatedAmount = amount,
            currency = currency
        )
        allocatedCosts.add(allocated)
        recalculateLandedCost()
    }

    fun recalculateLandedCost() {
        totalAllocatedCost = allocatedCosts.sumOf { it.allocatedAmount }
        totalLandedCost = totalPrice + totalAllocatedCost
        landedCostPerUnit = if (quantity > BigDecimal.ZERO) {
            totalLandedCost / quantity
        } else {
            BigDecimal.ZERO
        }
        updatedAt = Instant.now()
    }

    fun getLandedCostPerUnit(): BigDecimal = landedCostPerUnit

    fun getCostBreakdown(): Map<String, BigDecimal> {
        val breakdown = mutableMapOf<String, BigDecimal>()
        breakdown["Base Price"] = totalPrice
        allocatedCosts.forEach {
            breakdown[it.costType.name] = it.allocatedAmount
        }
        breakdown["Total Landed Cost"] = totalLandedCost
        return breakdown
    }
}
```

**LandedCostComponent (Entity)**

```kotlin
@Entity
@Table(
    name = "landed_cost_components",
    schema = "costing_schema",
    indexes = [
        Index(name = "idx_lc_comp_document", columnList = "landedCostDocumentId"),
        Index(name = "idx_lc_comp_type", columnList = "costType")
    ]
)
class LandedCostComponent(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "landed_cost_document_id", nullable = false)
    var landedCostDocument: LandedCostDocument,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    val costType: LandedCostType,

    @Column(nullable = false)
    val costDescription: String,

    @Column(nullable = false, precision = 19, scale = 2)
    val totalAmount: BigDecimal,

    @Column(nullable = false)
    val currency: String,

    // Service provider (freight company, customs broker, etc.)
    val serviceProviderId: UUID? = null,
    val serviceProviderName: String? = null,

    // Reference invoice/document
    val invoiceNumber: String? = null,
    val invoiceDate: LocalDate? = null,

    // Tax information
    val taxable: Boolean = false,

    @Column(precision = 19, scale = 2)
    val taxAmount: BigDecimal? = null,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now()
)

enum class LandedCostType {
    // Transportation costs
    OCEAN_FREIGHT,
    AIR_FREIGHT,
    GROUND_FREIGHT,
    INLAND_TRANSPORTATION,

    // Insurance
    CARGO_INSURANCE,

    // Customs and duties
    IMPORT_DUTY,
    CUSTOMS_DUTY,
    EXCISE_TAX,
    VAT,
    ANTI_DUMPING_DUTY,

    // Port and terminal charges
    PORT_CHARGES,
    TERMINAL_HANDLING_CHARGES,
    DEMURRAGE,
    DETENTION,

    // Documentation and brokerage
    CUSTOMS_BROKERAGE,
    DOCUMENTATION_FEES,
    CLEARANCE_FEES,

    // Storage and handling
    WAREHOUSING,
    LOADING_UNLOADING,
    PACKAGING,
    CONTAINER_FEES,

    // Financial
    BANK_CHARGES,
    LETTER_OF_CREDIT_FEES,
    EXCHANGE_RATE_DIFFERENCE,

    // Quality and inspection
    INSPECTION_FEES,
    QUALITY_CONTROL,
    FUMIGATION,

    // Other
    COURIER_CHARGES,
    MISCELLANEOUS,
    OTHER
}
```

**AllocatedLandedCost (Entity)**

```kotlin
@Entity
@Table(
    name = "allocated_landed_costs",
    schema = "costing_schema"
)
class AllocatedLandedCost(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "material_id", nullable = false)
    var material: LandedCostMaterial,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    val costType: LandedCostType,

    @Column(nullable = false, precision = 19, scale = 2)
    val allocatedAmount: BigDecimal,

    @Column(nullable = false)
    val currency: String,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now()
)
```

**ShippingAddress (Embeddable)**

```kotlin
@Embeddable
data class ShippingAddress(
    @Column(name = "address_line1")
    val addressLine1: String,

    @Column(name = "address_line2")
    val addressLine2: String? = null,

    @Column(name = "address_city")
    val city: String,

    @Column(name = "address_state")
    val state: String? = null,

    @Column(name = "address_postal_code")
    val postalCode: String,

    @Column(name = "address_country")
    val country: String,

    @Column(name = "address_country_code")
    val countryCode: String // ISO 3166-1 alpha-2
)
```

### Domain Services

**LandedCostCalculationService**

```kotlin
class LandedCostCalculationService {
    /**
     * Calculate landed costs for a purchase order or shipment
     */
    fun calculateLandedCosts(
        purchaseOrderId: UUID,
        freight: BigDecimal,
        insurance: BigDecimal,
        customsDuty: BigDecimal,
        otherCosts: Map<LandedCostType, BigDecimal>
    ): LandedCostDocument {
        // 1. Retrieve PO details and line items
        // 2. Create landed cost document
        // 3. Add all cost components
        // 4. Calculate and allocate costs
        // 5. Update material costs

        return LandedCostDocument(
            documentNumber = "LC-2025-000001",
            documentDate = LocalDate.now(),
            vendorId = UUID.randomUUID(),
            vendorName = "Vendor",
            originAddress = ShippingAddress("", "", "", "", "", "", ""),
            destinationAddress = ShippingAddress("", "", "", "", "", "", ""),
            incoterms = Incoterms.CIF,
            createdBy = UUID.randomUUID(),
            tenantId = UUID.randomUUID()
        )
    }

    /**
     * Calculate duty rates based on HS codes and origin country
     */
    fun calculateCustomsDuty(
        hsCode: String,
        originCountry: String,
        destinationCountry: String,
        materialValue: BigDecimal
    ): BigDecimal {
        // Lookup duty rate from tariff tables
        // Apply trade agreements
        // Calculate duty amount

        return BigDecimal.ZERO
    }

    /**
     * Estimate landed cost before actual shipment
     */
    fun estimateLandedCost(
        materialId: UUID,
        quantity: BigDecimal,
        unitPrice: BigDecimal,
        originCountry: String,
        destinationCountry: String,
        transportMode: TransportMode
    ): LandedCostEstimate {
        // Use historical data and rates
        // Apply standard freight rates
        // Estimate duties and taxes

        return LandedCostEstimate(
            totalLandedCost = BigDecimal.ZERO,
            landedCostPerUnit = BigDecimal.ZERO,
            breakdown = emptyMap()
        )
    }
}

enum class TransportMode {
    OCEAN, AIR, GROUND, RAIL, MULTIMODAL
}

data class LandedCostEstimate(
    val totalLandedCost: BigDecimal,
    val landedCostPerUnit: BigDecimal,
    val breakdown: Map<LandedCostType, BigDecimal>
)
```

**DutyCalculationService**

```kotlin
class DutyCalculationService {
    /**
     * Calculate import duty based on HS code and country of origin
     */
    fun calculateImportDuty(
        hsCode: String,
        originCountry: String,
        destinationCountry: String,
        customsValue: BigDecimal
    ): DutyCalculation {
        // 1. Lookup HS code in tariff database
        // 2. Check for trade agreements (free trade, preferential rates)
        // 3. Apply duty rate
        // 4. Calculate VAT/GST if applicable

        return DutyCalculation(
            dutyRate = BigDecimal.ZERO,
            dutyAmount = BigDecimal.ZERO,
            vatRate = BigDecimal.ZERO,
            vatAmount = BigDecimal.ZERO,
            totalDutyAndTax = BigDecimal.ZERO
        )
    }

    /**
     * Check for anti-dumping duties
     */
    fun checkAntiDumpingDuty(
        materialId: UUID,
        originCountry: String,
        destinationCountry: String
    ): AntiDumpingDutyInfo? {
        // Check if material is subject to anti-dumping duties
        return null
    }
}

data class DutyCalculation(
    val dutyRate: BigDecimal,
    val dutyAmount: BigDecimal,
    val vatRate: BigDecimal,
    val vatAmount: BigDecimal,
    val totalDutyAndTax: BigDecimal
)

data class AntiDumpingDutyInfo(
    val applicable: Boolean,
    val dutyRate: BigDecimal,
    val effectiveFrom: LocalDate,
    val effectiveTo: LocalDate?
)
```

### Domain Events

```kotlin
// Landed Cost Events
data class LandedCostDocumentCreatedEvent(
    val documentId: UUID,
    val documentNumber: String,
    val purchaseOrderId: UUID?,
    val shipmentId: UUID?,
    val totalMaterialCost: BigDecimal,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
) : DomainEvent

data class LandedCostCalculatedEvent(
    val documentId: UUID,
    val documentNumber: String,
    val totalLandedCost: BigDecimal,
    val totalAdditionalCosts: BigDecimal,
    val allocationMethod: CostAllocationMethod,
    val materialCount: Int,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
) : DomainEvent

data class LandedCostPostedEvent(
    val documentId: UUID,
    val documentNumber: String,
    val materialsAffected: List<UUID>,
    val totalLandedCost: BigDecimal,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
) : DomainEvent

data class MaterialLandedCostUpdatedEvent(
    val materialId: UUID,
    val oldLandedCost: BigDecimal,
    val newLandedCost: BigDecimal,
    val landedCostDocumentId: UUID,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
) : DomainEvent
```

---

## Domain Services

**ActualCostingService**

```kotlin
class ActualCostingService {
    /**
     * Calculate actual costs for a period using material ledger data
     */
    fun calculateActualCosts(
        fiscalYear: Int,
        fiscalPeriod: Int,
        plantId: UUID
    ): ActualCostingResult {
        // 1. Retrieve all material ledger entries for period
        // 2. Calculate actual unit costs based on:
        //    - Invoice receipts (actual purchase prices)
        //    - Production confirmations (actual production costs)
        //    - Overhead allocations
        // 3. Compare with standard costs
        // 4. Calculate variances
        // 5. Update material prices with actual costs

        return ActualCostingResult(
            materialsProcessed = 0,
            averageVariancePercent = BigDecimal.ZERO,
            totalVarianceAmount = BigDecimal.ZERO
        )
    }
}

data class ActualCostingResult(
    val materialsProcessed: Int,
    val averageVariancePercent: BigDecimal,
    val totalVarianceAmount: BigDecimal
)
```

**VarianceAnalysisService**

```kotlin
class VarianceAnalysisService {
    /**
     * Analyze variances and categorize by type
     */
    fun analyzeVariances(
        fiscalYear: Int,
        fiscalPeriod: Int
    ): List<VarianceAnalysisResult> {
        // Identify significant variances
        // Categorize by type (price, quantity, efficiency)
        // Calculate root causes
        // Generate recommendations

        return emptyList()
    }

    /**
     * Calculate price variance
     * Price Variance = (Actual Price - Standard Price) × Actual Quantity
     */
    fun calculatePriceVariance(
        standardPrice: BigDecimal,
        actualPrice: BigDecimal,
        actualQuantity: BigDecimal
    ): BigDecimal {
        return (actualPrice - standardPrice) * actualQuantity
    }

    /**
     * Calculate quantity variance
     * Quantity Variance = (Actual Quantity - Standard Quantity) × Standard Price
     */
    fun calculateQuantityVariance(
        standardQuantity: BigDecimal,
        actualQuantity: BigDecimal,
        standardPrice: BigDecimal
    ): BigDecimal {
        return (actualQuantity - standardQuantity) * standardPrice
    }
}

data class VarianceAnalysisResult(
    val varianceType: VarianceType,
    val totalAmount: BigDecimal,
    val impactPercent: BigDecimal,
    val topMaterials: List<UUID>
)
```

**CostRollupService**

```kotlin
class CostRollupService {
    /**
     * Roll up costs from components to finished products
     * Following BOM structure
     */
    fun rollupCosts(
        materialId: UUID,
        bomId: UUID,
        costingVersion: String
    ): CostRollupResult {
        // 1. Get BOM structure
        // 2. Retrieve component costs
        // 3. Add operation costs from routing
        // 4. Apply overhead rates
        // 5. Calculate total rolled-up cost

        return CostRollupResult(
            materialId = materialId,
            totalCost = BigDecimal.ZERO,
            costBreakdown = emptyMap()
        )
    }
}

data class CostRollupResult(
    val materialId: UUID,
    val totalCost: BigDecimal,
    val costBreakdown: Map<CostComponentType, BigDecimal>
)
```

---

## Domain Events

```kotlin
// Cost Estimate Events
data class CostEstimateCreatedEvent(
    val estimateId: UUID,
    val materialId: UUID,
    val costingVersion: String,
    val totalCost: BigDecimal,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
) : DomainEvent

data class CostEstimateReleasedEvent(
    val estimateId: UUID,
    val materialId: UUID,
    val unitCost: BigDecimal,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
) : DomainEvent

data class StandardCostChangedEvent(
    val materialId: UUID,
    val oldStandardCost: BigDecimal,
    val newStandardCost: BigDecimal,
    val effectiveDate: LocalDate,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
) : DomainEvent

// Material Ledger Events
data class MaterialLedgerEntryPostedEvent(
    val entryId: UUID,
    val materialId: UUID,
    val transactionType: MaterialLedgerTransactionType,
    val quantity: BigDecimal,
    val totalValue: BigDecimal,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
) : DomainEvent

// Variance Events
data class VarianceDetectedEvent(
    val varianceId: UUID,
    val materialId: UUID,
    val varianceType: VarianceType,
    val varianceAmount: BigDecimal,
    val varianceImpact: VarianceImpact,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
) : DomainEvent

data class SignificantVarianceAlertEvent(
    val varianceId: UUID,
    val materialId: UUID,
    val varianceAmount: BigDecimal,
    val thresholdExceeded: BigDecimal,
    val requiresReview: Boolean,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
) : DomainEvent

// Period Close Events
data class PeriodCloseStartedEvent(
    val runId: UUID,
    val fiscalYear: Int,
    val fiscalPeriod: Int,
    val plantId: UUID,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
) : DomainEvent

data class PeriodCloseCompletedEvent(
    val runId: UUID,
    val fiscalYear: Int,
    val fiscalPeriod: Int,
    val materialsProcessed: Int,
    val totalVarianceAmount: BigDecimal,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
) : DomainEvent

// Planning Events
data class CostPlanningScenarioCreatedEvent(
    val scenarioId: UUID,
    val scenarioCode: String,
    val planningYear: Int,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
) : DomainEvent

// WIP Events
data class WIPValueUpdatedEvent(
    val wipPositionId: UUID,
    val productionOrderId: UUID,
    val wipValue: BigDecimal,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
) : DomainEvent

data class WIPSettledEvent(
    val wipPositionId: UUID,
    val productionOrderId: UUID,
    val settledAmount: BigDecimal,
    val settlementDocumentId: UUID,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
) : DomainEvent
```

---

## Integration Points

### With Supply Chain Service

-   **Material Master**: Share material data
-   **Inventory Movements**: Post material ledger entries for goods movements
-   **Production Orders**: Track WIP and actual production costs

### With Financial Management Service

-   **General Ledger**: Post variance settlements, period-end adjustments
-   **Accounts Payable**: Invoice receipts update actual costs
-   **Cost Centers**: Activity allocations and overhead rates

### With Production Planning Service

-   **BOM**: Cost rollup calculations
-   **Routing**: Operation cost calculations
-   **Production Confirmations**: Actual cost capture

### With Procurement Service

-   **Purchase Orders**: Standard vs. actual price tracking
-   **Invoice Verification**: Actual purchase price updates
-   **Landed Costs**: Freight, duty, and additional cost allocation

### With Logistics Service

-   **Shipments**: Landed cost calculation triggers
-   **Freight Invoices**: Actual freight cost capture
-   **Customs Documents**: Duty and tax information

---

## Reporting & Analytics

### Key Reports

1. **Cost Estimate Report**

    - Detailed cost breakdown by component
    - Multi-level BOM cost rollup
    - Comparison across costing versions

2. **Variance Analysis Report**

    - Price, quantity, efficiency variances
    - Trending over periods
    - Top variance contributors

3. **Material Ledger Report**

    - Actual cost history
    - Valuation method comparison
    - Period-end valuations

4. **Product Cost Planning Report**

    - Scenario comparisons
    - Cost trend projections
    - What-if analysis results

5. **WIP Report**

    - WIP positions by production order
    - Cost accumulation details
    - Settlement status

6. **Landed Cost Report**

    - Landed cost breakdown by material
    - Cost allocation analysis
    - Freight and duty tracking
    - Incoterms analysis
    - Vendor/shipment comparison

7. **Profitability Analysis**
    - Product profitability
    - Cost structure analysis
    - Contribution margin

---

## Best Practices

1. **Cost Estimation**

    - Regular updates to standard costs
    - Detailed cost component tracking
    - Version control for cost estimates

2. **Variance Management**

    - Timely variance analysis
    - Root cause investigation
    - Corrective action tracking

3. **Period Closing**

    - Systematic period-end closing
    - Complete variance settlement
    - Accurate WIP valuation

4. **Cost Planning**

    - Multiple scenario planning
    - Regular forecast updates
    - Integration with budgeting

5. **Data Quality**

    - Accurate transaction recording
    - Timely invoice receipts
    - Complete production confirmations

6. **Landed Cost Management**
    - Timely capture of all import costs
    - Accurate freight and duty allocation
    - Regular reconciliation with actuals
    - Incoterms compliance

---

## Summary

This comprehensive Product Costing & Cost Analysis domain model follows **SAP CO-PC** (Controlling - Product Costing) patterns and provides:

✅ **Standard Cost Estimation** with detailed component breakdown
✅ **Material Ledger** for actual costing and multi-valuation
✅ **Comprehensive Variance Analysis** (price, quantity, efficiency)
✅ **Product Cost Planning** with scenario modeling
✅ **WIP Tracking** for production orders
✅ **Landed Cost Calculation** with freight, duty, and import costs
✅ **Cost Center & Activity-Based Costing** support
✅ **Period-End Closing** processes
✅ **Integration** with financial and operational systems

This provides world-class cost management capabilities for global manufacturing and trading enterprises.
