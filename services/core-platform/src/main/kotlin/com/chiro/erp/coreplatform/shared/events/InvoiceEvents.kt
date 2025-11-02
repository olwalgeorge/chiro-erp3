package com.chiro.erp.coreplatform.shared.events

import java.math.BigDecimal
import java.time.Instant
import java.time.LocalDate
import java.util.UUID

/** Invoice aggregate events for financial management. */

/** Published when a new invoice is created. */
data class InvoiceCreatedEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "Invoice",
        override val eventType: String = "InvoiceCreated",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val invoiceId: UUID,
        val invoiceNumber: String,
        val customerId: UUID,
        val orderId: UUID?,
        val invoiceDate: LocalDate,
        val dueDate: LocalDate,
        val totalAmount: BigDecimal,
        val taxAmount: BigDecimal,
        val netAmount: BigDecimal,
        val currency: String,
        val status: InvoiceStatus,
        val lineItems: List<InvoiceLineItem>
) : IntegrationEvent

/** Published when an invoice is sent to the customer. */
data class InvoiceSentEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "Invoice",
        override val eventType: String = "InvoiceSent",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val invoiceId: UUID,
        val invoiceNumber: String,
        val sentTo: String,
        val sentAt: Instant,
        val deliveryMethod: String // EMAIL, MAIL, PORTAL
) : IntegrationEvent

/** Published when payment is received for an invoice. */
data class InvoicePaymentReceivedEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "Invoice",
        override val eventType: String = "InvoicePaymentReceived",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val invoiceId: UUID,
        val invoiceNumber: String,
        val paymentId: UUID,
        val paymentAmount: BigDecimal,
        val paymentDate: LocalDate,
        val paymentMethod: PaymentMethod,
        val remainingBalance: BigDecimal
) : IntegrationEvent

/** Published when an invoice is fully paid. */
data class InvoicePaidEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "Invoice",
        override val eventType: String = "InvoicePaid",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val invoiceId: UUID,
        val invoiceNumber: String,
        val totalPaid: BigDecimal,
        val paidAt: Instant
) : IntegrationEvent

/** Published when an invoice becomes overdue. */
data class InvoiceOverdueEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "Invoice",
        override val eventType: String = "InvoiceOverdue",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val invoiceId: UUID,
        val invoiceNumber: String,
        val dueDate: LocalDate,
        val daysOverdue: Int,
        val outstandingAmount: BigDecimal
) : IntegrationEvent

/** Published when an invoice is cancelled or voided. */
data class InvoiceCancelledEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "Invoice",
        override val eventType: String = "InvoiceCancelled",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val invoiceId: UUID,
        val invoiceNumber: String,
        val reason: String,
        val cancelledBy: UUID
) : IntegrationEvent

/** Published when a credit note is issued for an invoice. */
data class CreditNoteIssuedEvent(
        override val eventId: UUID = UUID.randomUUID(),
        override val aggregateId: UUID,
        override val aggregateType: String = "CreditNote",
        override val eventType: String = "CreditNoteIssued",
        override val occurredAt: Instant = Instant.now(),
        override val tenantId: UUID,
        override val metadata: EventMetadata,
        val creditNoteId: UUID,
        val creditNoteNumber: String,
        val invoiceId: UUID,
        val invoiceNumber: String,
        val creditAmount: BigDecimal,
        val reason: String
) : IntegrationEvent

// Value Objects for Invoice Events

data class InvoiceLineItem(
        val lineNumber: Int,
        val description: String,
        val quantity: BigDecimal,
        val unitPrice: BigDecimal,
        val lineTotal: BigDecimal,
        val taxAmount: BigDecimal,
        val accountCode: String?
)

enum class InvoiceStatus {
    DRAFT,
    PENDING,
    SENT,
    PARTIALLY_PAID,
    PAID,
    OVERDUE,
    CANCELLED,
    VOID
}

enum class PaymentMethod {
    CASH,
    CHECK,
    CREDIT_CARD,
    DEBIT_CARD,
    BANK_TRANSFER,
    ACH,
    WIRE_TRANSFER,
    PAYPAL,
    OTHER
}
