package com.chiro.erp.shared.events

import java.math.BigDecimal
import java.time.Instant
import java.util.UUID

/** Inventory and material management events. */

/** Published when a new product is added to inventory. */
data class ProductCreatedEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "Product",
        override val eventType: String = "ProductCreated",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val productId: UUID,
        val productCode: String,
        val productName: String,
        val description: String?,
        val category: String,
        val unitOfMeasure: String,
        val standardCost: BigDecimal,
        val sellingPrice: BigDecimal
) : IntegrationEvent

/** Published when inventory levels change. */
data class InventoryAdjustedEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "Inventory",
        override val eventType: String = "InventoryAdjusted",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val inventoryId: UUID,
        val productId: UUID,
        val productCode: String,
        val locationId: UUID,
        val locationCode: String,
        val previousQuantity: BigDecimal,
        val adjustmentQuantity: BigDecimal,
        val newQuantity: BigDecimal,
        val reason: InventoryAdjustmentReason,
        val notes: String?
) : IntegrationEvent

/** Published when inventory is allocated to an order. */
data class InventoryAllocatedEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "Inventory",
        override val eventType: String = "InventoryAllocated",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val inventoryId: UUID,
        val productId: UUID,
        val orderId: UUID,
        val orderNumber: String,
        val allocatedQuantity: BigDecimal,
        val locationId: UUID,
        val reservationId: UUID
) : IntegrationEvent

/** Published when allocated inventory is released (e.g., order cancelled). */
data class InventoryReleasedEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "Inventory",
        override val eventType: String = "InventoryReleased",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val inventoryId: UUID,
        val productId: UUID,
        val releasedQuantity: BigDecimal,
        val reservationId: UUID,
        val reason: String
) : IntegrationEvent

/** Published when inventory falls below reorder point. */
data class InventoryLowStockEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "Inventory",
        override val eventType: String = "InventoryLowStock",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val inventoryId: UUID,
        val productId: UUID,
        val productCode: String,
        val productName: String,
        val locationId: UUID,
        val currentQuantity: BigDecimal,
        val reorderPoint: BigDecimal,
        val reorderQuantity: BigDecimal
) : IntegrationEvent

/** Published when inventory reaches zero. */
data class InventoryOutOfStockEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "Inventory",
        override val eventType: String = "InventoryOutOfStock",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val inventoryId: UUID,
        val productId: UUID,
        val productCode: String,
        val productName: String,
        val locationId: UUID
) : IntegrationEvent

/** Published when goods are received into inventory. */
data class GoodsReceivedEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "GoodsReceipt",
        override val eventType: String = "GoodsReceived",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val receiptId: UUID,
        val receiptNumber: String,
        val purchaseOrderId: UUID?,
        val supplierId: UUID,
        val locationId: UUID,
        val receivedItems: List<ReceivedItem>,
        val receivedAt: Instant
) : IntegrationEvent

/** Published when a material movement occurs between locations. */
data class MaterialTransferredEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "MaterialTransfer",
        override val eventType: String = "MaterialTransferred",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val transferId: UUID,
        val transferNumber: String,
        val productId: UUID,
        val quantity: BigDecimal,
        val fromLocationId: UUID,
        val fromLocationCode: String,
        val toLocationId: UUID,
        val toLocationCode: String,
        val reason: String?
) : IntegrationEvent

// Value Objects for Inventory Events

data class ReceivedItem(
        val lineNumber: Int,
        val productId: UUID,
        val productCode: String,
        val quantityOrdered: BigDecimal,
        val quantityReceived: BigDecimal,
        val unitCost: BigDecimal
)

enum class InventoryAdjustmentReason {
    RECEIPT,
    ISSUE,
    TRANSFER,
    PHYSICAL_COUNT,
    DAMAGE,
    OBSOLETE,
    RETURN,
    CORRECTION,
    PRODUCTION,
    OTHER
}
