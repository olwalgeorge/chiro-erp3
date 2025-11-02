package com.chiro.erp.coreplatform.shared.events

import java.math.BigDecimal
import java.time.Instant
import java.time.LocalDate
import java.util.UUID

/** Order aggregate events for e-commerce and sales orders. */

/** Published when a new order is created. */
data class OrderCreatedEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "Order",
        override val eventType: String = "OrderCreated",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val orderId: UUID,
        val orderNumber: String,
        val customerId: UUID,
        val orderDate: Instant,
        val orderType: OrderType,
        val items: List<OrderLineItem>,
        val totalAmount: BigDecimal,
        val currency: String,
        val status: OrderStatus
) : IntegrationEvent

/** Published when an order is confirmed/approved. */
data class OrderConfirmedEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "Order",
        override val eventType: String = "OrderConfirmed",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val orderId: UUID,
        val orderNumber: String,
        val confirmedBy: UUID,
        val confirmedAt: Instant
) : IntegrationEvent

/** Published when an order status changes. */
data class OrderStatusChangedEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "Order",
        override val eventType: String = "OrderStatusChanged",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val orderId: UUID,
        val orderNumber: String,
        val previousStatus: OrderStatus,
        val newStatus: OrderStatus,
        val reason: String?
) : IntegrationEvent

/** Published when an order is cancelled. */
data class OrderCancelledEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "Order",
        override val eventType: String = "OrderCancelled",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val orderId: UUID,
        val orderNumber: String,
        val reason: String,
        val cancelledBy: UUID
) : IntegrationEvent

/** Published when an order is shipped. */
data class OrderShippedEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "Order",
        override val eventType: String = "OrderShipped",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val orderId: UUID,
        val orderNumber: String,
        val shipmentId: UUID,
        val trackingNumber: String?,
        val carrier: String?,
        val shippedAt: Instant,
        val estimatedDelivery: LocalDate?
) : IntegrationEvent

/** Published when an order is delivered. */
data class OrderDeliveredEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "Order",
        override val eventType: String = "OrderDelivered",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val orderId: UUID,
        val orderNumber: String,
        val deliveredAt: Instant,
        val signedBy: String?
) : IntegrationEvent

// Value Objects for Order Events

data class OrderLineItem(
        val lineNumber: Int,
        val productId: UUID,
        val productCode: String,
        val productName: String,
        val quantity: BigDecimal,
        val unitPrice: BigDecimal,
        val lineTotal: BigDecimal,
        val taxAmount: BigDecimal = BigDecimal.ZERO
)

enum class OrderType {
    SALES_ORDER,
    SERVICE_ORDER,
    SUBSCRIPTION_ORDER,
    RETURN_ORDER,
    EXCHANGE_ORDER
}

enum class OrderStatus {
    DRAFT,
    PENDING,
    CONFIRMED,
    PROCESSING,
    ON_HOLD,
    READY_TO_SHIP,
    SHIPPED,
    DELIVERED,
    COMPLETED,
    CANCELLED,
    RETURNED
}
