# Domain Models - Supply Chain & Manufacturing Service

## Schema: `supply_schema`

This service implements **SAP MM (Materials Management)** and **SAP PP (Production Planning)** patterns following world-class ERP standards.

---

## Domain 1: Inventory Management (SAP MM Pattern)

### Overview

Comprehensive inventory management following SAP MM principles with multi-location support, batch tracking, and valuation.

### Aggregates

**Material (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "materials",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_material_number", columnList = "materialNumber"),
        Index(name = "idx_material_type", columnList = "materialType"),
        Index(name = "idx_material_group", columnList = "materialGroup")
    ]
)
class Material(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val materialNumber: String, // MAT-NNNNNNNNNN (10 digits)

    @Column(nullable = false)
    var description: String,

    var longDescription: String? = null,

    // SAP MM Classification
    @Enumerated(EnumType.STRING)
    val materialType: MaterialType,

    @Column(nullable = false)
    val materialGroup: String, // Material group code

    // Base unit of measure
    @Column(nullable = false)
    val baseUnitOfMeasure: String, // EA, KG, L, M, etc.

    // Alternative units
    @OneToMany(mappedBy = "material", cascade = [CascadeType.ALL])
    val alternativeUnits: MutableSet<MaterialUnitOfMeasure> = mutableSetOf(),

    // Dimensions and weight
    @Embedded
    var dimensions: MaterialDimensions?,

    // Valuation
    @Embedded
    var valuation: MaterialValuation,

    // Procurement
    @Embedded
    var procurement: ProcurementData,

    // Sales
    @Embedded
    var salesData: SalesData?,

    // MRP (Material Requirements Planning)
    @Embedded
    var mrpData: MRPData,

    // Quality management
    @Column(nullable = false)
    val qualityInspectionRequired: Boolean = false,

    // Batch management
    @Column(nullable = false)
    val batchManaged: Boolean = false,

    // Serial number management
    @Column(nullable = false)
    val serialNumberManaged: Boolean = false,

    // Shelf life
    val shelfLifeDays: Int? = null,

    // Storage
    @Embedded
    var storageData: StorageData?,

    // Status
    @Enumerated(EnumType.STRING)
    var status: MaterialStatus,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
) {
    fun activate() {
        this.status = MaterialStatus.ACTIVE
        this.updatedAt = Instant.now()
    }

    fun block() {
        this.status = MaterialStatus.BLOCKED
        this.updatedAt = Instant.now()
    }

    fun convertQuantity(quantity: BigDecimal, fromUnit: String, toUnit: String): BigDecimal {
        if (fromUnit == toUnit) return quantity

        val conversion = alternativeUnits.firstOrNull { it.alternativeUnit == toUnit }
            ?: throw IllegalArgumentException("No conversion found for $toUnit")

        return quantity * conversion.conversionFactor
    }
}

enum class MaterialType {
    RAW_MATERIAL,           // RMAT - Raw materials
    SEMI_FINISHED,          // HALB - Semi-finished goods
    FINISHED_PRODUCT,       // FERT - Finished products
    TRADING_GOODS,          // HAWA - Trading goods
    SPARE_PARTS,            // ERSA - Spare parts
    PACKAGING,              // VERP - Packaging
    CONSUMABLES,            // VERB - Consumables
    SERVICES,               // DIEN - Services
    NON_STOCK              // NLAG - Non-stock items
}

enum class MaterialStatus {
    ACTIVE, BLOCKED, OBSOLETE, DISCONTINUED
}

@Embeddable
data class MaterialDimensions(
    @Column(precision = 19, scale = 4)
    val length: BigDecimal? = null,

    @Column(precision = 19, scale = 4)
    val width: BigDecimal? = null,

    @Column(precision = 19, scale = 4)
    val height: BigDecimal? = null,

    val dimensionUnit: String = "CM",

    @Column(precision = 19, scale = 4)
    val weight: BigDecimal? = null,

    val weightUnit: String = "KG",

    @Column(precision = 19, scale = 4)
    val volume: BigDecimal? = null,

    val volumeUnit: String = "L"
)

@Embeddable
data class MaterialValuation(
    @Enumerated(EnumType.STRING)
    val valuationMethod: ValuationMethod,

    @Column(precision = 19, scale = 4)
    var standardPrice: BigDecimal = BigDecimal.ZERO,

    @Column(precision = 19, scale = 4)
    var movingAveragePrice: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false)
    val currency: String = "USD",

    @Column(precision = 19, scale = 4)
    val lastPurchasePrice: BigDecimal? = null,

    val priceUnit: Int = 1 // Price per X units
)

enum class ValuationMethod {
    STANDARD_PRICE,      // Standard costing
    MOVING_AVERAGE,      // Moving average price
    FIFO,               // First-in, first-out
    LIFO                // Last-in, first-out
}

@Embeddable
data class ProcurementData(
    @Enumerated(EnumType.STRING)
    val procurementType: ProcurementType,

    val defaultVendorId: UUID? = null,

    val purchasingGroup: String? = null,

    @Column(precision = 19, scale = 4)
    val minimumOrderQuantity: BigDecimal? = null,

    @Column(precision = 19, scale = 4)
    val standardOrderQuantity: BigDecimal? = null,

    val leadTimeDays: Int = 0,

    val goodsReceiptProcessingDays: Int = 0
)

enum class ProcurementType {
    EXTERNAL,           // Purchase from vendors
    IN_HOUSE,          // In-house production
    BOTH,              // Both external and in-house
    SUBCONTRACTING     // Subcontracting
}

@Embeddable
data class SalesData(
    val salesOrganization: String,

    val distributionChannel: String,

    @Column(precision = 19, scale = 4)
    val minimumOrderQuantity: BigDecimal? = null,

    @Column(precision = 19, scale = 4)
    val deliveryQuantity: BigDecimal? = null,

    val availabilityCheck: Boolean = true
)

@Embeddable
data class MRPData(
    @Enumerated(EnumType.STRING)
    val mrpType: MRPType,

    @Enumerated(EnumType.STRING)
    val mrpController: String? = null,

    @Column(precision = 19, scale = 4)
    val reorderPoint: BigDecimal? = null,

    @Column(precision = 19, scale = 4)
    val safetyStock: BigDecimal? = null,

    @Column(precision = 19, scale = 4)
    val maximumStock: BigDecimal? = null,

    val planningTimeFenceDays: Int? = null
)

enum class MRPType {
    NO_MRP,            // No planning
    MRP,               // Material requirements planning
    REORDER_POINT,     // Reorder point planning
    FORECAST_BASED,    // Forecast-based planning
    TIME_PHASED        // Time-phased planning
}

@Embeddable
data class StorageData(
    val storageConditions: String? = null,

    val temperatureMin: BigDecimal? = null,

    val temperatureMax: BigDecimal? = null,

    val hazardousMaterial: Boolean = false,

    val hazardClass: String? = null
)
```

**MaterialUnitOfMeasure (Entity)**

```kotlin
@Entity
@Table(
    name = "material_units_of_measure",
    schema = "supply_schema",
    uniqueConstraints = [
        UniqueConstraint(
            name = "uk_material_uom",
            columnNames = ["materialId", "alternativeUnit"]
        )
    ]
)
class MaterialUnitOfMeasure(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "material_id", nullable = false)
    val material: Material,

    @Column(nullable = false)
    val alternativeUnit: String,

    @Column(nullable = false, precision = 19, scale = 8)
    val conversionFactor: BigDecimal,

    val ean: String? = null, // EAN/UPC barcode

    @Column(precision = 19, scale = 4)
    val length: BigDecimal? = null,

    @Column(precision = 19, scale = 4)
    val width: BigDecimal? = null,

    @Column(precision = 19, scale = 4)
    val height: BigDecimal? = null,

    @Column(precision = 19, scale = 4)
    val weight: BigDecimal? = null
)
```

**Stock (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "stock",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_stock_material", columnList = "materialId"),
        Index(name = "idx_stock_location", columnList = "storageLocationId"),
        Index(name = "idx_stock_batch", columnList = "batchNumber")
    ],
    uniqueConstraints = [
        UniqueConstraint(
            name = "uk_stock",
            columnNames = ["materialId", "storageLocationId", "batchNumber"]
        )
    ]
)
class Stock(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "material_id", nullable = false)
    val material: Material,

    @ManyToOne
    @JoinColumn(name = "storage_location_id", nullable = false)
    val storageLocation: StorageLocation,

    val batchNumber: String? = null,

    // Stock quantities (SAP MM stock types)
    @Column(nullable = false, precision = 19, scale = 4)
    var unrestrictedStock: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false, precision = 19, scale = 4)
    var qualityInspectionStock: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false, precision = 19, scale = 4)
    var blockedStock: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false, precision = 19, scale = 4)
    var reservedStock: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false, precision = 19, scale = 4)
    var inTransitStock: BigDecimal = BigDecimal.ZERO,

    // Valuation
    @Column(precision = 19, scale = 2)
    var totalValue: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false)
    val currency: String = "USD",

    // Last movement
    var lastMovementDate: Instant? = null,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
) {
    fun getTotalQuantity(): BigDecimal {
        return unrestrictedStock + qualityInspectionStock +
               blockedStock + reservedStock + inTransitStock
    }

    fun getAvailableQuantity(): BigDecimal {
        return unrestrictedStock - reservedStock
    }

    fun goodsReceipt(quantity: BigDecimal, toInspection: Boolean = false) {
        require(quantity > BigDecimal.ZERO) { "Quantity must be positive" }

        if (toInspection && material.qualityInspectionRequired) {
            qualityInspectionStock += quantity
        } else {
            unrestrictedStock += quantity
        }

        lastMovementDate = Instant.now()
        updatedAt = Instant.now()
    }

    fun goodsIssue(quantity: BigDecimal) {
        require(quantity > BigDecimal.ZERO) { "Quantity must be positive" }
        require(getAvailableQuantity() >= quantity) {
            "Insufficient available stock. Available: ${getAvailableQuantity()}, Requested: $quantity"
        }

        unrestrictedStock -= quantity
        lastMovementDate = Instant.now()
        updatedAt = Instant.now()
    }

    fun transferToUnrestricted(quantity: BigDecimal) {
        require(qualityInspectionStock >= quantity) {
            "Insufficient quality inspection stock"
        }

        qualityInspectionStock -= quantity
        unrestrictedStock += quantity
        updatedAt = Instant.now()
    }

    fun blockStock(quantity: BigDecimal) {
        require(unrestrictedStock >= quantity) {
            "Insufficient unrestricted stock to block"
        }

        unrestrictedStock -= quantity
        blockedStock += quantity
        updatedAt = Instant.now()
    }

    fun reserveStock(quantity: BigDecimal, reservationId: UUID) {
        require(unrestrictedStock >= quantity + reservedStock) {
            "Insufficient unrestricted stock to reserve"
        }

        reservedStock += quantity
        updatedAt = Instant.now()
    }

    fun releaseReservation(quantity: BigDecimal) {
        require(reservedStock >= quantity) {
            "Cannot release more than reserved quantity"
        }

        reservedStock -= quantity
        updatedAt = Instant.now()
    }
}
```

**StorageLocation (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "storage_locations",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_storage_location_code", columnList = "locationCode"),
        Index(name = "idx_storage_location_warehouse", columnList = "warehouseId")
    ]
)
class StorageLocation(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val locationCode: String,

    @Column(nullable = false)
    var name: String,

    @Column(length = 1000)
    var description: String? = null,

    @ManyToOne
    @JoinColumn(name = "warehouse_id", nullable = false)
    val warehouse: Warehouse,

    @Enumerated(EnumType.STRING)
    val locationType: LocationType,

    @Embedded
    var address: Address?,

    // Capacity
    @Column(precision = 19, scale = 2)
    val storageCapacity: BigDecimal? = null,

    val capacityUnit: String? = null,

    // Status
    @Enumerated(EnumType.STRING)
    var status: LocationStatus,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now()
)

enum class LocationType {
    WAREHOUSE, STORAGE_LOCATION, BIN_LOCATION, PRODUCTION_AREA, QUALITY_AREA
}

enum class LocationStatus {
    ACTIVE, INACTIVE, UNDER_MAINTENANCE, FULL
}
```

**Warehouse (Aggregate Root)**

```kotlin
@Entity
@Table(name = "warehouses", schema = "supply_schema")
class Warehouse(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val warehouseCode: String,

    @Column(nullable = false)
    var name: String,

    @Embedded
    var address: Address,

    @Enumerated(EnumType.STRING)
    var warehouseType: WarehouseType,

    @Enumerated(EnumType.STRING)
    var status: WarehouseStatus,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now()
)

enum class WarehouseType {
    CENTRAL, REGIONAL, LOCAL, TRANSIT, QUARANTINE, RETURNS
}

enum class WarehouseStatus {
    ACTIVE, INACTIVE, UNDER_CONSTRUCTION
}
```

**MaterialDocument (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "material_documents",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_mat_doc_number", columnList = "documentNumber"),
        Index(name = "idx_mat_doc_date", columnList = "postingDate"),
        Index(name = "idx_mat_doc_type", columnList = "movementType")
    ]
)
class MaterialDocument(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val documentNumber: String, // MD-YYYY-NNNNNN

    @Column(nullable = false)
    val postingDate: LocalDate,

    @Column(nullable = false)
    val documentDate: LocalDate,

    @Enumerated(EnumType.STRING)
    val movementType: MovementType,

    // Reference documents
    val referenceDocumentType: String? = null,
    val referenceDocumentNumber: String? = null,

    // Line items
    @OneToMany(mappedBy = "materialDocument", cascade = [CascadeType.ALL])
    val items: MutableList<MaterialDocumentItem> = mutableListOf(),

    @Column(length = 2000)
    var headerText: String? = null,

    // Status
    @Enumerated(EnumType.STRING)
    var status: MaterialDocumentStatus = MaterialDocumentStatus.POSTED,

    // Reversal
    var reversalDate: LocalDate? = null,
    val reversalDocumentId: UUID? = null,

    // Audit
    @Column(nullable = false)
    val createdBy: UUID,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
) {
    companion object {
        fun generateDocumentNumber(year: Int, sequence: Long): String {
            return "MD-$year-${sequence.toString().padStart(6, '0')}"
        }
    }

    fun addItem(item: MaterialDocumentItem) {
        items.add(item)
        item.materialDocument = this
    }

    fun reverse(): MaterialDocument {
        require(status == MaterialDocumentStatus.POSTED) {
            "Only posted documents can be reversed"
        }

        val reversalDoc = MaterialDocument(
            documentNumber = generateDocumentNumber(
                LocalDate.now().year,
                System.currentTimeMillis()
            ),
            postingDate = LocalDate.now(),
            documentDate = LocalDate.now(),
            movementType = movementType.getReversal(),
            referenceDocumentType = "Material Document",
            referenceDocumentNumber = documentNumber,
            headerText = "Reversal of $documentNumber",
            status = MaterialDocumentStatus.POSTED,
            createdBy = createdBy,
            tenantId = tenantId
        )

        // Add reversed items
        items.forEach { originalItem ->
            val reversedItem = MaterialDocumentItem(
                lineNumber = originalItem.lineNumber,
                material = originalItem.material,
                quantity = originalItem.quantity,
                unitOfMeasure = originalItem.unitOfMeasure,
                storageLocation = originalItem.storageLocation,
                batchNumber = originalItem.batchNumber,
                movementIndicator = originalItem.movementIndicator.opposite(),
                itemText = "Reversal: ${originalItem.itemText}"
            )
            reversalDoc.addItem(reversedItem)
        }

        this.status = MaterialDocumentStatus.REVERSED
        this.reversalDate = LocalDate.now()

        return reversalDoc
    }
}

enum class MovementType {
    GOODS_RECEIPT_PO,           // 101 - Goods receipt from PO
    GOODS_RECEIPT_PRODUCTION,   // 131 - Goods receipt from production
    GOODS_ISSUE_COST_CENTER,    // 201 - Goods issue to cost center
    GOODS_ISSUE_PRODUCTION,     // 261 - Goods issue to production
    GOODS_ISSUE_SALES_ORDER,    // 601 - Goods issue for sales order
    TRANSFER_POSTING,           // 311 - Transfer posting
    STOCK_TRANSFER,             // 351 - Stock transfer
    PHYSICAL_INVENTORY;         // 701/702 - Physical inventory

    fun getReversal(): MovementType {
        return when (this) {
            GOODS_RECEIPT_PO -> GOODS_ISSUE_SALES_ORDER
            GOODS_ISSUE_PRODUCTION -> GOODS_RECEIPT_PRODUCTION
            else -> this
        }
    }
}

enum class MaterialDocumentStatus {
    POSTED, REVERSED, CANCELLED
}

enum class MovementIndicator {
    RECEIPT, ISSUE;

    fun opposite(): MovementIndicator {
        return when (this) {
            RECEIPT -> ISSUE
            ISSUE -> RECEIPT
        }
    }
}
```

**MaterialDocumentItem (Entity)**

```kotlin
@Entity
@Table(name = "material_document_items", schema = "supply_schema")
class MaterialDocumentItem(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "material_document_id", nullable = false)
    var materialDocument: MaterialDocument? = null,

    @Column(nullable = false)
    val lineNumber: Int,

    @ManyToOne
    @JoinColumn(name = "material_id", nullable = false)
    val material: Material,

    @Column(nullable = false, precision = 19, scale = 4)
    val quantity: BigDecimal,

    @Column(nullable = false)
    val unitOfMeasure: String,

    @ManyToOne
    @JoinColumn(name = "storage_location_id", nullable = false)
    val storageLocation: StorageLocation,

    val batchNumber: String? = null,

    @Enumerated(EnumType.STRING)
    val movementIndicator: MovementIndicator,

    // Valuation
    @Column(precision = 19, scale = 4)
    val unitPrice: BigDecimal? = null,

    @Column(precision = 19, scale = 2)
    val totalValue: BigDecimal? = null,

    @Column(nullable = false)
    val currency: String = "USD",

    // Accounting
    val glAccountId: UUID? = null,
    val costCenterId: UUID? = null,

    @Column(length = 1000)
    var itemText: String? = null
)
```

---

## Domain 1A: Product Modeling - Variants, Bundles & Kits

### Overview

Advanced product modeling supporting:

-   **Product Variants** (size, color, style combinations)
-   **Product Bundles** (selling multiple items together)
-   **Product Kits** (assembly of components)
-   **Configurable Products** (customer-specific configurations)

### Aggregates

**ProductMaster (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "product_masters",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_product_master_number", columnList = "productMasterNumber"),
        Index(name = "idx_product_master_type", columnList = "productType")
    ]
)
class ProductMaster(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val productMasterNumber: String, // PM-NNNNNNNNNN

    @Column(nullable = false)
    var name: String,

    @Lob
    var description: String?,

    @Enumerated(EnumType.STRING)
    val productType: ProductType,

    // Category and classification
    val categoryId: UUID?,
    val brandId: UUID?,
    val manufacturerId: UUID?,

    // Variant configuration (if applicable)
    @Enumerated(EnumType.STRING)
    val variantStrategy: VariantStrategy = VariantStrategy.NONE,

    @OneToMany(mappedBy = "productMaster", cascade = [CascadeType.ALL])
    val variantAttributes: MutableSet<ProductVariantAttribute> = mutableSetOf(),

    @OneToMany(mappedBy = "productMaster", cascade = [CascadeType.ALL])
    val variants: MutableSet<ProductVariant> = mutableSetOf(),

    // For bundles
    @OneToMany(mappedBy = "bundleProduct", cascade = [CascadeType.ALL])
    val bundleComponents: MutableSet<BundleComponent> = mutableSetOf(),

    // For kits
    @OneToMany(mappedBy = "kitProduct", cascade = [CascadeType.ALL])
    val kitComponents: MutableSet<KitComponent> = mutableSetOf(),

    // Pricing
    @Embedded
    var pricing: ProductPricing,

    // Inventory linking
    val linkedMaterialId: UUID?, // Links to Material entity for inventory

    @Enumerated(EnumType.STRING)
    var status: ProductStatus,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
) {
    fun addVariantAttribute(attribute: ProductVariantAttribute) {
        require(variantStrategy == VariantStrategy.MATRIX || variantStrategy == VariantStrategy.CONFIGURABLE) {
            "Product must support variants"
        }
        variantAttributes.add(attribute)
        attribute.productMaster = this
        updatedAt = Instant.now()
    }

    fun createVariant(
        variantValues: Map<String, String>,
        materialId: UUID,
        sku: String
    ): ProductVariant {
        require(variantStrategy == VariantStrategy.MATRIX) {
            "Product must use matrix variant strategy"
        }

        val variant = ProductVariant(
            productMaster = this,
            sku = sku,
            materialId = materialId,
            variantValues = variantValues
        )
        variants.add(variant)
        updatedAt = Instant.now()
        return variant
    }

    fun addBundleComponent(materialId: UUID, quantity: BigDecimal, isOptional: Boolean = false) {
        require(productType == ProductType.BUNDLE) {
            "Product must be a bundle"
        }

        val component = BundleComponent(
            bundleProduct = this,
            materialId = materialId,
            quantity = quantity,
            isOptional = isOptional
        )
        bundleComponents.add(component)
        updatedAt = Instant.now()
    }

    fun addKitComponent(materialId: UUID, quantity: BigDecimal, sequence: Int) {
        require(productType == ProductType.KIT) {
            "Product must be a kit"
        }

        val component = KitComponent(
            kitProduct = this,
            materialId = materialId,
            quantity = quantity,
            assemblySequence = sequence
        )
        kitComponents.add(component)
        updatedAt = Instant.now()
    }

    fun calculateBundlePrice(discountPercent: BigDecimal = BigDecimal.ZERO): BigDecimal {
        // Bundle price can be sum of components or custom price
        return pricing.basePrice
    }
}

enum class ProductType {
    SIMPLE,              // Single SKU, no variants
    VARIANT_MASTER,      // Master product with variants
    BUNDLE,              // Bundle of multiple products sold together
    KIT,                 // Kit that requires assembly
    CONFIGURABLE,        // Configurable product (customer-specific)
    SERVICE,             // Service product
    DIGITAL,             // Digital product (download, license)
    SUBSCRIPTION         // Subscription product
}

enum class VariantStrategy {
    NONE,                // No variants
    MATRIX,              // Matrix of attributes (Color x Size)
    CONFIGURABLE,        // Customer configurable
    CUSTOM               // Custom variants
}

enum class ProductStatus {
    DRAFT, ACTIVE, INACTIVE, DISCONTINUED
}

@Embeddable
data class ProductPricing(
    @Column(precision = 19, scale = 2)
    val basePrice: BigDecimal,

    @Column(precision = 19, scale = 2)
    val salePrice: BigDecimal? = null,

    val currency: String = "USD",

    @Column(precision = 19, scale = 2)
    val costPrice: BigDecimal? = null,

    @Column(precision = 19, scale = 2)
    val msrp: BigDecimal? = null, // Manufacturer's suggested retail price

    val taxIncluded: Boolean = false,

    val taxCategory: String? = null
)
```

**ProductVariantAttribute (Entity)**

```kotlin
@Entity
@Table(
    name = "product_variant_attributes",
    schema = "supply_schema",
    uniqueConstraints = [
        UniqueConstraint(
            name = "uk_product_attr",
            columnNames = ["productMasterId", "attributeName"]
        )
    ]
)
class ProductVariantAttribute(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "product_master_id", nullable = false)
    var productMaster: ProductMaster,

    @Column(nullable = false)
    val attributeName: String, // e.g., "Color", "Size", "Style"

    @Column(nullable = false)
    val displayName: String,

    @ElementCollection
    @CollectionTable(
        name = "product_variant_attribute_values",
        schema = "supply_schema",
        joinColumns = [JoinColumn(name = "attribute_id")]
    )
    @Column(name = "value")
    val possibleValues: MutableList<String> = mutableListOf(), // ["Red", "Blue", "Green"]

    val sortOrder: Int = 0,

    val required: Boolean = true
)
```

**ProductVariant (Entity)**

```kotlin
@Entity
@Table(
    name = "product_variants",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_variant_sku", columnList = "sku"),
        Index(name = "idx_variant_material", columnList = "materialId")
    ],
    uniqueConstraints = [
        UniqueConstraint(name = "uk_variant_sku", columnNames = ["sku"])
    ]
)
class ProductVariant(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "product_master_id", nullable = false)
    var productMaster: ProductMaster,

    @Column(nullable = false, unique = true)
    val sku: String, // Variant SKU (e.g., SHIRT-RED-L)

    // Link to Material for inventory management
    @Column(nullable = false)
    val materialId: UUID,

    // Variant attribute values (Color: Red, Size: L)
    @ElementCollection
    @CollectionTable(
        name = "product_variant_values",
        schema = "supply_schema",
        joinColumns = [JoinColumn(name = "variant_id")]
    )
    @MapKeyColumn(name = "attribute_name")
    @Column(name = "value")
    val variantValues: MutableMap<String, String> = mutableMapOf(),

    // Optional variant-specific pricing
    @Embedded
    var variantPricing: ProductPricing? = null,

    // Images specific to this variant
    @ElementCollection
    @CollectionTable(
        name = "product_variant_images",
        schema = "supply_schema",
        joinColumns = [JoinColumn(name = "variant_id")]
    )
    @Column(name = "image_url")
    val images: MutableList<String> = mutableListOf(),

    @Enumerated(EnumType.STRING)
    var status: ProductStatus = ProductStatus.ACTIVE,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now()
) {
    fun getDisplayName(): String {
        val values = variantValues.values.joinToString(" / ")
        return "${productMaster.name} - $values"
    }

    fun getPrice(): BigDecimal {
        return variantPricing?.basePrice ?: productMaster.pricing.basePrice
    }
}
```

**BundleComponent (Entity)**

```kotlin
@Entity
@Table(
    name = "bundle_components",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_bundle_product", columnList = "bundleProductId")
    ]
)
class BundleComponent(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "bundle_product_id", nullable = false)
    var bundleProduct: ProductMaster,

    // Component can be Material or another Product
    @Column(nullable = false)
    val materialId: UUID,

    @Column(nullable = false, precision = 19, scale = 4)
    val quantity: BigDecimal,

    val unitOfMeasure: String = "EA",

    // Is this component optional?
    @Column(nullable = false)
    val isOptional: Boolean = false,

    // Can customer select from alternatives?
    @Column(nullable = false)
    val allowSubstitution: Boolean = false,

    @ElementCollection
    @CollectionTable(
        name = "bundle_component_alternatives",
        schema = "supply_schema",
        joinColumns = [JoinColumn(name = "component_id")]
    )
    @Column(name = "alternative_material_id")
    val alternatives: MutableList<UUID> = mutableListOf(),

    // Discount for this component within bundle
    @Column(precision = 5, scale = 2)
    val discountPercent: BigDecimal = BigDecimal.ZERO,

    val sortOrder: Int = 0,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now()
) {
    fun isSubstitutable(): Boolean {
        return allowSubstitution && alternatives.isNotEmpty()
    }
}
```

**KitComponent (Entity)**

```kotlin
@Entity
@Table(
    name = "kit_components",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_kit_product", columnList = "kitProductId")
    ]
)
class KitComponent(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "kit_product_id", nullable = false)
    var kitProduct: ProductMaster,

    @Column(nullable = false)
    val materialId: UUID,

    @Column(nullable = false, precision = 19, scale = 4)
    val quantity: BigDecimal,

    val unitOfMeasure: String = "EA",

    // Assembly sequence
    @Column(nullable = false)
    val assemblySequence: Int,

    // Assembly instructions
    @Lob
    val assemblyInstructions: String? = null,

    // Time to assemble (minutes)
    val assemblyTimeMinutes: Int? = null,

    // Scrap/waste percentage
    @Column(precision = 5, scale = 2)
    val scrapPercent: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now()
)
```

**ConfigurableProduct (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "configurable_products",
    schema = "supply_schema"
)
class ConfigurableProduct(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "product_master_id", nullable = false)
    val productMaster: ProductMaster,

    @Column(nullable = false)
    val configurationTemplateId: UUID,

    // Configuration rules (stored as JSON)
    @Column(columnDefinition = "jsonb")
    val configurationRules: String,

    // Pricing rules for configurations
    @Column(columnDefinition = "jsonb")
    val pricingRules: String,

    @OneToMany(mappedBy = "configurableProduct", cascade = [CascadeType.ALL])
    val configurationOptions: MutableSet<ConfigurationOption> = mutableSetOf(),

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
)
```

**ConfigurationOption (Entity)**

```kotlin
@Entity
@Table(
    name = "configuration_options",
    schema = "supply_schema"
)
class ConfigurationOption(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "configurable_product_id", nullable = false)
    var configurableProduct: ConfigurableProduct,

    @Column(nullable = false)
    val optionName: String, // e.g., "Processor", "Memory", "Storage"

    @Column(nullable = false)
    val optionType: String, // e.g., "SINGLE_SELECT", "MULTI_SELECT", "TEXT_INPUT"

    @ElementCollection
    @CollectionTable(
        name = "configuration_option_values",
        schema = "supply_schema",
        joinColumns = [JoinColumn(name = "option_id")]
    )
    @Column(name = "value")
    val possibleValues: MutableList<String> = mutableListOf(),

    // Price impact for each value
    @ElementCollection
    @CollectionTable(
        name = "configuration_option_pricing",
        schema = "supply_schema",
        joinColumns = [JoinColumn(name = "option_id")]
    )
    @MapKeyColumn(name = "value")
    @Column(name = "price_impact", precision = 19, scale = 2)
    val pricingImpact: MutableMap<String, BigDecimal> = mutableMapOf(),

    val required: Boolean = true,

    val sortOrder: Int = 0
)
```

### Domain Services

**VariantGenerationService**

```kotlin
class VariantGenerationService {
    /**
     * Generate all possible variants from attributes
     * Example: Color [Red, Blue] x Size [S, M, L] = 6 variants
     */
    fun generateVariantMatrix(
        productMaster: ProductMaster,
        materialFactory: (attributeValues: Map<String, String>) -> UUID
    ): List<ProductVariant> {
        val attributes = productMaster.variantAttributes.sortedBy { it.sortOrder }
        val combinations = generateCombinations(
            attributes.associate { it.attributeName to it.possibleValues }
        )

        return combinations.map { combination ->
            val sku = generateSku(productMaster.productMasterNumber, combination)
            val materialId = materialFactory(combination)

            ProductVariant(
                productMaster = productMaster,
                sku = sku,
                materialId = materialId,
                variantValues = combination.toMutableMap()
            )
        }
    }

    private fun generateCombinations(
        attributes: Map<String, List<String>>
    ): List<Map<String, String>> {
        if (attributes.isEmpty()) return listOf(emptyMap())

        val (key, values) = attributes.entries.first()
        val rest = attributes.minus(key)
        val restCombinations = generateCombinations(rest)

        return values.flatMap { value ->
            restCombinations.map { combo ->
                combo + (key to value)
            }
        }
    }

    private fun generateSku(baseNumber: String, attributes: Map<String, String>): String {
        val suffix = attributes.values.joinToString("-") { it.take(3).uppercase() }
        return "$baseNumber-$suffix"
    }
}
```

**BundlePricingService**

```kotlin
class BundlePricingService {
    /**
     * Calculate bundle price with component discounts
     */
    fun calculateBundlePrice(
        bundle: ProductMaster,
        componentPrices: Map<UUID, BigDecimal>
    ): BigDecimal {
        require(bundle.productType == ProductType.BUNDLE) {
            "Product must be a bundle"
        }

        val totalComponentPrice = bundle.bundleComponents
            .filter { !it.isOptional } // Only required components
            .sumOf { component ->
                val basePrice = componentPrices[component.materialId] ?: BigDecimal.ZERO
                val discountedPrice = basePrice * (BigDecimal.ONE - component.discountPercent / BigDecimal(100))
                discountedPrice * component.quantity
            }

        // Bundle can override with custom price or use calculated price
        return bundle.pricing.basePrice.takeIf { it > BigDecimal.ZERO } ?: totalComponentPrice
    }

    /**
     * Calculate price with selected optional components
     */
    fun calculateBundlePriceWithOptions(
        bundle: ProductMaster,
        componentPrices: Map<UUID, BigDecimal>,
        selectedOptionalComponents: Set<UUID>
    ): BigDecimal {
        val basePrice = calculateBundlePrice(bundle, componentPrices)

        val optionalPrice = bundle.bundleComponents
            .filter { it.isOptional && selectedOptionalComponents.contains(it.materialId) }
            .sumOf { component ->
                val basePrice = componentPrices[component.materialId] ?: BigDecimal.ZERO
                val discountedPrice = basePrice * (BigDecimal.ONE - component.discountPercent / BigDecimal(100))
                discountedPrice * component.quantity
            }

        return basePrice + optionalPrice
    }
}
```

**KitAssemblyService**

```kotlin
class KitAssemblyService {
    /**
     * Validate kit components availability
     */
    fun validateKitComponentsAvailable(
        kit: ProductMaster,
        componentStock: Map<UUID, BigDecimal>
    ): KitValidationResult {
        require(kit.productType == ProductType.KIT) {
            "Product must be a kit"
        }

        val missingComponents = mutableListOf<KitComponent>()
        val insufficientComponents = mutableListOf<Pair<KitComponent, BigDecimal>>()

        kit.kitComponents.forEach { component ->
            val availableQty = componentStock[component.materialId] ?: BigDecimal.ZERO
            val requiredQty = component.quantity * (BigDecimal.ONE + component.scrapPercent / BigDecimal(100))

            when {
                availableQty == BigDecimal.ZERO -> missingComponents.add(component)
                availableQty < requiredQty -> insufficientComponents.add(component to availableQty)
            }
        }

        return KitValidationResult(
            canAssemble = missingComponents.isEmpty() && insufficientComponents.isEmpty(),
            missingComponents = missingComponents,
            insufficientComponents = insufficientComponents
        )
    }

    /**
     * Calculate total assembly time
     */
    fun calculateAssemblyTime(kit: ProductMaster): Int {
        return kit.kitComponents.sumOf { it.assemblyTimeMinutes ?: 0 }
    }

    /**
     * Get assembly sequence
     */
    fun getAssemblySequence(kit: ProductMaster): List<KitComponent> {
        return kit.kitComponents.sortedBy { it.assemblySequence }
    }
}

data class KitValidationResult(
    val canAssemble: Boolean,
    val missingComponents: List<KitComponent>,
    val insufficientComponents: List<Pair<KitComponent, BigDecimal>>
)
```

### Domain Events

```kotlin
// Variant Events
data class ProductVariantCreatedEvent(
    val variantId: UUID,
    val productMasterId: UUID,
    val sku: String,
    val variantValues: Map<String, String>,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
) : DomainEvent

// Bundle Events
data class BundleComponentAddedEvent(
    val bundleId: UUID,
    val componentMaterialId: UUID,
    val quantity: BigDecimal,
    val isOptional: Boolean,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
) : DomainEvent

// Kit Events
data class KitAssemblyStartedEvent(
    val kitId: UUID,
    val productMasterId: UUID,
    val assemblyOrderId: UUID,
    val components: List<UUID>,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
) : DomainEvent

data class KitAssemblyCompletedEvent(
    val kitId: UUID,
    val assemblyOrderId: UUID,
    val materialId: UUID,
    val quantityAssembled: BigDecimal,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
) : DomainEvent
```

---

## Domain 1B: Advanced Tracking & Identification

### Overview

Comprehensive tracking and identification system supporting:

-   **Batch Management** (expiry, manufacturing date, lot tracking)
-   **Serial Number Tracking** (individual item tracking)
-   **Barcode/QR Code** support
-   **RFID Tracking** capability
-   **Traceability** (forward and backward tracing)

### Aggregates

**Batch (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "batches",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_batch_number", columnList = "batchNumber"),
        Index(name = "idx_batch_material", columnList = "materialId"),
        Index(name = "idx_batch_expiry", columnList = "expiryDate"),
        Index(name = "idx_batch_vendor", columnList = "vendorBatchNumber")
    ],
    uniqueConstraints = [
        UniqueConstraint(name = "uk_batch_number", columnNames = ["batchNumber"])
    ]
)
class Batch(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val batchNumber: String, // BATCH-YYYYMMDD-NNNN

    @ManyToOne
    @JoinColumn(name = "material_id", nullable = false)
    val material: Material,

    // Manufacturing information
    @Column(nullable = false)
    val manufacturingDate: LocalDate,

    val vendorBatchNumber: String? = null, // Vendor's batch number

    val vendorId: UUID? = null,

    // Expiry information
    val expiryDate: LocalDate? = null,

    val shelfLifeDays: Int? = null,

    val bestBeforeDate: LocalDate? = null,

    // Status
    @Enumerated(EnumType.STRING)
    var status: BatchStatus = BatchStatus.UNRESTRICTED,

    // Quality
    @Enumerated(EnumType.STRING)
    var qualityStatus: QualityStatus? = null,

    val qualityInspectionId: UUID? = null,

    // Certificate of Analysis
    val coaDocumentUrl: String? = null,

    // Characteristics (store as JSON for flexibility)
    @Column(columnDefinition = "jsonb")
    val batchCharacteristics: String? = null,

    // Stock tracking
    @Column(precision = 19, scale = 4)
    var totalQuantityProduced: BigDecimal = BigDecimal.ZERO,

    @Column(precision = 19, scale = 4)
    var availableQuantity: BigDecimal = BigDecimal.ZERO,

    // Traceability
    @ElementCollection
    @CollectionTable(
        name = "batch_source_batches",
        schema = "supply_schema",
        joinColumns = [JoinColumn(name = "batch_id")]
    )
    @Column(name = "source_batch_id")
    val sourceBatches: MutableList<UUID> = mutableListOf(), // For traceability

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
) {
    fun isExpired(): Boolean {
        return expiryDate?.isBefore(LocalDate.now()) ?: false
    }

    fun daysUntilExpiry(): Long? {
        return expiryDate?.let { ChronoUnit.DAYS.between(LocalDate.now(), it) }
    }

    fun block(reason: String) {
        this.status = BatchStatus.BLOCKED
        this.updatedAt = Instant.now()
    }

    fun release() {
        require(status == BatchStatus.BLOCKED || status == BatchStatus.QUALITY_INSPECTION) {
            "Can only release blocked or inspecting batches"
        }
        this.status = BatchStatus.UNRESTRICTED
        this.qualityStatus = QualityStatus.APPROVED
        this.updatedAt = Instant.now()
    }
}

enum class BatchStatus {
    UNRESTRICTED,        // Available for use
    BLOCKED,             // Blocked from use
    QUALITY_INSPECTION,  // Under quality inspection
    RESTRICTED,          // Restricted use only
    EXPIRED              // Past expiry date
}

enum class QualityStatus {
    PENDING, APPROVED, REJECTED, CONDITIONALLY_APPROVED
}
```

**SerialNumber (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "serial_numbers",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_serial_number", columnList = "serialNumber"),
        Index(name = "idx_serial_material", columnList = "materialId"),
        Index(name = "idx_serial_status", columnList = "status")
    ],
    uniqueConstraints = [
        UniqueConstraint(name = "uk_serial_number", columnNames = ["serialNumber"])
    ]
)
class SerialNumber(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val serialNumber: String,

    @ManyToOne
    @JoinColumn(name = "material_id", nullable = false)
    val material: Material,

    @ManyToOne
    @JoinColumn(name = "batch_id")
    val batch: Batch? = null,

    // Manufacturing details
    val manufacturingDate: LocalDate? = null,

    val warrantyStartDate: LocalDate? = null,

    val warrantyEndDate: LocalDate? = null,

    val warrantyMonths: Int? = null,

    // Current location
    @ManyToOne
    @JoinColumn(name = "current_location_id")
    var currentLocation: StorageLocation? = null,

    // Ownership
    var currentOwnerId: UUID? = null, // Customer, warehouse, etc.

    @Enumerated(EnumType.STRING)
    var ownershipType: OwnershipType = OwnershipType.COMPANY_OWNED,

    // Status
    @Enumerated(EnumType.STRING)
    var status: SerialNumberStatus = SerialNumberStatus.IN_STOCK,

    // Lifecycle tracking
    @OneToMany(mappedBy = "serialNumber", cascade = [CascadeType.ALL])
    val movementHistory: MutableList<SerialNumberMovement> = mutableListOf(),

    // Service history
    @ElementCollection
    @CollectionTable(
        name = "serial_number_service_history",
        schema = "supply_schema",
        joinColumns = [JoinColumn(name = "serial_number_id")]
    )
    @Column(name = "service_record_id")
    val serviceHistory: MutableList<UUID> = mutableListOf(),

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
) {
    fun recordMovement(
        fromLocation: StorageLocation?,
        toLocation: StorageLocation,
        movementType: SerialMovementType,
        documentId: UUID
    ) {
        val movement = SerialNumberMovement(
            serialNumber = this,
            fromLocation = fromLocation,
            toLocation = toLocation,
            movementType = movementType,
            documentId = documentId,
            movedAt = Instant.now()
        )
        movementHistory.add(movement)
        this.currentLocation = toLocation
        this.updatedAt = Instant.now()
    }

    fun sell(customerId: UUID) {
        this.status = SerialNumberStatus.SOLD
        this.currentOwnerId = customerId
        this.ownershipType = OwnershipType.CUSTOMER_OWNED
        this.updatedAt = Instant.now()
    }

    fun isUnderWarranty(): Boolean {
        return warrantyEndDate?.isAfter(LocalDate.now()) ?: false
    }
}

enum class SerialNumberStatus {
    IN_STOCK, RESERVED, IN_TRANSIT, SOLD,
    IN_SERVICE, RETURNED, SCRAPPED, LOST
}

enum class OwnershipType {
    COMPANY_OWNED, CUSTOMER_OWNED, CONSIGNMENT, RENTAL
}

enum class SerialMovementType {
    GOODS_RECEIPT, GOODS_ISSUE, TRANSFER,
    RETURN, SERVICE, SCRAP
}
```

**SerialNumberMovement (Entity)**

```kotlin
@Entity
@Table(
    name = "serial_number_movements",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_serial_movement_date", columnList = "movedAt")
    ]
)
class SerialNumberMovement(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "serial_number_id", nullable = false)
    val serialNumber: SerialNumber,

    @ManyToOne
    @JoinColumn(name = "from_location_id")
    val fromLocation: StorageLocation?,

    @ManyToOne
    @JoinColumn(name = "to_location_id", nullable = false)
    val toLocation: StorageLocation,

    @Enumerated(EnumType.STRING)
    val movementType: SerialMovementType,

    val documentId: UUID,

    val movedBy: UUID,

    @Column(nullable = false)
    val movedAt: Instant
)
```

**Barcode (Value Object / Entity)**

```kotlin
@Entity
@Table(
    name = "barcodes",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_barcode_value", columnList = "barcodeValue"),
        Index(name = "idx_barcode_material", columnList = "materialId")
    ],
    uniqueConstraints = [
        UniqueConstraint(name = "uk_barcode_value", columnNames = ["barcodeValue"])
    ]
)
class Barcode(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val barcodeValue: String,

    @Enumerated(EnumType.STRING)
    val barcodeType: BarcodeType,

    // What this barcode identifies
    @Enumerated(EnumType.STRING)
    val entityType: BarcodeEntityType,

    // Material/Product
    val materialId: UUID? = null,
    val productVariantId: UUID? = null,

    // Batch/Serial
    val batchNumber: String? = null,
    val serialNumber: String? = null,

    // Package/Pallet
    val packageId: UUID? = null,

    // Unit of measure
    val unitOfMeasure: String? = null,

    @Column(precision = 19, scale = 4)
    val quantity: BigDecimal? = null,

    @Column(nullable = false)
    val isActive: Boolean = true,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now()
)

enum class BarcodeType {
    EAN13, EAN8, UPC_A, UPC_E, CODE128,
    CODE39, QR_CODE, DATA_MATRIX, ITF14
}

enum class BarcodeEntityType {
    MATERIAL, PRODUCT_VARIANT, BATCH, SERIAL_NUMBER,
    PACKAGE, PALLET, STORAGE_LOCATION
}
```

---

## Domain 1C: Advanced Warehousing & Multi-Location

### Overview

Enterprise-grade warehousing with:

-   **Multi-warehouse** support
-   **Multi-location** inventory tracking
-   **Bin location** management
-   **Zone-based** storage
-   **Put-away and picking** strategies
-   **Cross-docking** support
-   **Cycle counting** capability

### Aggregates

**BinLocation (Entity)**

```kotlin
@Entity
@Table(
    name = "bin_locations",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_bin_code", columnList = "binCode"),
        Index(name = "idx_bin_zone", columnList = "zoneId"),
        Index(name = "idx_bin_aisle", columnList = "aisle, rack, level, position")
    ],
    uniqueConstraints = [
        UniqueConstraint(
            name = "uk_bin_location",
            columnNames = ["storageLocationId", "binCode"]
        )
    ]
)
class BinLocation(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "storage_location_id", nullable = false)
    val storageLocation: StorageLocation,

    @ManyToOne
    @JoinColumn(name = "zone_id")
    val zone: WarehouseZone? = null,

    @Column(nullable = false)
    val binCode: String, // e.g., A-01-02-03

    // Physical location
    val aisle: String? = null,
    val rack: String? = null,
    val level: Int? = null,
    val position: Int? = null,

    // Dimensions
    @Column(precision = 19, scale = 4)
    val length: BigDecimal? = null,

    @Column(precision = 19, scale = 4)
    val width: BigDecimal? = null,

    @Column(precision = 19, scale = 4)
    val height: BigDecimal? = null,

    val dimensionUnit: String = "CM",

    // Capacity
    @Column(precision = 19, scale = 4)
    val maxWeight: BigDecimal? = null,

    val weightUnit: String = "KG",

    @Column(precision = 19, scale = 4)
    val maxVolume: BigDecimal? = null,

    val volumeUnit: String = "M3",

    // Storage type
    @Enumerated(EnumType.STRING)
    val storageType: StorageType,

    // Environmental conditions
    val temperatureControlled: Boolean = false,

    @Column(precision = 5, scale = 2)
    val minTemperature: BigDecimal? = null,

    @Column(precision = 5, scale = 2)
    val maxTemperature: BigDecimal? = null,

    // Picking
    @Enumerated(EnumType.STRING)
    val pickingPriority: PickingPriority = PickingPriority.NORMAL,

    // Status
    @Enumerated(EnumType.STRING)
    var status: BinLocationStatus = BinLocationStatus.AVAILABLE,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now()
)

enum class StorageType {
    FLOOR, RACK, SHELF, PALLET, DRAWER,
    BULK, PICKING, RESERVE, OVERFLOW
}

enum class PickingPriority {
    HIGH, NORMAL, LOW
}

enum class BinLocationStatus {
    AVAILABLE, OCCUPIED, FULL, BLOCKED, UNDER_MAINTENANCE
}
```

**WarehouseZone (Entity)**

```kotlin
@Entity
@Table(
    name = "warehouse_zones",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_zone_warehouse", columnList = "warehouseId"),
        Index(name = "idx_zone_type", columnList = "zoneType")
    ]
)
class WarehouseZone(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "warehouse_id", nullable = false)
    val warehouse: Warehouse,

    @Column(nullable = false)
    val zoneCode: String,

    @Column(nullable = false)
    var name: String,

    @Enumerated(EnumType.STRING)
    val zoneType: ZoneType,

    @Lob
    var description: String? = null,

    // Environmental requirements
    val temperatureControlled: Boolean = false,
    val humidityControlled: Boolean = false,

    // Access control
    val restrictedAccess: Boolean = false,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now()
)

enum class ZoneType {
    RECEIVING, PUTAWAY, STORAGE, PICKING,
    PACKING, SHIPPING, QUARANTINE, RETURNS,
    CROSSDOCK, HAZMAT, COLD_STORAGE
}
```

**StockByBin (View/Aggregate)**

```kotlin
@Entity
@Table(
    name = "stock_by_bin",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_stock_bin_material", columnList = "materialId"),
        Index(name = "idx_stock_bin_location", columnList = "binLocationId")
    ]
)
class StockByBin(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "material_id", nullable = false)
    val material: Material,

    @ManyToOne
    @JoinColumn(name = "bin_location_id", nullable = false)
    val binLocation: BinLocation,

    val batchNumber: String? = null,

    @Column(nullable = false, precision = 19, scale = 4)
    var quantity: BigDecimal = BigDecimal.ZERO,

    val unitOfMeasure: String,

    @Enumerated(EnumType.STRING)
    var stockStatus: StockStatus = StockStatus.AVAILABLE,

    var lastMovementDate: Instant? = null,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
)

enum class StockStatus {
    AVAILABLE, RESERVED, BLOCKED, QUALITY_INSPECTION, DAMAGED
}
```

**PutAwayStrategy (Configuration)**

```kotlin
@Entity
@Table(name = "putaway_strategies", schema = "supply_schema")
class PutAwayStrategy(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false)
    val name: String,

    @Enumerated(EnumType.STRING)
    val strategyType: PutAwayStrategyType,

    @Lob
    val description: String? = null,

    // Rules (stored as JSON for flexibility)
    @Column(columnDefinition = "jsonb")
    val rules: String,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val isActive: Boolean = true
)

enum class PutAwayStrategyType {
    FIFO,                    // First in, first out
    LIFO,                    // Last in, first out
    FEFO,                    // First expired, first out
    NEAREST_LOCATION,        // Nearest available location
    FIXED_BIN,              // Fixed bin per material
    BULK_STORAGE,           // Bulk storage areas
    ZONE_BASED,             // Based on zone assignment
    ABC_CLASSIFICATION      // Based on ABC analysis
}
```

**PickingStrategy (Configuration)**

```kotlin
@Entity
@Table(name = "picking_strategies", schema = "supply_schema")
class PickingStrategy(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false)
    val name: String,

    @Enumerated(EnumType.STRING)
    val strategyType: PickingStrategyType,

    // Rules (stored as JSON)
    @Column(columnDefinition = "jsonb")
    val rules: String,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val isActive: Boolean = true
)

enum class PickingStrategyType {
    FIFO,                    // First in, first out
    FEFO,                    // First expired, first out
    NEAREST_BIN,            // Nearest bin to picker
    BATCH_PICKING,          // Pick multiple orders at once
    WAVE_PICKING,           // Pick in waves
    ZONE_PICKING,           // Pick by zone
    CLUSTER_PICKING         // Pick to multiple orders
}
```

**CycleCount (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "cycle_counts",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_cycle_count_date", columnList = "countDate"),
        Index(name = "idx_cycle_count_status", columnList = "status")
    ]
)
class CycleCount(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val countNumber: String,

    @Column(nullable = false)
    val countDate: LocalDate,

    @ManyToOne
    @JoinColumn(name = "storage_location_id", nullable = false)
    val storageLocation: StorageLocation,

    @ManyToOne
    @JoinColumn(name = "zone_id")
    val zone: WarehouseZone? = null,

    @Enumerated(EnumType.STRING)
    val countType: CycleCountType,

    @OneToMany(mappedBy = "cycleCount", cascade = [CascadeType.ALL])
    val items: MutableList<CycleCountItem> = mutableListOf(),

    @Enumerated(EnumType.STRING)
    var status: CycleCountStatus = CycleCountStatus.PLANNED,

    val countedBy: UUID? = null,

    var countStartTime: Instant? = null,

    var countEndTime: Instant? = null,

    val approvedBy: UUID? = null,

    var approvedAt: Instant? = null,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
)

enum class CycleCountType {
    FULL_COUNT,              // Count all items
    ABC_COUNT,               // Count by ABC classification
    ZONE_COUNT,              // Count specific zone
    SPOT_COUNT,              // Random spot check
    LOW_STOCK_COUNT          // Count low stock items
}

enum class CycleCountStatus {
    PLANNED, IN_PROGRESS, COUNTED, VARIANCE_REVIEW, APPROVED, POSTED
}
```

**CycleCountItem (Entity)**

```kotlin
@Entity
@Table(name = "cycle_count_items", schema = "supply_schema")
class CycleCountItem(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "cycle_count_id", nullable = false)
    val cycleCount: CycleCount,

    @ManyToOne
    @JoinColumn(name = "material_id", nullable = false)
    val material: Material,

    @ManyToOne
    @JoinColumn(name = "bin_location_id")
    val binLocation: BinLocation? = null,

    val batchNumber: String? = null,

    @Column(precision = 19, scale = 4)
    val systemQuantity: BigDecimal,

    @Column(precision = 19, scale = 4)
    var countedQuantity: BigDecimal? = null,

    @Column(precision = 19, scale = 4)
    var variance: BigDecimal? = null,

    @Column(length = 1000)
    var varianceReason: String? = null,

    @Enumerated(EnumType.STRING)
    var status: CountItemStatus = CountItemStatus.NOT_COUNTED
)

enum class CountItemStatus {
    NOT_COUNTED, COUNTED, VARIANCE, ACCEPTED, REJECTED
}
```

---

## Domain 3: Supplier & Procurement Management (Enhanced)

### Aggregates

**Vendor (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "vendors",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_vendor_number", columnList = "vendorNumber"),
        Index(name = "idx_vendor_status", columnList = "status")
    ]
)
class Vendor(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val vendorNumber: String, // VEN-NNNNNNNN

    @Column(nullable = false)
    var name: String,

    @Embedded
    var contactInfo: VendorContactInfo,

    @Enumerated(EnumType.STRING)
    var vendorType: VendorType,

    @Enumerated(EnumType.STRING)
    var status: VendorStatus = VendorStatus.ACTIVE,

    // Payment terms
    @Embedded
    var paymentTerms: VendorPaymentTerms,

    // Performance metrics
    @Embedded
    var performanceMetrics: VendorPerformance,

    // Certifications
    @ElementCollection
    @CollectionTable(
        name = "vendor_certifications",
        schema = "supply_schema",
        joinColumns = [JoinColumn(name = "vendor_id")]
    )
    val certifications: MutableList<VendorCertification> = mutableListOf(),

    // Approved materials
    @OneToMany(mappedBy = "vendor", cascade = [CascadeType.ALL])
    val approvedMaterials: MutableSet<VendorMaterialMapping> = mutableSetOf(),

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
)

enum class VendorType {
    MANUFACTURER, DISTRIBUTOR, WHOLESALER, RETAILER, SERVICE_PROVIDER
}

enum class VendorStatus {
    ACTIVE, INACTIVE, SUSPENDED, BLACKLISTED, UNDER_REVIEW
}

@Embeddable
data class VendorContactInfo(
    val email: String,
    val phone: String? = null,
    @Embedded
    @AttributeOverrides(
        AttributeOverride(name = "street", column = Column(name = "vendor_street")),
        AttributeOverride(name = "street2", column = Column(name = "vendor_street2")),
        AttributeOverride(name = "city", column = Column(name = "vendor_city")),
        AttributeOverride(name = "state", column = Column(name = "vendor_state")),
        AttributeOverride(name = "postalCode", column = Column(name = "vendor_postal_code")),
        AttributeOverride(name = "country", column = Column(name = "vendor_country"))
    )
    val address: Address,
    val website: String? = null,
    val primaryContactName: String? = null,
    val primaryContactEmail: String? = null,
    val primaryContactPhone: String? = null
)

@Embeddable
data class VendorPaymentTerms(
    val paymentTermsDays: Int = 30,
    val earlyPaymentDiscountPercent: BigDecimal? = null,
    val earlyPaymentDays: Int? = null,
    val currency: String = "USD",
    val creditLimit: BigDecimal? = null
)

@Embeddable
data class VendorPerformance(
    @Column(precision = 5, scale = 2)
    var onTimeDeliveryRate: BigDecimal = BigDecimal.ZERO, // Percentage

    @Column(precision = 5, scale = 2)
    var qualityRating: BigDecimal = BigDecimal.ZERO, // 0-100

    @Column(precision = 5, scale = 2)
    var priceCompetitiveness: BigDecimal = BigDecimal.ZERO, // 0-100

    var totalOrdersPlaced: Int = 0,
    var totalOrdersFulfilled: Int = 0,
    var totalReturns: Int = 0,

    var lastEvaluationDate: LocalDate? = null
)

@Embeddable
data class VendorCertification(
    val certificationType: String,
    val certificationNumber: String,
    val issuedBy: String,
    val issuedDate: LocalDate,
    val expiryDate: LocalDate?
)
```

**VendorMaterialMapping (Entity)**

```kotlin
@Entity
@Table(
    name = "vendor_material_mappings",
    schema = "supply_schema",
    uniqueConstraints = [
        UniqueConstraint(
            name = "uk_vendor_material",
            columnNames = ["vendorId", "materialId"]
        )
    ]
)
class VendorMaterialMapping(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "vendor_id", nullable = false)
    val vendor: Vendor,

    @ManyToOne
    @JoinColumn(name = "material_id", nullable = false)
    val material: Material,

    val vendorMaterialNumber: String,

    @Column(precision = 19, scale = 4)
    var lastPurchasePrice: BigDecimal,

    val currency: String = "USD",

    val leadTimeDays: Int,

    @Column(precision = 19, scale = 4)
    val minimumOrderQuantity: BigDecimal? = null,

    @Column(precision = 19, scale = 4)
    val orderMultiple: BigDecimal? = null,

    @Column(nullable = false)
    val isPreferredVendor: Boolean = false,

    @Column(nullable = false)
    val isActive: Boolean = true,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now()
)
```

**PurchaseRequisition (Aggregate Root with Approval)**

```kotlin
@Entity
@Table(
    name = "purchase_requisitions",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_pr_number", columnList = "requisitionNumber"),
        Index(name = "idx_pr_status", columnList = "status"),
        Index(name = "idx_pr_requester", columnList = "requesterId")
    ]
)
class PurchaseRequisition(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val requisitionNumber: String, // PR-YYYY-NNNNNN

    @Column(nullable = false)
    val requisitionDate: LocalDate,

    @Column(nullable = false)
    val requesterId: UUID,

    val costCenterId: UUID? = null,

    @Enumerated(EnumType.STRING)
    val requisitionType: RequisitionType,

    @Enumerated(EnumType.STRING)
    val priority: Priority,

    @OneToMany(mappedBy = "purchaseRequisition", cascade = [CascadeType.ALL])
    val items: MutableList<PurchaseRequisitionItem> = mutableListOf(),

    @Column(precision = 19, scale = 2)
    var totalAmount: BigDecimal = BigDecimal.ZERO,

    val currency: String = "USD",

    @Enumerated(EnumType.STRING)
    var status: RequisitionStatus = RequisitionStatus.DRAFT,

    // Approval workflow
    @OneToMany(mappedBy = "purchaseRequisition", cascade = [CascadeType.ALL])
    val approvals: MutableList<RequisitionApproval> = mutableListOf(),

    var submittedAt: Instant? = null,

    var approvedAt: Instant? = null,

    var rejectedAt: Instant? = null,

    val rejectionReason: String? = null,

    // Conversion tracking
    var convertedToPOAt: Instant? = null,

    val purchaseOrderId: UUID? = null,

    @Column(length = 2000)
    var notes: String? = null,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
) {
    fun submit() {
        require(status == RequisitionStatus.DRAFT) {
            "Only draft requisitions can be submitted"
        }
        this.status = RequisitionStatus.PENDING_APPROVAL
        this.submittedAt = Instant.now()
        this.updatedAt = Instant.now()
    }

    fun approve(approverId: UUID, approverLevel: Int, comments: String? = null) {
        val approval = RequisitionApproval(
            purchaseRequisition = this,
            approverId = approverId,
            approverLevel = approverLevel,
            decision = ApprovalDecision.APPROVED,
            comments = comments,
            decidedAt = Instant.now()
        )
        approvals.add(approval)

        // Check if all required approvals are complete
        if (isFullyApproved()) {
            this.status = RequisitionStatus.APPROVED
            this.approvedAt = Instant.now()
        }
        this.updatedAt = Instant.now()
    }

    fun reject(approverId: UUID, approverLevel: Int, reason: String) {
        val approval = RequisitionApproval(
            purchaseRequisition = this,
            approverId = approverId,
            approverLevel = approverLevel,
            decision = ApprovalDecision.REJECTED,
            comments = reason,
            decidedAt = Instant.now()
        )
        approvals.add(approval)

        this.status = RequisitionStatus.REJECTED
        this.rejectedAt = Instant.now()
        this.updatedAt = Instant.now()
    }

    fun addItem(item: PurchaseRequisitionItem) {
        items.add(item)
        item.purchaseRequisition = this
        calculateTotalAmount()
        updatedAt = Instant.now()
    }

    private fun calculateTotalAmount() {
        totalAmount = items.sumOf { it.totalPrice }
    }

    private fun isFullyApproved(): Boolean {
        // Logic to check if all required approval levels are complete
        val requiredLevels = getRequiredApprovalLevels()
        val approvedLevels = approvals
            .filter { it.decision == ApprovalDecision.APPROVED }
            .map { it.approverLevel }
            .toSet()

        return requiredLevels.all { it in approvedLevels }
    }

    private fun getRequiredApprovalLevels(): Set<Int> {
        // Dynamic approval levels based on amount
        return when {
            totalAmount < BigDecimal("1000") -> setOf(1)
            totalAmount < BigDecimal("10000") -> setOf(1, 2)
            totalAmount < BigDecimal("100000") -> setOf(1, 2, 3)
            else -> setOf(1, 2, 3, 4)
        }
    }
}

enum class RequisitionType {
    STANDARD, URGENT, BLANKET, CONTRACT, SERVICE
}

enum class RequisitionStatus {
    DRAFT, PENDING_APPROVAL, APPROVED, REJECTED,
    PARTIALLY_ORDERED, FULLY_ORDERED, CANCELLED
}

enum class Priority {
    LOW, MEDIUM, HIGH, CRITICAL
}
```

**PurchaseRequisitionItem (Entity)**

```kotlin
@Entity
@Table(name = "purchase_requisition_items", schema = "supply_schema")
class PurchaseRequisitionItem(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "purchase_requisition_id", nullable = false)
    var purchaseRequisition: PurchaseRequisition? = null,

    @Column(nullable = false)
    val lineNumber: Int,

    @ManyToOne
    @JoinColumn(name = "material_id", nullable = false)
    val material: Material,

    @Column(nullable = false, precision = 19, scale = 4)
    val quantity: BigDecimal,

    val unitOfMeasure: String,

    @Column(precision = 19, scale = 4)
    val estimatedUnitPrice: BigDecimal? = null,

    @Column(precision = 19, scale = 2)
    val totalPrice: BigDecimal = BigDecimal.ZERO,

    val suggestedVendorId: UUID? = null,

    @Column(nullable = false)
    val requiredByDate: LocalDate,

    val accountAssignment: String? = null,

    @Column(length = 1000)
    var itemNotes: String? = null
)
```

**RequisitionApproval (Entity)**

```kotlin
@Entity
@Table(
    name = "requisition_approvals",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_approval_requisition", columnList = "purchaseRequisitionId"),
        Index(name = "idx_approval_approver", columnList = "approverId")
    ]
)
class RequisitionApproval(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "purchase_requisition_id", nullable = false)
    val purchaseRequisition: PurchaseRequisition,

    @Column(nullable = false)
    val approverId: UUID,

    @Column(nullable = false)
    val approverLevel: Int,

    @Enumerated(EnumType.STRING)
    val decision: ApprovalDecision,

    @Column(length = 2000)
    val comments: String? = null,

    @Column(nullable = false)
    val decidedAt: Instant
)

enum class ApprovalDecision {
    PENDING, APPROVED, REJECTED, DELEGATED
}
```

---

## Domain 4: Demand Forecasting & Planning

### Aggregates

**DemandForecast (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "demand_forecasts",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_forecast_material", columnList = "materialId"),
        Index(name = "idx_forecast_period", columnList = "forecastPeriodStart, forecastPeriodEnd")
    ]
)
class DemandForecast(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "material_id", nullable = false)
    val material: Material,

    @Column(nullable = false)
    val forecastPeriodStart: LocalDate,

    @Column(nullable = false)
    val forecastPeriodEnd: LocalDate,

    @Enumerated(EnumType.STRING)
    val forecastMethod: ForecastMethod,

    @OneToMany(mappedBy = "demandForecast", cascade = [CascadeType.ALL])
    val periodForecasts: MutableList<PeriodForecast> = mutableListOf(),

    @Column(precision = 5, scale = 2)
    var accuracyPercent: BigDecimal? = null,

    @Enumerated(EnumType.STRING)
    var status: ForecastStatus = ForecastStatus.DRAFT,

    val createdBy: UUID,

    val approvedBy: UUID? = null,

    var approvedAt: Instant? = null,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
)

enum class ForecastMethod {
    MOVING_AVERAGE, EXPONENTIAL_SMOOTHING,
    LINEAR_REGRESSION, SEASONAL, ML_BASED, MANUAL
}

enum class ForecastStatus {
    DRAFT, APPROVED, PUBLISHED, ARCHIVED
}
```

**PeriodForecast (Entity)**

```kotlin
@Entity
@Table(name = "period_forecasts", schema = "supply_schema")
class PeriodForecast(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "demand_forecast_id", nullable = false)
    val demandForecast: DemandForecast,

    @Column(nullable = false)
    val periodDate: LocalDate,

    @Enumerated(EnumType.STRING)
    val periodType: PeriodType,

    @Column(nullable = false, precision = 19, scale = 4)
    val forecastedQuantity: BigDecimal,

    @Column(precision = 19, scale = 4)
    var actualQuantity: BigDecimal? = null,

    @Column(precision = 19, scale = 4)
    var variance: BigDecimal? = null,

    @Column(precision = 5, scale = 2)
    var confidenceLevel: BigDecimal? = null
)

enum class PeriodType {
    DAILY, WEEKLY, MONTHLY, QUARTERLY, YEARLY
}
```

**MRPRun (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "mrp_runs",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_mrp_run_date", columnList = "runDate"),
        Index(name = "idx_mrp_run_status", columnList = "status")
    ]
)
class MRPRun(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val runNumber: String,

    @Column(nullable = false)
    val runDate: LocalDate,

    @Column(nullable = false)
    val planningHorizonDays: Int,

    @Enumerated(EnumType.STRING)
    val runType: MRPRunType,

    @OneToMany(mappedBy = "mrpRun", cascade = [CascadeType.ALL])
    val plannedOrders: MutableList<PlannedOrder> = mutableListOf(),

    @Enumerated(EnumType.STRING)
    var status: MRPRunStatus = MRPRunStatus.RUNNING,

    var startTime: Instant = Instant.now(),

    var endTime: Instant? = null,

    val runBy: UUID,

    @Column(nullable = false)
    val tenantId: UUID,

    @Version
    var version: Long = 0
)

enum class MRPRunType {
    REGENERATIVE,    // Full regeneration
    NET_CHANGE,      // Only changed materials
    SINGLE_LEVEL     // Single level only
}

enum class MRPRunStatus {
    RUNNING, COMPLETED, FAILED, CANCELLED
}
```

**PlannedOrder (Entity)**

```kotlin
@Entity
@Table(
    name = "planned_orders",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_planned_order_material", columnList = "materialId"),
        Index(name = "idx_planned_order_date", columnList = "plannedReceiptDate")
    ]
)
class PlannedOrder(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "mrp_run_id", nullable = false)
    val mrpRun: MRPRun,

    @ManyToOne
    @JoinColumn(name = "material_id", nullable = false)
    val material: Material,

    @Column(nullable = false, precision = 19, scale = 4)
    val plannedQuantity: BigDecimal,

    @Column(nullable = false)
    val plannedReceiptDate: LocalDate,

    @Column(nullable = false)
    val plannedStartDate: LocalDate,

    @Enumerated(EnumType.STRING)
    val orderType: PlannedOrderType,

    val suggestedVendorId: UUID? = null,

    @Enumerated(EnumType.STRING)
    var status: PlannedOrderStatus = PlannedOrderStatus.PROPOSED,

    var convertedToOrderAt: Instant? = null,

    val purchaseOrderId: UUID? = null,

    val productionOrderId: UUID? = null
)

enum class PlannedOrderType {
    PURCHASE_REQUISITION, PRODUCTION_ORDER, STOCK_TRANSFER
}

enum class PlannedOrderStatus {
    PROPOSED, FIRMED, CONVERTED, CANCELLED
}
```

---

## Domain 5: Advanced Replenishment Strategies

### Overview

Enterprise-grade replenishment system supporting:

-   **Automatic Replenishment** based on reorder points
-   **Min-Max Planning** for optimal stock levels
-   **Safety Stock Calculation** using statistical methods
-   **ABC Analysis** for inventory classification
-   **Multi-Location Replenishment** strategies
-   **Seasonal Planning** adjustments
-   **Lead Time Analysis** and optimization
-   **Service Level** targets

### Aggregates

**ReplenishmentStrategy (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "replenishment_strategies",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_replenish_material", columnList = "materialId"),
        Index(name = "idx_replenish_location", columnList = "storageLocationId")
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

    @Column(precision = 5, scale = 2)
    val annualConsumptionValue: BigDecimal? = null,

    // Review period (for periodic review)
    val reviewPeriodDays: Int? = null,

    // Seasonality
    @Column(nullable = false)
    val isSeasonalItem: Boolean = false,

    @Column(columnDefinition = "jsonb")
    val seasonalityFactors: String? = null, // Monthly factors stored as JSON

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

        // Z-score based on service level (simplified)
        val zScore = when {
            serviceLevel >= BigDecimal(99) -> BigDecimal("2.33")
            serviceLevel >= BigDecimal(97.5) -> BigDecimal("1.96")
            serviceLevel >= BigDecimal(95) -> BigDecimal("1.65")
            serviceLevel >= BigDecimal(90) -> BigDecimal("1.28")
            else -> BigDecimal("1.00")
        }

        // Safety stock = Z × σ × √(lead time)
        return zScore * stdDev * sqrt(leadTimeDays.toDouble()).toBigDecimal()
    }

    /**
     * Apply seasonal adjustment
     */
    fun applySeasonalAdjustment(currentMonth: Int): BigDecimal {
        if (!isSeasonalItem || seasonalityFactors == null) {
            return BigDecimal.ONE
        }

        // Parse JSON seasonality factors and apply for current month
        // Simplified - in real implementation, parse JSON array
        return BigDecimal.ONE // Placeholder
    }
}

enum class ReplenishmentMethod {
    REORDER_POINT,       // Order when stock hits reorder point
    MIN_MAX,             // Maintain stock between min and max
    PERIODIC_REVIEW,     // Review at fixed intervals
    DEMAND_DRIVEN,       // Based on actual demand patterns
    TWO_BIN,             // Two-bin system
    KANBAN              // Pull-based Kanban system
}

enum class SafetyStockMethod {
    FIXED,                  // Fixed safety stock quantity
    PERCENTAGE_OF_DEMAND,   // Percentage of average demand
    STATISTICAL,            // Statistical calculation based on variability
    TIME_PERIOD            // Coverage for specific time period
}

enum class ABCClassification {
    A,  // High value items (typically 20% of items, 80% of value)
    B,  // Medium value items (typically 30% of items, 15% of value)
    C   // Low value items (typically 50% of items, 5% of value)
}

enum class ReplenishmentPriority {
    CRITICAL, HIGH, NORMAL, LOW
}
```

**ReplenishmentRun (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "replenishment_runs",
    schema = "supply_schema",
    indexes = [
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
    fun addProposal(proposal: ReplenishmentProposal) {
        proposals.add(proposal)
        proposal.replenishmentRun = this
        totalProposalsGenerated++
        totalEstimatedValue += proposal.estimatedValue
    }

    fun complete() {
        this.status = ReplenishmentRunStatus.COMPLETED
        this.endTime = Instant.now()
    }

    fun fail(error: String) {
        this.status = ReplenishmentRunStatus.FAILED
        this.endTime = Instant.now()
        this.errorMessage = error
    }
}

enum class ReplenishmentRunType {
    AUTOMATIC,          // Scheduled automatic run
    MANUAL,             // Manual triggered run
    EMERGENCY,          // Emergency replenishment
    SIMULATION          // Simulation mode (no actual orders created)
}

enum class ReplenishmentRunStatus {
    RUNNING, COMPLETED, FAILED, CANCELLED
}
```

**ReplenishmentProposal (Entity)**

```kotlin
@Entity
@Table(
    name = "replenishment_proposals",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_replenish_proposal_material", columnList = "materialId"),
        Index(name = "idx_replenish_proposal_status", columnList = "status")
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

    val purchaseRequisitionId: UUID? = null,

    val transferOrderId: UUID? = null,

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
                // Set purchaseRequisitionId
            }
            ProposedOrderType.TRANSFER_ORDER -> {
                // Set transferOrderId
            }
            ProposedOrderType.PRODUCTION_ORDER -> {
                // Set production order id
            }
        }

        this.status = ProposalStatus.CONVERTED
        this.convertedToOrderAt = Instant.now()
    }
}

enum class ProposedOrderType {
    PURCHASE_REQUISITION, TRANSFER_ORDER, PRODUCTION_ORDER
}

enum class ReplenishmentReason {
    BELOW_REORDER_POINT,
    BELOW_MINIMUM,
    SAFETY_STOCK_BREACH,
    PERIODIC_REVIEW,
    SEASONAL_DEMAND,
    PROMOTIONAL_EVENT,
    STOCKOUT_PREVENTION,
    EMERGENCY
}

enum class ReplenishmentUrgency {
    CRITICAL,    // Stockout imminent
    HIGH,        // Below safety stock
    NORMAL,      // Routine replenishment
    LOW          // Opportunistic replenishment
}

enum class ProposalStatus {
    PENDING, APPROVED, REJECTED, CONVERTED, CANCELLED
}
```

**SafetyStockCalculation (Entity)**

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

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now()
)
```

---

## Domain 2: Production Management (SAP PP Pattern)

### Overview

Comprehensive production planning and control following SAP PP principles with demand-driven MRP, capacity planning, and shop floor control.

### Aggregates

**ProductionOrder (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "production_orders",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_prod_order_material", columnList = "materialId"),
        Index(name = "idx_prod_order_status", columnList = "status"),
        Index(name = "idx_prod_order_priority", columnList = "priority")
    ]
)
class ProductionOrder(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val orderNumber: String, // PO-YYYY-NNNNNN

    @Column(nullable = false)
    val materialId: UUID, // Product to be produced

    @Column(nullable = false)
    val quantity: BigDecimal, // Target quantity

    @Column(nullable = false)
    val plannedStartDate: LocalDate, // When to start production

    @Column(nullable = false)
    val plannedEndDate: LocalDate, // When to complete production

    // Actual dates
    var actualStartDate: LocalDate? = null,
    var actualEndDate: LocalDate? = null,

    // Status
    @Enumerated(EnumType.STRING)
    var status: ProductionOrderStatus = ProductionOrderStatus.DRAFT,

    // Priority for scheduling
    @Enumerated(EnumType.STRING)
    var priority: OrderPriority = OrderPriority.NORMAL,

    // Reference to parent order (for sub-orders)
    val parentOrderId: UUID? = null,

    // Notes or comments
    @Column(length = 2000)
    var notes: String? = null,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
) {
    fun start() {
        require(status == ProductionOrderStatus.DRAFT) {
            "Only draft orders can be started"
        }
        this.status = ProductionOrderStatus.IN_PROGRESS
        this.actualStartDate = LocalDate.now()
    }

    fun complete() {
        require(status == ProductionOrderStatus.IN_PROGRESS) {
            "Only in-progress orders can be completed"
        }
        this.status = ProductionOrderStatus.COMPLETED
        this.actualEndDate = LocalDate.now()
    }

    fun cancel() {
        this.status = ProductionOrderStatus.CANCELLED
    }
}

enum class ProductionOrderStatus {
    DRAFT, IN_PROGRESS, COMPLETED, CANCELLED, BLOCKED
}

enum class OrderPriority {
    LOW, NORMAL, HIGH, URGENT
}
```

**MRPConfiguration (Entity)**

```kotlin
@Entity
@Table(
    name = "mrp_configurations",
    schema = "supply_schema"
)
class MRPConfiguration(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false)
    val materialId: UUID,

    @Column(nullable = false)
    val plantId: UUID,

    // MRP type
    @Enumerated(EnumType.STRING)
    val mrpType: MRPType,

    // Lot size
    @Enumerated(EnumType.STRING)
    val lotSizeType: LotSizeType,

    // Safety stock
    @Column(precision = 19, scale = 4)
    var safetyStock: BigDecimal = BigDecimal.ZERO,

    // Reorder point
    @Column(precision = 19, scale = 4)
    var reorderPoint: BigDecimal = BigDecimal.ZERO,

    // Lead time
    var leadTimeDays: Int = 0,

    // Planning frequency
    @Enumerated(EnumType.STRING)
    var planningFrequency: PlanningFrequency = PlanningFrequency.DAILY,

    // Status
    @Column(nullable = false)
    var isActive: Boolean = true,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
)

enum class LotSizeType {
    EXCESS, FIRM, FLOATING, INVERSE
}

enum class PlanningFrequency {
    DAILY, WEEKLY, MONTHLY
}
```

**WorkCenter (Entity)**

```kotlin
@Entity
@Table(
    name = "work_centers",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_work_center_name", columnList = "name"),
        Index(name = "idx_work_center_type", columnList = "workCenterType")
    ]
)
class WorkCenter(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val name: String, // e.g., "WC-01"

    @Column(nullable = false)
    var description: String,

    @Enumerated(EnumType.STRING)
    var workCenterType: WorkCenterType,

    // Capacity
    @Column(precision = 19, scale = 2)
    val capacity: BigDecimal? = null,

    val capacityUnit: String? = null,

    // Status
    @Enumerated(EnumType.STRING)
    var status: WorkCenterStatus = WorkCenterStatus.ACTIVE,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now()
)

enum class WorkCenterType {
    MANUAL, MACHINE, PACKAGING, ASSEMBLY, INSPECTION
}

enum class WorkCenterStatus {
    ACTIVE, INACTIVE, UNDER_MAINTENANCE
}
```

**ProductionVersion (Entity)**

```kotlin
@Entity
@Table(
    name = "production_versions",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_prod_version_material", columnList = "materialId"),
        Index(name = "idx_prod_version_status", columnList = "status")
    ]
)
class ProductionVersion(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "material_id", nullable = false)
    val material: Material,

    // Version identifier
    @Column(nullable = false)
    val versionId: String, // e.g., "V1", "V2"

    // Validity dates
    var validFrom: LocalDate? = null,
    var validTo: LocalDate? = null,

    // Status
    @Enumerated(EnumType.STRING)
    var status: VersionStatus = VersionStatus.ACTIVE,

    // Notes or comments
    @Column(length = 2000)
    var notes: String? = null,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
)

enum class VersionStatus {
    ACTIVE, INACTIVE, OBSOLETE
}
```

**Routing (Entity)**

```kotlin
@Entity
@Table(
    name = "routings",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_routing_material", columnList = "materialId"),
        Index(name = "idx_routing_work_center", columnList = "workCenterId")
    ]
)
class Routing(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "material_id", nullable = false)
    val material: Material,

    @ManyToOne
    @JoinColumn(name = "work_center_id", nullable = false)
    val workCenter: WorkCenter,

    // Sequence of operations
    @Column(nullable = false)
    val operationSequence: Int,

    // Standard values
    @Column(precision = 19, scale = 4)
    val standardTime: BigDecimal? = null, // In hours

    @Column(precision = 19, scale = 4)
    val setupTime: BigDecimal? = null, // In hours

    // Status
    @Enumerated(EnumType.STRING)
    var status: RoutingStatus = RoutingStatus.ACTIVE,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
)

enum class RoutingStatus {
    ACTIVE, INACTIVE, OBSOLETE
}
```

**ProductionLine (Entity)**

```kotlin
@Entity
@Table(
    name = "production_lines",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_prod_line_work_center", columnList = "workCenterId"),
        Index(name = "idx_prod_line_status", columnList = "status")
    ]
)
class ProductionLine(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "work_center_id", nullable = false)
    val workCenter: WorkCenter,

    // Line configuration
    @Column(nullable = false)
    val lineCode: String, // e.g., "PL-01"

    @Column(nullable = false)
    var name: String,

    // Capacity
    @Column(precision = 19, scale = 2)
    val capacity: BigDecimal? = null,

    // Status
    @Enumerated(EnumType.STRING)
    var status: ProductionLineStatus = ProductionLineStatus.ACTIVE,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now()
)

enum class ProductionLineStatus {
    ACTIVE, INACTIVE, UNDER_MAINTENANCE
}
```

---

## Domain 5: Advanced Replenishment Strategies

### Overview

Enterprise-grade replenishment system supporting:

-   **Automatic Replenishment** based on reorder points
-   **Min-Max Planning** for optimal stock levels
-   **Safety Stock Calculation** using statistical methods
-   **ABC Analysis** for inventory classification
-   **Multi-Location Replenishment** strategies
-   **Seasonal Planning** adjustments
-   **Lead Time Analysis** and optimization
-   **Service Level** targets

### Aggregates

**ReplenishmentStrategy (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "replenishment_strategies",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_replenish_material", columnList = "materialId"),
        Index(name = "idx_replenish_location", columnList = "storageLocationId")
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

    @Column(precision = 5, scale = 2)
    val annualConsumptionValue: BigDecimal? = null,

    // Review period (for periodic review)
    val reviewPeriodDays: Int? = null,

    // Seasonality
    @Column(nullable = false)
    val isSeasonalItem: Boolean = false,

    @Column(columnDefinition = "jsonb")
    val seasonalityFactors: String? = null, // Monthly factors stored as JSON

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

        // Z-score based on service level (simplified)
        val zScore = when {
            serviceLevel >= BigDecimal(99) -> BigDecimal("2.33")
            serviceLevel >= BigDecimal(97.5) -> BigDecimal("1.96")
            serviceLevel >= BigDecimal(95) -> BigDecimal("1.65")
            serviceLevel >= BigDecimal(90) -> BigDecimal("1.28")
            else -> BigDecimal("1.00")
        }

        // Safety stock = Z × σ × √(lead time)
        return zScore * stdDev * sqrt(leadTimeDays.toDouble()).toBigDecimal()
    }

    /**
     * Apply seasonal adjustment
     */
    fun applySeasonalAdjustment(currentMonth: Int): BigDecimal {
        if (!isSeasonalItem || seasonalityFactors == null) {
            return BigDecimal.ONE
        }

        // Parse JSON seasonality factors and apply for current month
        // Simplified - in real implementation, parse JSON array
        return BigDecimal.ONE // Placeholder
    }
}

enum class ReplenishmentMethod {
    REORDER_POINT,       // Order when stock hits reorder point
    MIN_MAX,             // Maintain stock between min and max
    PERIODIC_REVIEW,     // Review at fixed intervals
    DEMAND_DRIVEN,       // Based on actual demand patterns
    TWO_BIN,             // Two-bin system
    KANBAN              // Pull-based Kanban system
}

enum class SafetyStockMethod {
    FIXED,                  // Fixed safety stock quantity
    PERCENTAGE_OF_DEMAND,   // Percentage of average demand
    STATISTICAL,            // Statistical calculation based on variability
    TIME_PERIOD            // Coverage for specific time period
}

enum class ABCClassification {
    A,  // High value items (typically 20% of items, 80% of value)
    B,  // Medium value items (typically 30% of items, 15% of value)
    C   // Low value items (typically 50% of items, 5% of value)
}

enum class ReplenishmentPriority {
    CRITICAL, HIGH, NORMAL, LOW
}
```

**ReplenishmentRun (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "replenishment_runs",
    schema = "supply_schema",
    indexes = [
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
    fun addProposal(proposal: ReplenishmentProposal) {
        proposals.add(proposal)
        proposal.replenishmentRun = this
        totalProposalsGenerated++
        totalEstimatedValue += proposal.estimatedValue
    }

    fun complete() {
        this.status = ReplenishmentRunStatus.COMPLETED
        this.endTime = Instant.now()
    }

    fun fail(error: String) {
        this.status = ReplenishmentRunStatus.FAILED
        this.endTime = Instant.now()
        this.errorMessage = error
    }
}

enum class ReplenishmentRunType {
    AUTOMATIC,          // Scheduled automatic run
    MANUAL,             // Manual triggered run
    EMERGENCY,          // Emergency replenishment
    SIMULATION          // Simulation mode (no actual orders created)
}

enum class ReplenishmentRunStatus {
    RUNNING, COMPLETED, FAILED, CANCELLED
}
```

**ReplenishmentProposal (Entity)**

```kotlin
@Entity
@Table(
    name = "replenishment_proposals",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_replenish_proposal_material", columnList = "materialId"),
        Index(name = "idx_replenish_proposal_status", columnList = "status")
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

    val purchaseRequisitionId: UUID? = null,

    val transferOrderId: UUID? = null,

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
                // Set purchaseRequisitionId
            }
            ProposedOrderType.TRANSFER_ORDER -> {
                // Set transferOrderId
            }
            ProposedOrderType.PRODUCTION_ORDER -> {
                // Set production order id
            }
        }

        this.status = ProposalStatus.CONVERTED
        this.convertedToOrderAt = Instant.now()
    }
}

enum class ProposedOrderType {
    PURCHASE_REQUISITION, TRANSFER_ORDER, PRODUCTION_ORDER
}

enum class ReplenishmentReason {
    BELOW_REORDER_POINT,
    BELOW_MINIMUM,
    SAFETY_STOCK_BREACH,
    PERIODIC_REVIEW,
    SEASONAL_DEMAND,
    PROMOTIONAL_EVENT,
    STOCKOUT_PREVENTION,
    EMERGENCY
}

enum class ReplenishmentUrgency {
    CRITICAL,    // Stockout imminent
    HIGH,        // Below safety stock
    NORMAL,      // Routine replenishment
    LOW          // Opportunistic replenishment
}

enum class ProposalStatus {
    PENDING, APPROVED, REJECTED, CONVERTED, CANCELLED
}
```

**SafetyStockCalculation (Entity)**

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

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now()
)
```

---

## Domain 2: Production Management (SAP PP Pattern)

### Overview

Comprehensive production planning and control following SAP PP principles with demand-driven MRP, capacity planning, and shop floor control.

### Aggregates

**ProductionOrder (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "production_orders",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_prod_order_material", columnList = "materialId"),
        Index(name = "idx_prod_order_status", columnList = "status"),
        Index(name = "idx_prod_order_priority", columnList = "priority")
    ]
)
class ProductionOrder(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val orderNumber: String, // PO-YYYY-NNNNNN

    @Column(nullable = false)
    val materialId: UUID, // Product to be produced

    @Column(nullable = false)
    val quantity: BigDecimal, // Target quantity

    @Column(nullable = false)
    val plannedStartDate: LocalDate, // When to start production

    @Column(nullable = false)
    val plannedEndDate: LocalDate, // When to complete production

    // Actual dates
    var actualStartDate: LocalDate? = null,
    var actualEndDate: LocalDate? = null,

    // Status
    @Enumerated(EnumType.STRING)
    var status: ProductionOrderStatus = ProductionOrderStatus.DRAFT,

    // Priority for scheduling
    @Enumerated(EnumType.STRING)
    var priority: OrderPriority = OrderPriority.NORMAL,

    // Reference to parent order (for sub-orders)
    val parentOrderId: UUID? = null,

    // Notes or comments
    @Column(length = 2000)
    var notes: String? = null,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
) {
    fun start() {
        require(status == ProductionOrderStatus.DRAFT) {
            "Only draft orders can be started"
        }
        this.status = ProductionOrderStatus.IN_PROGRESS
        this.actualStartDate = LocalDate.now()
    }

    fun complete() {
        require(status == ProductionOrderStatus.IN_PROGRESS) {
            "Only in-progress orders can be completed"
        }
        this.status = ProductionOrderStatus.COMPLETED
        this.actualEndDate = LocalDate.now()
    }

    fun cancel() {
        this.status = ProductionOrderStatus.CANCELLED
    }
}

enum class ProductionOrderStatus {
    DRAFT, IN_PROGRESS, COMPLETED, CANCELLED, BLOCKED
}

enum class OrderPriority {
    LOW, NORMAL, HIGH, URGENT
}
```

**MRPConfiguration (Entity)**

```kotlin
@Entity
@Table(
    name = "mrp_configurations",
    schema = "supply_schema"
)
class MRPConfiguration(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false)
    val materialId: UUID,

    @Column(nullable = false)
    val plantId: UUID,

    // MRP type
    @Enumerated(EnumType.STRING)
    val mrpType: MRPType,

    // Lot size
    @Enumerated(EnumType.STRING)
    val lotSizeType: LotSizeType,

    // Safety stock
    @Column(precision = 19, scale = 4)
    var safetyStock: BigDecimal = BigDecimal.ZERO,

    // Reorder point
    @Column(precision = 19, scale = 4)
    var reorderPoint: BigDecimal = BigDecimal.ZERO,

    // Lead time
    var leadTimeDays: Int = 0,

    // Planning frequency
    @Enumerated(EnumType.STRING)
    var planningFrequency: PlanningFrequency = PlanningFrequency.DAILY,

    // Status
    @Column(nullable = false)
    var isActive: Boolean = true,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
)

enum class LotSizeType {
    EXCESS, FIRM, FLOATING, INVERSE
}

enum class PlanningFrequency {
    DAILY, WEEKLY, MONTHLY
}
```

**WorkCenter (Entity)**

```kotlin
@Entity
@Table(
    name = "work_centers",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_work_center_name", columnList = "name"),
        Index(name = "idx_work_center_type", columnList = "workCenterType")
    ]
)
class WorkCenter(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val name: String, // e.g., "WC-01"

    @Column(nullable = false)
    var description: String,

    @Enumerated(EnumType.STRING)
    var workCenterType: WorkCenterType,

    // Capacity
    @Column(precision = 19, scale = 2)
    val capacity: BigDecimal? = null,

    val capacityUnit: String? = null,

    // Status
    @Enumerated(EnumType.STRING)
    var status: WorkCenterStatus = WorkCenterStatus.ACTIVE,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now()
)

enum class WorkCenterType {
    MANUAL, MACHINE, PACKAGING, ASSEMBLY, INSPECTION
}

enum class WorkCenterStatus {
    ACTIVE, INACTIVE, UNDER_MAINTENANCE
}
```

**ProductionVersion (Entity)**

```kotlin
@Entity
@Table(
    name = "production_versions",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_prod_version_material", columnList = "materialId"),
        Index(name = "idx_prod_version_status", columnList = "status")
    ]
)
class ProductionVersion(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "material_id", nullable = false)
    val material: Material,

    // Version identifier
    @Column(nullable = false)
    val versionId: String, // e.g., "V1", "V2"

    // Validity dates
    var validFrom: LocalDate? = null,
    var validTo: LocalDate? = null,

    // Status
    @Enumerated(EnumType.STRING)
    var status: VersionStatus = VersionStatus.ACTIVE,

    // Notes or comments
    @Column(length = 2000)
    var notes: String? = null,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
)

enum class VersionStatus {
    ACTIVE, INACTIVE, OBSOLETE
}
```

**Routing (Entity)**

```kotlin
@Entity
@Table(
    name = "routings",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_routing_material", columnList = "materialId"),
        Index(name = "idx_routing_work_center", columnList = "workCenterId")
    ]
)
class Routing(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "material_id", nullable = false)
    val material: Material,

    @ManyToOne
    @JoinColumn(name = "work_center_id", nullable = false)
    val workCenter: WorkCenter,

    // Sequence of operations
    @Column(nullable = false)
    val operationSequence: Int,

    // Standard values
    @Column(precision = 19, scale = 4)
    val standardTime: BigDecimal? = null, // In hours

    @Column(precision = 19, scale = 4)
    val setupTime: BigDecimal? = null, // In hours

    // Status
    @Enumerated(EnumType.STRING)
    var status: RoutingStatus = RoutingStatus.ACTIVE,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
)

enum class RoutingStatus {
    ACTIVE, INACTIVE, OBSOLETE
}
```

**ProductionLine (Entity)**

```kotlin
@Entity
@Table(
    name = "production_lines",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_prod_line_work_center", columnList = "workCenterId"),
        Index(name = "idx_prod_line_status", columnList = "status")
    ]
)
class ProductionLine(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "work_center_id", nullable = false)
    val workCenter: WorkCenter,

    // Line configuration
    @Column(nullable = false)
    val lineCode: String, // e.g., "PL-01"

    @Column(nullable = false)
    var name: String,

    // Capacity
    @Column(precision = 19, scale = 2)
    val capacity: BigDecimal? = null,

    // Status
    @Enumerated(EnumType.STRING)
    var status: ProductionLineStatus = ProductionLineStatus.ACTIVE,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now()
)

enum class ProductionLineStatus {
    ACTIVE, INACTIVE, UNDER_MAINTENANCE
}
```

---

## Domain 5: Advanced Replenishment Strategies

### Overview

Enterprise-grade replenishment system supporting:

-   **Automatic Replenishment** based on reorder points
-   **Min-Max Planning** for optimal stock levels
-   **Safety Stock Calculation** using statistical methods
-   **ABC Analysis** for inventory classification
-   **Multi-Location Replenishment** strategies
-   **Seasonal Planning** adjustments
-   **Lead Time Analysis** and optimization
-   **Service Level** targets

### Aggregates

**ReplenishmentStrategy (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "replenishment_strategies",
    schema = "supply_schema",
    indexes = [
        Index(name = "idx_replenish_material", columnList = "materialId"),
        Index(name = "idx_replenish_location", columnList = "storageLocationId")
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

    @Column(precision = 5, scale = 2)
    val annualConsumptionValue: BigDecimal? = null,

    // Review period (for periodic review)
    val reviewPeriodDays: Int? = null,

    // Seasonality
    @Column(nullable = false)
    val isSeasonalItem: Boolean = false,

    @Column(columnDefinition = "jsonb")
    val seasonalityFactors: String? = null, // Monthly factors stored as JSON

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

        // Z-score based on service level (simplified)
        val zScore = when {
            serviceLevel >= BigDecimal(99) -> BigDecimal("2.33")
            serviceLevel >= BigDecimal(
```
