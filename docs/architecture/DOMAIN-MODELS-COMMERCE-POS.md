# Domain Models - Point of Sale (POS) - Commerce Service

## Schema: `commerce_schema`

This document contains the **Point of Sale (POS)** domain models for the Commerce service, implementing retail transaction processing, register management, and real-time sales operations.

---

## Domain: Point of Sale (POS)

### Overview

The Point of Sale domain handles retail transactions, register management, and real-time sales processing. POS is a customer-facing retail system that integrates with inventory, customer management, and financial systems.

### Aggregates

**POSTerminal (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "pos_terminals",
    schema = "commerce_schema",
    indexes = [
        Index(name = "idx_pos_terminal_number", columnList = "terminalNumber"),
        Index(name = "idx_pos_terminal_location", columnList = "locationId")
    ]
)
class POSTerminal(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val terminalNumber: String, // POS-XXXX

    @Column(nullable = false)
    var terminalName: String,

    @Column(nullable = false)
    val locationId: UUID, // Store/Branch location

    @Column(nullable = false)
    var ipAddress: String,

    @Column(nullable = false)
    var macAddress: String,

    // Hardware info
    var hardwareModel: String? = null,
    var serialNumber: String? = null,

    // Terminal capabilities
    @Column(nullable = false)
    val supportsCashPayments: Boolean = true,

    @Column(nullable = false)
    val supportsCardPayments: Boolean = true,

    @Column(nullable = false)
    val supportsMobilePayments: Boolean = true,

    @Column(nullable = false)
    val hasReceiptPrinter: Boolean = true,

    @Column(nullable = false)
    val hasBarcodeScanner: Boolean = true,

    @Column(nullable = false)
    val hasCashDrawer: Boolean = true,

    // Financial Integration
    val cashAccountId: UUID, // Reference to Financial Service
    val cardClearingAccountId: UUID? = null,

    @Enumerated(EnumType.STRING)
    var status: POSTerminalStatus = POSTerminalStatus.ACTIVE,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now()
) {
    fun activate() {
        this.status = POSTerminalStatus.ACTIVE
        this.updatedAt = Instant.now()
    }

    fun deactivate() {
        this.status = POSTerminalStatus.INACTIVE
        this.updatedAt = Instant.now()
    }
}

enum class POSTerminalStatus {
    ACTIVE, INACTIVE, MAINTENANCE, OFFLINE
}
```

**POSShift (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "pos_shifts",
    schema = "commerce_schema",
    indexes = [
        Index(name = "idx_pos_shift_terminal", columnList = "terminalId,shiftDate"),
        Index(name = "idx_pos_shift_cashier", columnList = "cashierId"),
        Index(name = "idx_pos_shift_status", columnList = "status")
    ]
)
class POSShift(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val shiftNumber: String, // SHIFT-YYYY-NNNNNN

    @ManyToOne
    @JoinColumn(name = "terminal_id", nullable = false)
    val terminal: POSTerminal,

    @Column(nullable = false)
    val cashierId: UUID, // Employee ID from Administration Service

    @Column(nullable = false)
    val shiftDate: LocalDate,

    @Column(nullable = false)
    val openedAt: Instant,

    var closedAt: Instant? = null,

    // Opening float
    @Column(nullable = false, precision = 19, scale = 2)
    val openingFloat: BigDecimal,

    @Column(nullable = false)
    val currency: String = "USD",

    // Expected closing amounts by payment method
    @Column(precision = 19, scale = 2)
    var expectedCashAmount: BigDecimal = BigDecimal.ZERO,

    @Column(precision = 19, scale = 2)
    var expectedCardAmount: BigDecimal = BigDecimal.ZERO,

    @Column(precision = 19, scale = 2)
    var expectedMobilePaymentAmount: BigDecimal = BigDecimal.ZERO,

    @Column(precision = 19, scale = 2)
    var expectedOtherAmount: BigDecimal = BigDecimal.ZERO,

    // Actual closing amounts (counted)
    @Column(precision = 19, scale = 2)
    var actualCashAmount: BigDecimal? = null,

    @Column(precision = 19, scale = 2)
    var actualCardAmount: BigDecimal? = null,

    @Column(precision = 19, scale = 2)
    var actualMobilePaymentAmount: BigDecimal? = null,

    @Column(precision = 19, scale = 2)
    var actualOtherAmount: BigDecimal? = null,

    // Variance (over/short)
    @Column(precision = 19, scale = 2)
    var cashVariance: BigDecimal = BigDecimal.ZERO,

    @Column(precision = 19, scale = 2)
    var totalVariance: BigDecimal = BigDecimal.ZERO,

    // Totals
    @Column(nullable = false, precision = 19, scale = 2)
    var totalSales: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false, precision = 19, scale = 2)
    var totalRefunds: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false)
    var transactionCount: Int = 0,

    @Column(nullable = false)
    var refundCount: Int = 0,

    @Enumerated(EnumType.STRING)
    var status: POSShiftStatus = POSShiftStatus.OPEN,

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
    companion object {
        fun generateShiftNumber(fiscalYear: Int, sequence: Long): String {
            return "SHIFT-$fiscalYear-${sequence.toString().padStart(6, '0')}"
        }
    }

    fun recordSale(amount: BigDecimal, paymentMethod: PaymentMethod) {
        require(status == POSShiftStatus.OPEN) { "Can only record sales in open shifts" }

        totalSales = totalSales.add(amount).setScale(2, RoundingMode.HALF_UP)
        transactionCount++

        // Track by payment method
        when (paymentMethod) {
            PaymentMethod.CASH -> expectedCashAmount = expectedCashAmount.add(amount).setScale(2, RoundingMode.HALF_UP)
            PaymentMethod.CREDIT_CARD, PaymentMethod.DEBIT_CARD ->
                expectedCardAmount = expectedCardAmount.add(amount).setScale(2, RoundingMode.HALF_UP)
            PaymentMethod.MOBILE_PAYMENT, PaymentMethod.PAYPAL ->
                expectedMobilePaymentAmount = expectedMobilePaymentAmount.add(amount).setScale(2, RoundingMode.HALF_UP)
            else -> expectedOtherAmount = expectedOtherAmount.add(amount).setScale(2, RoundingMode.HALF_UP)
        }

        updatedAt = Instant.now()
    }

    fun recordRefund(amount: BigDecimal, paymentMethod: PaymentMethod) {
        require(status == POSShiftStatus.OPEN) { "Can only record refunds in open shifts" }

        totalRefunds = totalRefunds.add(amount).setScale(2, RoundingMode.HALF_UP)
        refundCount++

        // Subtract from expected amounts
        when (paymentMethod) {
            PaymentMethod.CASH -> expectedCashAmount = expectedCashAmount.subtract(amount).setScale(2, RoundingMode.HALF_UP)
            PaymentMethod.CREDIT_CARD, PaymentMethod.DEBIT_CARD ->
                expectedCardAmount = expectedCardAmount.subtract(amount).setScale(2, RoundingMode.HALF_UP)
            PaymentMethod.MOBILE_PAYMENT, PaymentMethod.PAYPAL ->
                expectedMobilePaymentAmount = expectedMobilePaymentAmount.subtract(amount).setScale(2, RoundingMode.HALF_UP)
            else -> expectedOtherAmount = expectedOtherAmount.subtract(amount).setScale(2, RoundingMode.HALF_UP)
        }

        updatedAt = Instant.now()
    }

    fun close(
        actualCash: BigDecimal,
        actualCard: BigDecimal,
        actualMobile: BigDecimal,
        actualOther: BigDecimal,
        closedBy: UUID
    ) {
        require(status == POSShiftStatus.OPEN) { "Only open shifts can be closed" }

        this.actualCashAmount = actualCash
        this.actualCardAmount = actualCard
        this.actualMobilePaymentAmount = actualMobile
        this.actualOtherAmount = actualOther

        // Calculate variances
        cashVariance = actualCash.subtract(expectedCashAmount).setScale(2, RoundingMode.HALF_UP)

        val cardVariance = actualCard.subtract(expectedCardAmount).setScale(2, RoundingMode.HALF_UP)
        val mobileVariance = actualMobile.subtract(expectedMobilePaymentAmount).setScale(2, RoundingMode.HALF_UP)
        val otherVariance = actualOther.subtract(expectedOtherAmount).setScale(2, RoundingMode.HALF_UP)

        totalVariance = cashVariance.add(cardVariance).add(mobileVariance).add(otherVariance)
            .setScale(2, RoundingMode.HALF_UP)

        this.status = POSShiftStatus.CLOSED
        this.closedAt = Instant.now()
        this.updatedAt = Instant.now()

        // Publish event to Financial Service for GL posting
        publishShiftClosedEvent(closedBy)
    }

    fun reconcile(reconciledBy: UUID) {
        require(status == POSShiftStatus.CLOSED) { "Only closed shifts can be reconciled" }

        this.status = POSShiftStatus.RECONCILED
        this.updatedAt = Instant.now()
    }

    private fun publishShiftClosedEvent(userId: UUID) {
        // Publish POSShiftClosedEvent to Kafka
        // Financial Service will consume and create journal entries
    }

    fun getNetSales(): BigDecimal {
        return totalSales.subtract(totalRefunds).setScale(2, RoundingMode.HALF_UP)
    }

    fun isOverShort(): Boolean {
        return totalVariance.abs() > BigDecimal.ZERO
    }
}

enum class POSShiftStatus {
    OPEN, CLOSED, RECONCILED, DISPUTED
}
```

**POSTransaction (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "pos_transactions",
    schema = "commerce_schema",
    indexes = [
        Index(name = "idx_pos_transaction_number", columnList = "transactionNumber"),
        Index(name = "idx_pos_transaction_shift", columnList = "shiftId"),
        Index(name = "idx_pos_transaction_date", columnList = "transactionDate"),
        Index(name = "idx_pos_transaction_customer", columnList = "customerId")
    ]
)
class POSTransaction(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val transactionNumber: String, // POS-YYYY-NNNNNNNN

    @ManyToOne
    @JoinColumn(name = "shift_id", nullable = false)
    val shift: POSShift,

    @ManyToOne
    @JoinColumn(name = "terminal_id", nullable = false)
    val terminal: POSTerminal,

    @Column(nullable = false)
    val cashierId: UUID,

    @Column(nullable = false)
    val transactionDate: LocalDate,

    @Column(nullable = false)
    val transactionTime: Instant,

    @Enumerated(EnumType.STRING)
    val transactionType: POSTransactionType = POSTransactionType.SALE,

    // Customer (optional)
    val customerId: UUID? = null,
    var customerName: String? = null,
    var customerEmail: String? = null,
    var customerPhone: String? = null,

    // Items
    @OneToMany(mappedBy = "transaction", cascade = [CascadeType.ALL], orphanRemoval = true)
    val items: MutableList<POSTransactionItem> = mutableListOf(),

    // Amounts
    @Column(nullable = false, precision = 19, scale = 2)
    var subtotal: BigDecimal = BigDecimal.ZERO,

    @Column(precision = 19, scale = 2)
    var discount: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false, precision = 19, scale = 2)
    var taxAmount: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false, precision = 19, scale = 2)
    var total: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false)
    val currency: String = "USD",

    // Payments
    @OneToMany(mappedBy = "transaction", cascade = [CascadeType.ALL], orphanRemoval = true)
    val payments: MutableList<POSPayment> = mutableListOf(),

    @Column(precision = 19, scale = 2)
    var amountPaid: BigDecimal = BigDecimal.ZERO,

    @Column(precision = 19, scale = 2)
    var changeGiven: BigDecimal = BigDecimal.ZERO,

    // Receipt
    var receiptNumber: String? = null,
    var receiptPrinted: Boolean = false,
    var receiptEmailed: Boolean = false,

    // Status
    @Enumerated(EnumType.STRING)
    var status: POSTransactionStatus = POSTransactionStatus.PENDING,

    // Return/Refund
    val originalTransactionId: UUID? = null,
    var returnReason: String? = null,

    @Column(length = 1000)
    var notes: String? = null,

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
    companion object {
        fun generateTransactionNumber(fiscalYear: Int, sequence: Long): String {
            return "POS-$fiscalYear-${sequence.toString().padStart(8, '0')}"
        }

        fun generateReceiptNumber(terminalNumber: String, sequence: Long): String {
            return "$terminalNumber-${sequence.toString().padStart(6, '0')}"
        }
    }

    fun addItem(item: POSTransactionItem) {
        require(status == POSTransactionStatus.PENDING) { "Cannot add items to completed transactions" }

        item.transaction = this
        item.lineNumber = items.size + 1
        items.add(item)

        calculateTotals()
    }

    fun addPayment(payment: POSPayment) {
        require(status == POSTransactionStatus.PENDING) { "Cannot add payment to completed transactions" }
        require(payment.amount > BigDecimal.ZERO) { "Payment amount must be positive" }

        payment.transaction = this
        payments.add(payment)

        amountPaid = payments.sumOf { it.amount }.setScale(2, RoundingMode.HALF_UP)

        if (amountPaid >= total) {
            changeGiven = amountPaid.subtract(total).setScale(2, RoundingMode.HALF_UP)
            complete()
        }

        updatedAt = Instant.now()
    }

    fun calculateTotals() {
        subtotal = items.sumOf { it.lineTotal }.setScale(2, RoundingMode.HALF_UP)

        // Tax calculation - would call Tax Service or Financial Service
        taxAmount = calculateTax()

        total = subtotal.add(taxAmount).subtract(discount).setScale(2, RoundingMode.HALF_UP)

        updatedAt = Instant.now()
    }

    private fun calculateTax(): BigDecimal {
        // Simplified tax calculation
        // In real implementation, would call Tax Service from Financial Service
        val taxableAmount = items.filter { it.taxCode != null }
            .sumOf { it.lineTotal }
            .setScale(2, RoundingMode.HALF_UP)

        // Assume 8% tax rate for simplicity
        return taxableAmount.multiply(BigDecimal("0.08")).setScale(2, RoundingMode.HALF_UP)
    }

    fun complete() {
        require(status == POSTransactionStatus.PENDING) { "Only pending transactions can be completed" }
        require(amountPaid >= total) { "Insufficient payment. Paid: $amountPaid, Total: $total" }

        this.status = POSTransactionStatus.COMPLETED
        this.receiptNumber = generateReceiptNumber(terminal.terminalNumber, System.currentTimeMillis())

        // Record in shift
        shift.recordSale(total, payments.first().paymentMethod)

        // Publish events
        publishTransactionCompletedEvent()
        updateInventory()

        updatedAt = Instant.now()
    }

    fun void(reason: String) {
        require(status == POSTransactionStatus.PENDING || status == POSTransactionStatus.COMPLETED) {
            "Only pending or completed transactions can be voided"
        }

        this.status = POSTransactionStatus.VOID
        this.notes = "VOIDED: $reason"
        this.updatedAt = Instant.now()
    }

    fun createRefundTransaction(refundReason: String): POSTransaction {
        require(status == POSTransactionStatus.COMPLETED) { "Can only refund completed transactions" }
        require(transactionType == POSTransactionType.SALE) { "Can only refund sale transactions" }

        val refundTransaction = POSTransaction(
            transactionNumber = generateTransactionNumber(
                LocalDate.now().year,
                System.currentTimeMillis()
            ),
            shift = shift,
            terminal = terminal,
            cashierId = cashierId,
            transactionDate = LocalDate.now(),
            transactionTime = Instant.now(),
            transactionType = POSTransactionType.REFUND,
            customerId = customerId,
            customerName = customerName,
            customerEmail = customerEmail,
            customerPhone = customerPhone,
            originalTransactionId = this.id,
            returnReason = refundReason,
            tenantId = tenantId,
            organizationId = organizationId
        )

        // Copy items with negated amounts
        items.forEach { originalItem ->
            val refundItem = POSTransactionItem(
                productId = originalItem.productId,
                sku = originalItem.sku,
                description = originalItem.description,
                quantity = originalItem.quantity.negate(),
                unitPrice = originalItem.unitPrice,
                lineTotal = originalItem.lineTotal.negate(),
                taxAmount = originalItem.taxAmount?.negate()
            )
            refundTransaction.addItem(refundItem)
        }

        // Copy payments with negated amounts
        payments.forEach { originalPayment ->
            val refundPayment = POSPayment(
                paymentMethod = originalPayment.paymentMethod,
                amount = originalPayment.amount.negate(),
                currency = originalPayment.currency
            )
            refundTransaction.addPayment(refundPayment)
        }

        this.status = POSTransactionStatus.REFUNDED
        this.updatedAt = Instant.now()

        return refundTransaction
    }

    private fun publishTransactionCompletedEvent() {
        // Publish POSTransactionCompletedEvent to Kafka
        // Financial Service will consume and create journal entries
        // Customer Relationship Service will update customer purchase history
    }

    private fun updateInventory() {
        // Publish InventoryUpdateRequiredEvent to Kafka
        // Supply Chain Service will consume and update inventory levels
    }
}

enum class POSTransactionType {
    SALE, REFUND, RETURN, EXCHANGE, NO_SALE
}

enum class POSTransactionStatus {
    PENDING, COMPLETED, VOID, REFUNDED, CANCELLED
}
```

**POSTransactionItem (Entity)**

```kotlin
@Entity
@Table(name = "pos_transaction_items", schema = "commerce_schema")
class POSTransactionItem(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "transaction_id", nullable = false)
    var transaction: POSTransaction? = null,

    @Column(nullable = false)
    var lineNumber: Int = 0,

    val productId: UUID? = null,

    val sku: String? = null,

    @Column(nullable = false)
    var description: String,

    @Column(nullable = false, precision = 19, scale = 4)
    var quantity: BigDecimal,

    @Column(nullable = false)
    val unitOfMeasure: String = "EA",

    @Column(nullable = false, precision = 19, scale = 2)
    var unitPrice: BigDecimal,

    @Column(nullable = false, precision = 19, scale = 2)
    var lineTotal: BigDecimal,

    // Tax
    val taxCode: String? = null,

    @Column(precision = 19, scale = 2)
    val taxAmount: BigDecimal? = null,

    // Discount at item level
    @Column(precision = 19, scale = 2)
    var itemDiscount: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false)
    val tenantId: UUID = UUID.randomUUID()
) {
    fun calculateLineTotal() {
        lineTotal = unitPrice.multiply(quantity).subtract(itemDiscount)
            .setScale(2, RoundingMode.HALF_UP)
    }

    init {
        calculateLineTotal()
    }
}
```

**POSPayment (Entity)**

```kotlin
@Entity
@Table(name = "pos_payments", schema = "commerce_schema")
class POSPayment(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "transaction_id", nullable = false)
    var transaction: POSTransaction? = null,

    @Enumerated(EnumType.STRING)
    val paymentMethod: PaymentMethod,

    @Column(nullable = false, precision = 19, scale = 2)
    val amount: BigDecimal,

    @Column(nullable = false)
    val currency: String = "USD",

    // Card payment details
    val cardType: String? = null, // Visa, MasterCard, Amex
    val cardLastFour: String? = null,
    val cardTransactionId: String? = null,
    val cardAuthCode: String? = null,

    // Digital payment details
    val paymentProviderTransactionId: String? = null,

    val paymentDate: Instant = Instant.now(),

    @Column(nullable = false)
    val tenantId: UUID = UUID.randomUUID()
)

enum class PaymentMethod {
    CASH, CREDIT_CARD, DEBIT_CARD, MOBILE_PAYMENT,
    PAYPAL, APPLE_PAY, GOOGLE_PAY, GIFT_CARD,
    STORE_CREDIT, CHECK
}
```

---

## Business Rules

### POS Terminal Management

1. **Terminal Registration:**

    - Each terminal must have unique terminal number
    - Terminal must be assigned to specific location/store
    - Hardware information must be recorded for support
    - Network configuration (IP/MAC) must be documented

2. **Terminal Status:**
    - Only ACTIVE terminals can process transactions
    - Terminals in MAINTENANCE should reject new transactions
    - OFFLINE terminals should queue transactions locally

### Shift Management

1. **Opening a Shift:**

    - Cashier must count and record opening float
    - Only one shift can be open per terminal at a time
    - Opening float must be verified by supervisor (optional)

2. **During a Shift:**

    - All transactions must be linked to an open shift
    - Real-time tracking of expected vs actual cash
    - Cannot open new shift until current shift is closed

3. **Closing a Shift:**
    - Cashier must count all cash and verify card totals
    - System calculates variance (over/short)
    - Significant variances require supervisor approval
    - Closed shift generates financial entries

### Transaction Processing

1. **Sale Transactions:**

    - At least one item required
    - Payment must equal or exceed total amount
    - Change must be calculated and given to customer
    - Receipt must be offered (printed or email)

2. **Payment Validation:**

    - Card payments require authorization
    - Cash payments require sufficient denominations for change
    - Split payments allowed (multiple payment methods)
    - Negative amounts not allowed

3. **Returns and Refunds:**

    - Must reference original transaction
    - Return reason required
    - Refund method should match original payment method
    - Manager approval required for large refunds

4. **Tax Calculation:**

    - Tax calculated based on terminal location jurisdiction
    - Tax-exempt customers require tax ID verification
    - Food items may have different tax rates
    - Tax rounding follows jurisdiction rules

5. **Receipt Management:**
    - Receipt number must be unique per terminal
    - Customer can choose printed or email receipt
    - Receipt includes all legally required information
    - Duplicate receipts can be printed with authorization

---

## Integration with Other Services

### Financial Management Service

-   **POSShiftClosedEvent** → Creates journal entries for daily sales
-   **POSTransactionCompletedEvent** → Creates AR entries if customer account sale
-   GL Accounts: Cash, Card Clearing, Sales Revenue, Tax Payable

### Supply Chain Service

-   **POSTransactionCompletedEvent** → Updates inventory levels
-   Real-time inventory checks before completing sale
-   Product information sync

### Customer Relationship Service

-   Links transactions to customer accounts
-   Updates customer purchase history
-   Loyalty points calculation

### Administration Service (HR)

-   Cashier authentication and authorization
-   Commission tracking for sales staff

---

## Domain Events

```kotlin
data class POSShiftOpenedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val shiftId: UUID,
    val terminalId: UUID,
    val cashierId: UUID,
    val openingFloat: BigDecimal,
    val timestamp: Instant = Instant.now(),
    val tenantId: UUID
)

data class POSShiftClosedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val shiftId: UUID,
    val terminalId: UUID,
    val cashierId: UUID,
    val totalSales: BigDecimal,
    val totalRefunds: BigDecimal,
    val netSales: BigDecimal,
    val cashVariance: BigDecimal,
    val totalVariance: BigDecimal,
    val salesByPaymentMethod: Map<PaymentMethod, BigDecimal>,
    val transactionCount: Int,
    val timestamp: Instant = Instant.now(),
    val tenantId: UUID
)

data class POSTransactionCompletedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val transactionId: UUID,
    val transactionNumber: String,
    val shiftId: UUID,
    val terminalId: UUID,
    val cashierId: UUID,
    val customerId: UUID?,
    val items: List<TransactionItemData>,
    val subtotal: BigDecimal,
    val taxAmount: BigDecimal,
    val total: BigDecimal,
    val payments: List<PaymentData>,
    val timestamp: Instant = Instant.now(),
    val tenantId: UUID
)

data class TransactionItemData(
    val productId: UUID?,
    val sku: String?,
    val description: String,
    val quantity: BigDecimal,
    val unitPrice: BigDecimal,
    val lineTotal: BigDecimal
)

data class PaymentData(
    val paymentMethod: PaymentMethod,
    val amount: BigDecimal,
    val currency: String
)
```

---

## API Endpoints (Summary)

### POS Terminal Management

-   `POST /api/commerce/pos/terminals` - Register new terminal
-   `GET /api/commerce/pos/terminals/{id}` - Get terminal details
-   `PUT /api/commerce/pos/terminals/{id}/status` - Update terminal status

### Shift Management

-   `POST /api/commerce/pos/shifts` - Open new shift
-   `POST /api/commerce/pos/shifts/{id}/close` - Close shift
-   `GET /api/commerce/pos/shifts/{id}` - Get shift details
-   `GET /api/commerce/pos/shifts/current` - Get current open shift for terminal

### Transaction Processing

-   `POST /api/commerce/pos/transactions` - Create new transaction
-   `POST /api/commerce/pos/transactions/{id}/items` - Add item to transaction
-   `POST /api/commerce/pos/transactions/{id}/payments` - Add payment
-   `POST /api/commerce/pos/transactions/{id}/complete` - Complete transaction
-   `POST /api/commerce/pos/transactions/{id}/void` - Void transaction
-   `POST /api/commerce/pos/transactions/{id}/refund` - Create refund

---

**Related Documentation:**

-   Commerce Service Overview: `services/commerce/docs/DOMAIN-MODELS.md`
-   Financial Management Integration: `docs/architecture/DOMAIN-MODELS-FINANCIAL.md`
-   Supply Chain Integration: `docs/architecture/DOMAIN-MODELS-SUPPLY-CHAIN.md`
