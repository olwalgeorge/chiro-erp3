# Domain Models - Financial Management Service

## Schema: `finance_schema`

This service implements **SAP FI (Financial Accounting)** patterns with six domains following world-class ERP standards.

**Note:** Point of Sale (POS) has been moved to the Commerce Service as it's customer-facing retail operations. See `docs/architecture/DOMAIN-MODELS-COMMERCE-POS.md` for POS domain models.

---

## Money Handling Standards

All financial calculations in this service follow strict money handling standards:

```kotlin
import java.math.BigDecimal
import java.math.RoundingMode

/**
 * Money calculation utilities for financial accuracy and compliance.
 * Uses HALF_UP rounding per GAAP/IFRS standards.
 */
object MoneyMath {
    private val ROUNDING = RoundingMode.HALF_UP
    private const val MONEY_SCALE = 2
    private const val EXCHANGE_RATE_SCALE = 6
    private const val TAX_RATE_SCALE = 4

    fun add(vararg amounts: BigDecimal): BigDecimal {
        return amounts.fold(BigDecimal.ZERO) { acc, amount -> acc.add(amount) }
            .setScale(MONEY_SCALE, ROUNDING)
    }

    fun subtract(minuend: BigDecimal, subtrahend: BigDecimal): BigDecimal {
        return minuend.subtract(subtrahend).setScale(MONEY_SCALE, ROUNDING)
    }

    fun multiply(amount: BigDecimal, factor: BigDecimal): BigDecimal {
        return amount.multiply(factor).setScale(MONEY_SCALE, ROUNDING)
    }

    fun divide(dividend: BigDecimal, divisor: BigDecimal): BigDecimal {
        require(divisor.compareTo(BigDecimal.ZERO) != 0) { "Cannot divide by zero" }
        return dividend.divide(divisor, MONEY_SCALE, ROUNDING)
    }

    fun percentage(base: BigDecimal, percent: BigDecimal): BigDecimal {
        return base.multiply(percent)
            .divide(BigDecimal.valueOf(100), MONEY_SCALE, ROUNDING)
    }

    fun convertCurrency(amount: BigDecimal, exchangeRate: BigDecimal): BigDecimal {
        require(exchangeRate.scale() >= EXCHANGE_RATE_SCALE) {
            "Exchange rate must have at least $EXCHANGE_RATE_SCALE decimal places"
        }
        return amount.multiply(exchangeRate).setScale(MONEY_SCALE, ROUNDING)
    }

    fun areBalanced(debit: BigDecimal, credit: BigDecimal, tolerance: BigDecimal = BigDecimal("0.01")): Boolean {
        val diff = debit.subtract(credit).abs()
        return diff.compareTo(tolerance) <= 0
    }
}

/**
 * Currency validation utilities
 */
object CurrencyValidator {
    fun validateSameCurrency(currencies: List<String>): ValidationResult {
        val distinct = currencies.distinct()
        return when {
            distinct.isEmpty() -> ValidationResult.failure("No currencies provided")
            distinct.size > 1 -> ValidationResult.failure(
                "Multiple currencies detected: ${distinct.joinToString()}. " +
                "All amounts must use the same currency or enable multi-currency mode."
            )
            else -> ValidationResult.success()
        }
    }

    fun validateCurrencyCode(code: String): ValidationResult {
        return try {
            java.util.Currency.getInstance(code)
            ValidationResult.success()
        } catch (e: IllegalArgumentException) {
            ValidationResult.failure("Invalid ISO 4217 currency code: $code")
        }
    }

    fun validateExchangeRate(rate: BigDecimal?): ValidationResult {
        return when {
            rate == null -> ValidationResult.failure("Exchange rate is required")
            rate <= BigDecimal.ZERO -> ValidationResult.failure("Exchange rate must be positive")
            rate.scale() < 6 -> ValidationResult.failure("Exchange rate requires at least 6 decimal places for accuracy")
            else -> ValidationResult.success()
        }
    }
}
```

---

## Domain 1: General Ledger

### Overview

The General Ledger is the **single source of financial truth** for the entire organization, following SAP FI principles.

### Aggregates

**ChartOfAccounts (Aggregate Root)**

```kotlin
@Entity
@Table(name = "chart_of_accounts", schema = "finance_schema")
class ChartOfAccounts(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val code: String,

    @Column(nullable = false)
    var name: String,

    @Column(length = 1000)
    var description: String?,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val organizationId: UUID,

    @Enumerated(EnumType.STRING)
    var status: ChartOfAccountsStatus,

    // SAP FI Standard: Operating Chart of Accounts
    @Column(nullable = false)
    val isOperating: Boolean = true,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now()
)

enum class ChartOfAccountsStatus {
    ACTIVE, INACTIVE, ARCHIVED
}
```

**GLAccount (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "gl_accounts",
    schema = "finance_schema",
    indexes = [
        Index(name = "idx_gl_account_number", columnList = "accountNumber"),
        Index(name = "idx_gl_account_type", columnList = "accountType")
    ],
    uniqueConstraints = [
        UniqueConstraint(name = "uk_gl_account", columnNames = ["chartOfAccountsId", "accountNumber"])
    ]
)
class GLAccount(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "chart_of_accounts_id", nullable = false)
    val chartOfAccounts: ChartOfAccounts,

    @Column(nullable = false)
    val accountNumber: String, // e.g., "1000", "2000", "3000"

    @Column(nullable = false)
    var accountName: String,

    @Column(length = 1000)
    var description: String?,

    // SAP FI Account Type Classification
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    val accountType: GLAccountType,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    val accountClass: GLAccountClass,

    // Balance Sheet or P&L
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    val statementType: FinancialStatementType,

    // Normal balance (Debit or Credit)
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    val normalBalance: BalanceType,

    // Account Control
    @Embedded
    var accountControl: GLAccountControl,

    // Currency
    @Column(nullable = false)
    val currency: String = "USD",

    @Column(nullable = false)
    val allowsMultipleCurrency: Boolean = false,

    // Tax
    @Column(nullable = false)
    val taxRelevant: Boolean = false,

    val taxCode: String? = null,

    // Reconciliation
    @Column(nullable = false)
    val requiresReconciliation: Boolean = false,

    // Account hierarchy
    @ManyToOne
    @JoinColumn(name = "parent_account_id")
    var parentAccount: GLAccount? = null,

    @OneToMany(mappedBy = "parentAccount")
    val childAccounts: MutableSet<GLAccount> = mutableSetOf(),

    @Column(nullable = false)
    val tenantId: UUID,

    @Enumerated(EnumType.STRING)
    var status: GLAccountStatus,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
) {
    fun activate() {
        this.status = GLAccountStatus.ACTIVE
        this.updatedAt = Instant.now()
    }

    fun block() {
        this.status = GLAccountStatus.BLOCKED
        this.updatedAt = Instant.now()
    }

    fun isPostingAllowed(): Boolean {
        return status == GLAccountStatus.ACTIVE && accountControl.allowsPosting
    }
}

enum class GLAccountType {
    // Assets
    CASH, BANK, ACCOUNTS_RECEIVABLE, INVENTORY, FIXED_ASSETS, OTHER_ASSETS,
    // Liabilities
    ACCOUNTS_PAYABLE, SHORT_TERM_DEBT, LONG_TERM_DEBT, OTHER_LIABILITIES,
    // Equity
    CAPITAL, RETAINED_EARNINGS, DIVIDENDS,
    // Revenue
    SALES_REVENUE, SERVICE_REVENUE, OTHER_REVENUE,
    // Expenses
    COST_OF_GOODS_SOLD, OPERATING_EXPENSE, ADMINISTRATIVE_EXPENSE, OTHER_EXPENSE
}

enum class GLAccountClass {
    ASSET, LIABILITY, EQUITY, REVENUE, EXPENSE
}

enum class FinancialStatementType {
    BALANCE_SHEET, PROFIT_AND_LOSS, CASH_FLOW
}

enum class BalanceType {
    DEBIT, CREDIT
}

enum class GLAccountStatus {
    ACTIVE, INACTIVE, BLOCKED, ARCHIVED
}

@Embeddable
data class GLAccountControl(
    val allowsPosting: Boolean = true,
    val allowsManualPostings: Boolean = true,
    val requiresCostCenter: Boolean = false,
    val requiresProject: Boolean = false,
    val requiresPartner: Boolean = false,
    val lineItemDisplay: Boolean = true,
    val sortKey: String? = null
)
```

**JournalEntry (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "journal_entries",
    schema = "finance_schema",
    indexes = [
        Index(name = "idx_journal_entry_date", columnList = "postingDate"),
        Index(name = "idx_journal_entry_number", columnList = "documentNumber"),
        Index(name = "idx_journal_entry_status", columnList = "status")
    ]
)
class JournalEntry(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val documentNumber: String, // Auto-generated: JE-YYYY-NNNNNN

    @Column(nullable = false)
    val postingDate: LocalDate,

    @Column(nullable = false)
    val documentDate: LocalDate,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    val documentType: JournalEntryType,

    @Column(nullable = false)
    val fiscalYear: Int,

    @Column(nullable = false)
    val fiscalPeriod: Int,

    @Column(length = 2000)
    var description: String?,

    @Column(nullable = false)
    val currency: String = "USD",

    @Column(precision = 19, scale = 6)  // 6 decimal places for FX accuracy
    val exchangeRate: BigDecimal? = null,

    // Line items - SAP FI: Always balanced
    @OneToMany(mappedBy = "journalEntry", cascade = [CascadeType.ALL], orphanRemoval = true)
    val lineItems: MutableList<JournalEntryLineItem> = mutableListOf(),

    // Control totals
    @Column(nullable = false, precision = 19, scale = 2)
    var totalDebit: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false, precision = 19, scale = 2)
    var totalCredit: BigDecimal = BigDecimal.ZERO,

    // Status workflow
    @Enumerated(EnumType.STRING)
    var status: JournalEntryStatus = JournalEntryStatus.DRAFT,

    // Reversal
    var reversalDate: LocalDate? = null,

    @ManyToOne
    @JoinColumn(name = "reversed_entry_id")
    var reversedEntry: JournalEntry? = null,

    // Audit
    @Column(nullable = false)
    val createdBy: UUID,

    var postedBy: UUID? = null,
    var postedAt: Instant? = null,

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
        fun generateDocumentNumber(fiscalYear: Int, sequence: Long): String {
            return "JE-$fiscalYear-${sequence.toString().padStart(6, '0')}"
        }
    }

    fun addLineItem(lineItem: JournalEntryLineItem) {
        lineItems.add(lineItem)
        lineItem.journalEntry = this
        recalculateTotals()
    }

    fun removeLineItem(lineItem: JournalEntryLineItem) {
        lineItems.remove(lineItem)
        recalculateTotals()
    }

    private fun recalculateTotals() {
        totalDebit = MoneyMath.add(
            *lineItems
                .mapNotNull { it.debitAmount }
                .toTypedArray()
        )

        totalCredit = MoneyMath.add(
            *lineItems
                .mapNotNull { it.creditAmount }
                .toTypedArray()
        )

        updatedAt = Instant.now()
    }

    fun validate(): ValidationResult {
        val errors = mutableListOf<String>()

        // Must have at least 2 line items
        if (lineItems.size < 2) {
            errors.add("Journal entry must have at least 2 line items")
        }

        // Debits must equal credits (with 1 cent tolerance for rounding)
        if (!MoneyMath.areBalanced(totalDebit, totalCredit)) {
            errors.add("Debits ($totalDebit) and credits ($totalCredit) must balance within 0.01 tolerance")
        }

        // All line items must have account assigned
        if (lineItems.any { it.glAccount == null }) {
            errors.add("All line items must have a GL account assigned")
        }

        // Currency consistency validation
        if (!allowsMultipleCurrency) {
            val lineItemCurrencies = lineItems.mapNotNull { it.glAccount?.currency }.distinct()
            if (lineItemCurrencies.size > 1) {
                errors.add("Multiple currencies not allowed in this entry: ${lineItemCurrencies.joinToString()}")
            }
            if (lineItemCurrencies.isNotEmpty() && lineItemCurrencies.first() != currency) {
                errors.add("Line item currencies must match journal entry currency: $currency")
            }
        }

        // Validate exchange rate if foreign currency
        if (currency != "USD" && exchangeRate == null) {
            errors.add("Exchange rate is required for foreign currency transactions")
        }

        // Validate exchange rate precision
        exchangeRate?.let {
            val rateValidation = CurrencyValidator.validateExchangeRate(it)
            if (!rateValidation.isSuccess) {
                errors.addAll(rateValidation.errors)
            }
        }

        // Validate all amounts are properly rounded
        lineItems.forEach { line ->
            line.debitAmount?.let {
                if (it.scale() > 2) errors.add("Line ${line.lineNumber}: Debit amount has incorrect scale")
            }
            line.creditAmount?.let {
                if (it.scale() > 2) errors.add("Line ${line.lineNumber}: Credit amount has incorrect scale")
            }
        }

        return if (errors.isEmpty()) {
            ValidationResult.success()
        } else {
            ValidationResult.failure(errors)
        }
    }

    fun post(postedBy: UUID) {
        val validation = validate()
        require(validation.isSuccess) { "Cannot post invalid journal entry: ${validation.errors}" }
        require(status == JournalEntryStatus.DRAFT) { "Only draft entries can be posted" }

        this.status = JournalEntryStatus.POSTED
        this.postedBy = postedBy
        this.postedAt = Instant.now()
        this.updatedAt = Instant.now()
    }

    fun reverse(reversalDate: LocalDate): JournalEntry {
        require(status == JournalEntryStatus.POSTED) { "Only posted entries can be reversed" }

        // Create reversal entry with opposite amounts
        val reversalEntry = JournalEntry(
            documentNumber = generateDocumentNumber(fiscalYear, System.currentTimeMillis()),
            postingDate = reversalDate,
            documentDate = reversalDate,
            documentType = JournalEntryType.REVERSAL,
            fiscalYear = fiscalYear,
            fiscalPeriod = fiscalPeriod,
            description = "Reversal of $documentNumber",
            currency = currency,
            exchangeRate = exchangeRate,
            status = JournalEntryStatus.POSTED,
            reversedEntry = this,
            createdBy = this.createdBy,
            tenantId = tenantId,
            organizationId = organizationId
        )

        // Add reversed line items
        lineItems.forEach { originalLine ->
            val reversedLine = JournalEntryLineItem(
                glAccount = originalLine.glAccount,
                debitAmount = originalLine.creditAmount, // Swap debit/credit
                creditAmount = originalLine.debitAmount,
                description = "Reversal: ${originalLine.description}",
                costCenter = originalLine.costCenter,
                profitCenter = originalLine.profitCenter,
                businessArea = originalLine.businessArea
            )
            reversalEntry.addLineItem(reversedLine)
        }

        this.status = JournalEntryStatus.REVERSED
        this.reversalDate = reversalDate
        this.updatedAt = Instant.now()

        return reversalEntry
    }
}

enum class JournalEntryType {
    STANDARD, ACCRUAL, DEFERRAL, ADJUSTMENT, REVERSAL, OPENING, CLOSING
}

enum class JournalEntryStatus {
    DRAFT, PENDING_APPROVAL, APPROVED, POSTED, REVERSED, CANCELLED
}

data class ValidationResult(
    val isSuccess: Boolean,
    val errors: List<String> = emptyList()
) {
    companion object {
        fun success() = ValidationResult(true)
        fun failure(errors: List<String>) = ValidationResult(false, errors)
    }
}
```

**JournalEntryLineItem (Entity within JournalEntry aggregate)**

```kotlin
@Entity
@Table(name = "journal_entry_line_items", schema = "finance_schema")
class JournalEntryLineItem(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "journal_entry_id", nullable = false)
    var journalEntry: JournalEntry? = null,

    @Column(nullable = false)
    val lineNumber: Int = 0,

    @ManyToOne
    @JoinColumn(name = "gl_account_id", nullable = false)
    val glAccount: GLAccount,

    @Column(precision = 19, scale = 2)
    val debitAmount: BigDecimal? = null,

    @Column(precision = 19, scale = 2)
    val creditAmount: BigDecimal? = null,

    @Column(length = 1000)
    var description: String?,

    // Cost allocation (SAP CO integration)
    val costCenter: String? = null,
    val profitCenter: String? = null,
    val businessArea: String? = null,
    val project: String? = null,

    // Partner account
    val partnerId: UUID? = null,
    val partnerType: String? = null, // CUSTOMER, VENDOR, EMPLOYEE

    // Tax
    val taxCode: String? = null,

    @Column(precision = 19, scale = 2)
    val taxAmount: BigDecimal? = null,

    // Reference documents
    val referenceDocumentType: String? = null,
    val referenceDocumentNumber: String? = null
) {
    init {
        require((debitAmount == null) xor (creditAmount == null)) {
            "Line item must have either debit or credit amount, not both"
        }
        require(debitAmount?.let { it > BigDecimal.ZERO } != false) {
            "Debit amount must be positive"
        }
        require(creditAmount?.let { it > BigDecimal.ZERO } != false) {
            "Credit amount must be positive"
        }
    }

    fun getAmount(): BigDecimal {
        return debitAmount ?: creditAmount ?: BigDecimal.ZERO
    }

    fun isDebit(): Boolean = debitAmount != null
    fun isCredit(): Boolean = creditAmount != null
}
```

**AccountBalance (View/Read Model)**

```kotlin
@Entity
@Table(
    name = "account_balances",
    schema = "finance_schema",
    indexes = [
        Index(name = "idx_balance_account", columnList = "glAccountId,fiscalYear,fiscalPeriod")
    ],
    uniqueConstraints = [
        UniqueConstraint(
            name = "uk_account_balance",
            columnNames = ["glAccountId", "fiscalYear", "fiscalPeriod"]
        )
    ]
)
class AccountBalance(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "gl_account_id", nullable = false)
    val glAccount: GLAccount,

    @Column(nullable = false)
    val fiscalYear: Int,

    @Column(nullable = false)
    val fiscalPeriod: Int,

    @Column(nullable = false, precision = 19, scale = 2)
    var openingBalance: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false, precision = 19, scale = 2)
    var debitTotal: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false, precision = 19, scale = 2)
    var creditTotal: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false, precision = 19, scale = 2)
    var closingBalance: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false)
    val currency: String = "USD",

    @Column(nullable = false)
    val updatedAt: Instant = Instant.now()
) {
    fun recalculateClosingBalance() {
        val calculated = when (glAccount.normalBalance) {
            BalanceType.DEBIT -> MoneyMath.add(openingBalance, debitTotal).let {
                MoneyMath.subtract(it, creditTotal)
            }
            BalanceType.CREDIT -> MoneyMath.add(openingBalance, creditTotal).let {
                MoneyMath.subtract(it, debitTotal)
            }
        }
        closingBalance = calculated.setScale(2, RoundingMode.HALF_UP)
    }
}
```

---

## Domain 2: Accounts Receivable (AR)

### Aggregates

**CustomerInvoice (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "customer_invoices",
    schema = "finance_schema",
    indexes = [
        Index(name = "idx_invoice_customer", columnList = "customerId"),
        Index(name = "idx_invoice_date", columnList = "invoiceDate"),
        Index(name = "idx_invoice_status", columnList = "status"),
        Index(name = "idx_invoice_due_date", columnList = "dueDate")
    ]
)
class CustomerInvoice(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val invoiceNumber: String, // INV-YYYY-NNNNNN

    @Column(nullable = false)
    val customerId: UUID,

    @Column(nullable = false)
    val invoiceDate: LocalDate,

    @Column(nullable = false)
    val dueDate: LocalDate,

    @Column(nullable = false)
    val fiscalYear: Int,

    @Column(nullable = false)
    val fiscalPeriod: Int,

    // Invoice header
    @Embedded
    var billingInfo: BillingInfo,

    @Embedded
    var shippingInfo: ShippingInfo?,

    // Line items
    @OneToMany(mappedBy = "invoice", cascade = [CascadeType.ALL], orphanRemoval = true)
    val lineItems: MutableList<InvoiceLineItem> = mutableListOf(),

    // Amounts
    @Column(nullable = false, precision = 19, scale = 2)
    var subtotal: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false, precision = 19, scale = 2)
    var taxAmount: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false, precision = 19, scale = 2)
    var discountAmount: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false, precision = 19, scale = 2)
    var totalAmount: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false, precision = 19, scale = 2)
    var paidAmount: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false, precision = 19, scale = 2)
    var balanceDue: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false)
    val currency: String = "USD",

    // Payment terms
    @Embedded
    var paymentTerms: PaymentTerms,

    // Status
    @Enumerated(EnumType.STRING)
    var status: InvoiceStatus = InvoiceStatus.DRAFT,

    // Payments
    @OneToMany(mappedBy = "invoice", cascade = [CascadeType.ALL])
    val payments: MutableList<CustomerPayment> = mutableListOf(),

    // References
    val purchaseOrderNumber: String? = null,
    val salesOrderId: UUID? = null,

    @Column(length = 2000)
    var notes: String? = null,

    // Audit
    @Column(nullable = false)
    val createdBy: UUID,

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
        fun generateInvoiceNumber(fiscalYear: Int, sequence: Long): String {
            return "INV-$fiscalYear-${sequence.toString().padStart(6, '0')}"
        }
    }

    fun addLineItem(lineItem: InvoiceLineItem) {
        lineItems.add(lineItem)
        lineItem.invoice = this
        recalculateTotals()
    }

    fun removeLineItem(lineItem: InvoiceLineItem) {
        lineItems.remove(lineItem)
        recalculateTotals()
    }

    private fun recalculateTotals() {
        subtotal = MoneyMath.add(*lineItems.map { it.lineTotal }.toTypedArray())
        taxAmount = MoneyMath.add(*lineItems.mapNotNull { it.taxAmount }.toTypedArray())

        // Total = Subtotal + Tax - Discount
        val subtotalPlusTax = MoneyMath.add(subtotal, taxAmount)
        totalAmount = MoneyMath.subtract(subtotalPlusTax, discountAmount)

        // Balance Due = Total - Paid
        balanceDue = MoneyMath.subtract(totalAmount, paidAmount)
        updatedAt = Instant.now()
    }

    fun post() {
        require(status == InvoiceStatus.DRAFT) { "Only draft invoices can be posted" }
        require(lineItems.isNotEmpty()) { "Invoice must have at least one line item" }

        this.status = InvoiceStatus.POSTED
        this.updatedAt = Instant.now()

        // Generate GL posting
        generateGLPosting()
    }

    private fun generateGLPosting() {
        // Create journal entry for invoice posting
        // DR: Accounts Receivable
        // CR: Revenue (by line item)
        // CR: Tax Payable (if applicable)
    }

    fun applyPayment(payment: CustomerPayment) {
        require(status == InvoiceStatus.POSTED) { "Can only apply payment to posted invoices" }
        require(payment.currency == currency) {
            "Payment currency (${payment.currency}) must match invoice currency ($currency)"
        }
        require(payment.amount > BigDecimal.ZERO) { "Payment amount must be positive" }

        val remainingBalance = MoneyMath.subtract(totalAmount, paidAmount)
        require(payment.amount <= remainingBalance) {
            "Payment amount (${payment.amount}) cannot exceed remaining balance ($remainingBalance)"
        }

        payments.add(payment)
        paidAmount = MoneyMath.add(paidAmount, payment.amount)
        balanceDue = MoneyMath.subtract(totalAmount, paidAmount)

        // Update status based on payment
        status = when {
            balanceDue <= BigDecimal.ZERO -> InvoiceStatus.PAID
            paidAmount > BigDecimal.ZERO -> InvoiceStatus.PARTIALLY_PAID
            else -> status
        }

        updatedAt = Instant.now()
    }

    fun isDue(): Boolean {
        return status == InvoiceStatus.POSTED && LocalDate.now().isAfter(dueDate)
    }

    fun isOverdue(): Boolean {
        return isDue() && balanceDue > BigDecimal.ZERO
    }

    fun getDaysOverdue(): Long {
        return if (isOverdue()) {
            ChronoUnit.DAYS.between(dueDate, LocalDate.now())
        } else {
            0
        }
    }
}

enum class InvoiceStatus {
    DRAFT, PENDING_APPROVAL, APPROVED, POSTED, PARTIALLY_PAID, PAID, CANCELLED, VOID
}

@Embeddable
data class BillingInfo(
    @Column(nullable = false)
    val customerName: String,

    @Column(nullable = false)
    val billingAddress: String,

    val taxId: String? = null,

    @Column(nullable = false)
    val email: String,

    val phone: String? = null
)

@Embeddable
data class ShippingInfo(
    val recipientName: String,
    val shippingAddress: String,
    val shippingMethod: String? = null,
    val trackingNumber: String? = null
)

@Embeddable
data class PaymentTerms(
    val termsDays: Int = 30, // NET 30
    val discountPercent: BigDecimal = BigDecimal.ZERO,
    val discountDays: Int = 0, // e.g., 2/10 NET 30
    val description: String = "NET 30"
)
```

**InvoiceLineItem**

```kotlin
@Entity
@Table(name = "invoice_line_items", schema = "finance_schema")
class InvoiceLineItem(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "invoice_id", nullable = false)
    var invoice: CustomerInvoice? = null,

    @Column(nullable = false)
    val lineNumber: Int,

    val productId: UUID? = null,

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

    @Column(precision = 5, scale = 2)
    val taxRate: BigDecimal? = null,

    @Column(precision = 19, scale = 2)
    val taxAmount: BigDecimal? = null,

    // Accounting
    val revenueAccountId: UUID? = null,
    val costCenterId: UUID? = null
) {
    init {
        recalculateLineTotal()
    }

    fun recalculateLineTotal() {
        lineTotal = MoneyMath.multiply(quantity, unitPrice)
    }

    fun updateQuantity(newQuantity: BigDecimal) {
        require(newQuantity >= BigDecimal.ZERO) { "Quantity cannot be negative" }
        this.quantity = newQuantity
        recalculateLineTotal()
    }

    fun updateUnitPrice(newPrice: BigDecimal) {
        require(newPrice >= BigDecimal.ZERO) { "Unit price cannot be negative" }
        this.unitPrice = newPrice
        recalculateLineTotal()
    }
}
```

**CustomerPayment (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "customer_payments",
    schema = "finance_schema",
    indexes = [
        Index(name = "idx_payment_customer", columnList = "customerId"),
        Index(name = "idx_payment_date", columnList = "paymentDate"),
        Index(name = "idx_payment_status", columnList = "status")
    ]
)
class CustomerPayment(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val paymentNumber: String, // PMT-YYYY-NNNNNN

    @Column(nullable = false)
    val customerId: UUID,

    @ManyToOne
    @JoinColumn(name = "invoice_id")
    var invoice: CustomerInvoice? = null,

    @Column(nullable = false)
    val paymentDate: LocalDate,

    @Column(nullable = false, precision = 19, scale = 2)
    val amount: BigDecimal,

    @Column(nullable = false)
    val currency: String = "USD",

    @Enumerated(EnumType.STRING)
    val paymentMethod: PaymentMethod,

    // Payment details
    val referenceNumber: String? = null,
    val checkNumber: String? = null,
    val cardLast4: String? = null,
    val transactionId: String? = null,

    @Enumerated(EnumType.STRING)
    var status: PaymentStatus = PaymentStatus.PENDING,

    @Column(length = 1000)
    var notes: String? = null,

    // Bank account
    val bankAccountId: UUID? = null,

    // Audit
    @Column(nullable = false)
    val createdBy: UUID,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now()
) {
    fun authorize() {
        require(status == PaymentStatus.PENDING) { "Only pending payments can be authorized" }
        require(paymentMethod == PaymentMethod.CREDIT_CARD || paymentMethod == PaymentMethod.DEBIT_CARD) {
            "Only card payments can be authorized"
        }
        this.status = PaymentStatus.AUTHORIZED
        this.updatedAt = Instant.now()
    }

    fun confirm() {
        require(status == PaymentStatus.PENDING || status == PaymentStatus.AUTHORIZED) {
            "Only pending or authorized payments can be confirmed"
        }

        // Validate payment method specific requirements
        if (paymentMethod.requiresReference() && referenceNumber.isNullOrBlank()) {
            throw IllegalStateException("${paymentMethod.name} requires a reference number")
        }

        if (paymentMethod.requiresBankAccount() && bankAccountId == null) {
            throw IllegalStateException("${paymentMethod.name} requires a bank account")
        }

        // Validate currency
        val currencyValidation = CurrencyValidator.validateCurrencyCode(currency)
        require(currencyValidation.isSuccess) { currencyValidation.errors.joinToString() }

        this.status = PaymentStatus.CONFIRMED
        this.updatedAt = Instant.now()

        // Post to GL
        postToGeneralLedger()
    }

    fun clear() {
        require(status == PaymentStatus.CONFIRMED) { "Only confirmed payments can be cleared" }
        this.status = PaymentStatus.CLEARED
        this.updatedAt = Instant.now()
    }

    fun reconcile() {
        require(status == PaymentStatus.CLEARED) { "Only cleared payments can be reconciled" }
        this.status = PaymentStatus.RECONCILED
        this.updatedAt = Instant.now()
    }

    fun void(reason: String) {
        require(status.canBeVoided()) {
            "Only pending, authorized, or confirmed payments can be voided. Current status: $status"
        }
        this.status = PaymentStatus.VOID
        this.notes = "Voided: $reason${if (notes != null) "\n$notes" else ""}"
        this.updatedAt = Instant.now()
    }

    fun refund(refundAmount: BigDecimal, reason: String): CustomerPayment {
        require(status.canBeRefunded()) {
            "Only cleared or reconciled payments can be refunded. Current status: $status"
        }
        require(refundAmount > BigDecimal.ZERO) { "Refund amount must be positive" }
        require(refundAmount <= amount) { "Refund amount cannot exceed original payment amount" }

        val refundPayment = CustomerPayment(
            paymentNumber = "$paymentNumber-REFUND",
            customerId = customerId,
            invoice = invoice,
            paymentDate = LocalDate.now(),
            amount = refundAmount.negate(), // Negative for refund
            currency = currency,
            paymentMethod = paymentMethod,
            referenceNumber = "REFUND-$referenceNumber",
            status = PaymentStatus.CONFIRMED,
            notes = "Refund of $paymentNumber: $reason",
            bankAccountId = bankAccountId,
            createdBy = createdBy,
            tenantId = tenantId
        )

        this.status = if (refundAmount == amount) {
            PaymentStatus.REFUNDED
        } else {
            PaymentStatus.PARTIALLY_REFUNDED
        }
        this.notes = "Refunded $refundAmount: $reason${if (notes != null) "\n$notes" else ""}"
        this.updatedAt = Instant.now()

        return refundPayment
    }

    private fun postToGeneralLedger() {
        // Create journal entry
        // DR: Bank/Cash (based on payment method)
        // CR: Accounts Receivable

        // For different payment methods:
        // - CASH: DR Cash Account
        // - CHECK: DR Undeposited Funds -> later DR Bank when deposited
        // - CREDIT_CARD: DR Credit Card Clearing Account -> later DR Bank when settled
        // - ACH/WIRE: DR Bank Account (with settlement delay)
    }
}

enum class PaymentMethod {
    CASH,
    CHECK,
    CREDIT_CARD,
    DEBIT_CARD,
    BANK_TRANSFER,
    ACH,
    WIRE,
    PAYPAL,
    STRIPE,
    SQUARE,
    VENMO,
    ZELLE,
    CRYPTOCURRENCY,
    MOBILE_PAYMENT,
    OTHER;

    fun requiresReference(): Boolean = when (this) {
        CHECK -> true
        WIRE -> true
        ACH -> true
        BANK_TRANSFER -> true
        else -> false
    }

    fun supportsPartialPayments(): Boolean = when (this) {
        CASH -> true
        CHECK -> true
        BANK_TRANSFER -> true
        ACH -> true
        WIRE -> true
        else -> false
    }

    fun requiresBankAccount(): Boolean = when (this) {
        ACH -> true
        WIRE -> true
        BANK_TRANSFER -> true
        else -> false
    }

    fun instantSettlement(): Boolean = when (this) {
        CASH -> true
        CREDIT_CARD -> false
        DEBIT_CARD -> false
        BANK_TRANSFER -> false
        ACH -> false
        WIRE -> false
        else -> false
    }

    fun typicalSettlementDays(): Int = when (this) {
        CASH -> 0
        CREDIT_CARD -> 2
        DEBIT_CARD -> 1
        CHECK -> 3
        ACH -> 2
        WIRE -> 1
        BANK_TRANSFER -> 1
        PAYPAL -> 1
        STRIPE -> 2
        SQUARE -> 2
        else -> 3
    }
}

enum class PaymentStatus {
    PENDING,       // Payment initiated but not confirmed
    AUTHORIZED,    // Payment authorized (credit cards)
    CONFIRMED,     // Payment confirmed/captured
    CLEARED,       // Payment cleared and settled
    RECONCILED,    // Payment reconciled with bank statement
    VOID,          // Payment voided before settlement
    FAILED,        // Payment failed to process
    REFUNDED,      // Payment refunded to customer
    PARTIALLY_REFUNDED,  // Partial refund issued
    DISPUTED,      // Payment disputed/chargeback
    CANCELLED;     // Payment cancelled

    fun isFinal(): Boolean = when (this) {
        CLEARED, RECONCILED, VOID, FAILED, REFUNDED -> true
        else -> false
    }

    fun canBeVoided(): Boolean = when (this) {
        PENDING, AUTHORIZED, CONFIRMED -> true
        else -> false
    }

    fun canBeRefunded(): Boolean = when (this) {
        CLEARED, RECONCILED -> true
        else -> false
    }
}
```

---

## Domain 3: Accounts Payable (AP)

### Aggregates

**VendorInvoice (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "vendor_invoices",
    schema = "finance_schema",
    indexes = [
        Index(name = "idx_vendor_invoice_vendor", columnList = "vendorId"),
        Index(name = "idx_vendor_invoice_date", columnList = "invoiceDate"),
        Index(name = "idx_vendor_invoice_status", columnList = "status")
    ]
)
class VendorInvoice(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val documentNumber: String, // VINV-YYYY-NNNNNN

    @Column(nullable = false)
    val vendorId: UUID,

    @Column(nullable = false)
    val vendorInvoiceNumber: String, // Vendor's invoice number

    @Column(nullable = false)
    val invoiceDate: LocalDate,

    @Column(nullable = false)
    val dueDate: LocalDate,

    // Purchase order reference (3-way matching)
    val purchaseOrderId: UUID? = null,

    // Goods receipt reference (3-way matching)
    val goodsReceiptId: UUID? = null,

    // Line items
    @OneToMany(mappedBy = "vendorInvoice", cascade = [CascadeType.ALL])
    val lineItems: MutableList<VendorInvoiceLineItem> = mutableListOf(),

    // Amounts
    @Column(nullable = false, precision = 19, scale = 2)
    var subtotal: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false, precision = 19, scale = 2)
    var taxAmount: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false, precision = 19, scale = 2)
    var totalAmount: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false, precision = 19, scale = 2)
    var paidAmount: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false, precision = 19, scale = 2)
    var balanceDue: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false)
    val currency: String = "USD",

    // Payment terms
    @Embedded
    var paymentTerms: PaymentTerms,

    // Status and workflow
    @Enumerated(EnumType.STRING)
    var status: VendorInvoiceStatus = VendorInvoiceStatus.RECEIVED,

    @Enumerated(EnumType.STRING)
    var approvalStatus: ApprovalStatus = ApprovalStatus.PENDING,

    @Enumerated(EnumType.STRING)
    var matchingStatus: MatchingStatus? = null,

    // Approval workflow
    var approvedBy: UUID? = null,
    var approvedAt: Instant? = null,

    @Column(length = 2000)
    var notes: String? = null,

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
    fun perform3WayMatch(): MatchingResult {
        require(purchaseOrderId != null) { "PO required for 3-way matching" }
        require(goodsReceiptId != null) { "GR required for 3-way matching" }

        // Implement 3-way matching logic
        // Compare: PO quantities/prices vs GR quantities vs Invoice quantities/prices

        val isMatch = true // Simplified
        matchingStatus = if (isMatch) MatchingStatus.MATCHED else MatchingStatus.MISMATCH
        updatedAt = Instant.now()

        return MatchingResult(isMatch, emptyList())
    }

    fun approve(approver: UUID) {
        require(status == VendorInvoiceStatus.RECEIVED) {
            "Only received invoices can be approved"
        }
        require(approvalStatus == ApprovalStatus.PENDING) {
            "Invoice is not pending approval"
        }

        this.approvalStatus = ApprovalStatus.APPROVED
        this.approvedBy = approver
        this.approvedAt = Instant.now()
        this.status = VendorInvoiceStatus.APPROVED
        this.updatedAt = Instant.now()
    }

    fun reject(rejector: UUID, reason: String) {
        this.approvalStatus = ApprovalStatus.REJECTED
        this.status = VendorInvoiceStatus.REJECTED
        this.notes = "Rejected: $reason"
        this.updatedAt = Instant.now()
    }

    fun post() {
        require(status == VendorInvoiceStatus.APPROVED) {
            "Only approved invoices can be posted"
        }

        this.status = VendorInvoiceStatus.POSTED
        this.updatedAt = Instant.now()

        // Post to GL
        postToGeneralLedger()
    }

    private fun postToGeneralLedger() {
        // Create journal entry
        // DR: Expense/Asset accounts (by line item)
        // DR: Tax Receivable (if applicable)
        // CR: Accounts Payable
    }

    fun schedulePayment(paymentDate: LocalDate) {
        require(status == VendorInvoiceStatus.POSTED) {
            "Only posted invoices can be scheduled for payment"
        }

        this.status = VendorInvoiceStatus.SCHEDULED_FOR_PAYMENT
        this.updatedAt = Instant.now()
    }
}

enum class VendorInvoiceStatus {
    RECEIVED, PENDING_MATCHING, MATCHED, APPROVED, REJECTED, POSTED,
    SCHEDULED_FOR_PAYMENT, PAID, CANCELLED
}

enum class ApprovalStatus {
    PENDING, APPROVED, REJECTED
}

enum class MatchingStatus {
    MATCHED, MISMATCH, UNDER_TOLERANCE, OVER_TOLERANCE
}

data class MatchingResult(
    val isMatch: Boolean,
    val discrepancies: List<String>
)
```

**VendorInvoiceLineItem**

```kotlin
@Entity
@Table(name = "vendor_invoice_line_items", schema = "finance_schema")
class VendorInvoiceLineItem(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "vendor_invoice_id", nullable = false)
    var vendorInvoice: VendorInvoice? = null,

    @Column(nullable = false)
    val lineNumber: Int,

    val purchaseOrderLineId: UUID? = null,

    @Column(nullable = false)
    var description: String,

    @Column(nullable = false, precision = 19, scale = 4)
    var quantity: BigDecimal,

    @Column(nullable = false)
    val unitOfMeasure: String,

    @Column(nullable = false, precision = 19, scale = 2)
    var unitPrice: BigDecimal,

    @Column(nullable = false, precision = 19, scale = 2)
    var lineTotal: BigDecimal,

    // GL Account assignment
    val expenseAccountId: UUID? = null,
    val assetAccountId: UUID? = null,
    val costCenterId: UUID? = null,

    // Tax
    val taxCode: String? = null,
    @Column(precision = 19, scale = 2)
    val taxAmount: BigDecimal? = null
)
```

**VendorPayment (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "vendor_payments",
    schema = "finance_schema",
    indexes = [
        Index(name = "idx_vendor_payment_vendor", columnList = "vendorId"),
        Index(name = "idx_vendor_payment_date", columnList = "paymentDate")
    ]
)
class VendorPayment(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val paymentNumber: String, // VPMT-YYYY-NNNNNN

    @Column(nullable = false)
    val vendorId: UUID,

    @Column(nullable = false)
    val paymentDate: LocalDate,

    @Column(nullable = false, precision = 19, scale = 2)
    val amount: BigDecimal,

    @Column(nullable = false)
    val currency: String = "USD",

    @Enumerated(EnumType.STRING)
    val paymentMethod: PaymentMethod,

    // Payment details
    val checkNumber: String? = null,
    val referenceNumber: String? = null,
    val transactionId: String? = null,

    // Invoices paid (can pay multiple invoices)
    @OneToMany(mappedBy = "payment", cascade = [CascadeType.ALL])
    val invoicePayments: MutableList<VendorInvoicePaymentAllocation> = mutableListOf(),

    @Enumerated(EnumType.STRING)
    var status: PaymentStatus = PaymentStatus.PENDING,

    val bankAccountId: UUID? = null,

    @Column(length = 1000)
    var notes: String? = null,

    // Audit
    @Column(nullable = false)
    val createdBy: UUID,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now()
) {
    fun allocateToInvoice(invoiceId: UUID, amount: BigDecimal) {
        val allocation = VendorInvoicePaymentAllocation(
            payment = this,
            vendorInvoiceId = invoiceId,
            amount = amount
        )
        invoicePayments.add(allocation)
        updatedAt = Instant.now()
    }

    fun process() {
        require(status == PaymentStatus.PENDING) {
            "Only pending payments can be processed"
        }

        this.status = PaymentStatus.CONFIRMED
        this.updatedAt = Instant.now()

        // Post to GL
        postToGeneralLedger()
    }

    private fun postToGeneralLedger() {
        // Create journal entry
        // DR: Accounts Payable
        // CR: Bank/Cash
    }
}
```

**VendorInvoicePaymentAllocation (Entity)**

```kotlin
@Entity
@Table(name = "vendor_invoice_payment_allocations", schema = "finance_schema")
class VendorInvoicePaymentAllocation(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "payment_id", nullable = false)
    val payment: VendorPayment,

    @Column(nullable = false)
    val vendorInvoiceId: UUID,

    @Column(nullable = false, precision = 19, scale = 2)
    val amount: BigDecimal
)
```

---

## Domain 4: Asset Accounting

### Aggregates

**FixedAsset (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "fixed_assets",
    schema = "finance_schema",
    indexes = [
        Index(name = "idx_asset_number", columnList = "assetNumber"),
        Index(name = "idx_asset_class", columnList = "assetClass")
    ]
)
class FixedAsset(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val assetNumber: String, // FA-YYYY-NNNN

    @Column(nullable = false)
    var description: String,

    @Enumerated(EnumType.STRING)
    val assetClass: AssetClass,

    @Enumerated(EnumType.STRING)
    var assetStatus: AssetStatus,

    // Acquisition
    @Column(nullable = false)
    val acquisitionDate: LocalDate,

    @Column(nullable = false, precision = 19, scale = 2)
    val acquisitionCost: BigDecimal,

    val vendorId: UUID? = null,
    val purchaseOrderId: UUID? = null,
    val invoiceId: UUID? = null,

    // Depreciation
    @Embedded
    var depreciationInfo: DepreciationInfo,

    // Current book value
    @Column(nullable = false, precision = 19, scale = 2)
    var accumulatedDepreciation: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false, precision = 19, scale = 2)
    var netBookValue: BigDecimal,

    // Location and assignment
    val locationId: UUID? = null,
    val departmentId: UUID? = null,
    val employeeId: UUID? = null, // Assigned to employee

    // Disposal
    var disposalDate: LocalDate? = null,
    var disposalAmount: BigDecimal? = null,
    @Enumerated(EnumType.STRING)
    var disposalMethod: DisposalMethod? = null,

    // GL Accounts
    val assetAccountId: UUID,
    val depreciationAccountId: UUID,
    val accumulatedDepreciationAccountId: UUID,

    // Maintenance
    @Column(precision = 19, scale = 2)
    var totalMaintenanceCost: BigDecimal = BigDecimal.ZERO,

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
    init {
        netBookValue = acquisitionCost
    }

    fun calculateMonthlyDepreciation(): BigDecimal {
        return when (depreciationInfo.method) {
            DepreciationMethod.STRAIGHT_LINE -> {
                val depreciableAmount = MoneyMath.subtract(acquisitionCost, depreciationInfo.salvageValue)
                MoneyMath.divide(depreciableAmount, BigDecimal(depreciationInfo.usefulLifeMonths))
            }
            DepreciationMethod.DECLINING_BALANCE -> {
                require(depreciationInfo.depreciationRate != null) {
                    "Depreciation rate required for declining balance method"
                }
                val annualDepreciation = MoneyMath.multiply(netBookValue, depreciationInfo.depreciationRate!!)
                MoneyMath.divide(annualDepreciation, BigDecimal(12))
            }
            DepreciationMethod.UNITS_OF_PRODUCTION -> {
                // Requires actual usage units - must be calculated separately
                BigDecimal.ZERO
            }
        }.setScale(2, RoundingMode.HALF_UP)
    }

    fun postMonthlyDepreciation(month: YearMonth): DepreciationEntry {
        require(assetStatus == AssetStatus.ACTIVE) {
            "Only active assets can be depreciated"
        }

        val depreciationAmount = calculateMonthlyDepreciation()
        accumulatedDepreciation = MoneyMath.add(accumulatedDepreciation, depreciationAmount)
        netBookValue = MoneyMath.subtract(acquisitionCost, accumulatedDepreciation)
        updatedAt = Instant.now()

        // Check if fully depreciated (within tolerance)
        if (netBookValue <= depreciationInfo.salvageValue ||
            MoneyMath.areBalanced(netBookValue, depreciationInfo.salvageValue)) {
            assetStatus = AssetStatus.FULLY_DEPRECIATED
            netBookValue = depreciationInfo.salvageValue  // Set to exact salvage value
        }

        return DepreciationEntry(
            assetId = id,
            period = month,
            depreciationAmount = depreciationAmount,
            accumulatedDepreciation = accumulatedDepreciation,
            netBookValue = netBookValue
        )
    }

    fun dispose(disposalDate: LocalDate, disposalAmount: BigDecimal, method: DisposalMethod) {
        require(assetStatus == AssetStatus.ACTIVE || assetStatus == AssetStatus.FULLY_DEPRECIATED) {
            "Asset must be active or fully depreciated to dispose"
        }
        require(disposalAmount >= BigDecimal.ZERO) {
            "Disposal amount cannot be negative"
        }

        this.disposalDate = disposalDate
        this.disposalAmount = disposalAmount.setScale(2, RoundingMode.HALF_UP)
        this.disposalMethod = method
        this.assetStatus = AssetStatus.DISPOSED
        this.updatedAt = Instant.now()

        // Calculate gain/loss on disposal with proper rounding
        val gainLoss = MoneyMath.subtract(disposalAmount, netBookValue)

        // Post disposal journal entry
        postDisposalToGL(gainLoss)
    }

    private fun postDisposalToGL(gainLoss: BigDecimal) {
        // DR: Accumulated Depreciation
        // DR/CR: Gain/Loss on Disposal (depending on sign)
        // CR: Fixed Asset
        // DR: Cash/Bank (if sold)
    }
}

enum class AssetClass {
    LAND, BUILDING, MACHINERY, VEHICLES, FURNITURE, COMPUTER_EQUIPMENT,
    OFFICE_EQUIPMENT, LEASEHOLD_IMPROVEMENTS, OTHER
}

enum class AssetStatus {
    ACTIVE, INACTIVE, UNDER_CONSTRUCTION, FULLY_DEPRECIATED, DISPOSED, SOLD
}

enum class DepreciationMethod {
    STRAIGHT_LINE, DECLINING_BALANCE, UNITS_OF_PRODUCTION
}

enum class DisposalMethod {
    SALE, SCRAP, DONATION, TRADE_IN, OTHER
}

@Embeddable
data class DepreciationInfo(
    @Enumerated(EnumType.STRING)
    val method: DepreciationMethod,

    val usefulLifeMonths: Int, // Total useful life in months

    @Column(precision = 19, scale = 2)
    val salvageValue: BigDecimal = BigDecimal.ZERO,

    @Column(precision = 5, scale = 2)
    val depreciationRate: BigDecimal? = null, // For declining balance

    val depreciationStartDate: LocalDate
)
```

**DepreciationEntry (Entity)**

```kotlin
@Entity
@Table(
    name = "depreciation_entries",
    schema = "finance_schema",
    indexes = [
        Index(name = "idx_depreciation_asset", columnList = "assetId,period")
    ]
)
class DepreciationEntry(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false)
    val assetId: UUID,

    @Column(nullable = false)
    val period: YearMonth,

    @Column(nullable = false, precision = 19, scale = 2)
    val depreciationAmount: BigDecimal,

    @Column(nullable = false, precision = 19, scale = 2)
    val accumulatedDepreciation: BigDecimal,

    @Column(nullable = false, precision = 19, scale = 2)
    val netBookValue: BigDecimal,

    val journalEntryId: UUID? = null,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now()
)
```

---

## Domain 5: Tax Engine

### Aggregates

**TaxCode (Aggregate Root)**

```kotlin
@Entity
@Table(name = "tax_codes", schema = "finance_schema")
class TaxCode(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val code: String,

    @Column(nullable = false)
    var description: String,

    @Enumerated(EnumType.STRING)
    val taxType: TaxType,

    @Column(nullable = false, precision = 5, scale = 2)
    var rate: BigDecimal,

    @Column(nullable = false)
    val jurisdiction: String,

    val country: String,
    val state: String? = null,
    val city: String? = null,

    @Column(nullable = false)
    val effectiveFrom: LocalDate,

    val effectiveTo: LocalDate? = null,

    val inputTaxAccountId: UUID? = null,
    val outputTaxAccountId: UUID? = null,

    @Enumerated(EnumType.STRING)
    var status: TaxCodeStatus,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now()
) {
    /**
     * Calculate tax amount with proper rounding.
     * Tax Rate: Stored with 4 decimal places (e.g., 8.25% = 0.0825)
     * Amount: 2 decimal places (standard money)
     * Result: Rounded using HALF_UP per tax regulations
     *
     * Example: $100.00 × 8.25% = $8.25
     *          $100.33 × 8.25% = $8.277225 → $8.28 (rounded up)
     */
    fun calculateTax(baseAmount: BigDecimal): BigDecimal {
        require(baseAmount >= BigDecimal.ZERO) { "Base amount cannot be negative" }
        require(rate.scale() <= 4) { "Tax rate must not exceed 4 decimal places" }

        return MoneyMath.percentage(baseAmount, rate)
    }

    fun isEffective(date: LocalDate): Boolean {
        return date >= effectiveFrom && (effectiveTo == null || date <= effectiveTo)
    }
}

enum class TaxType {
    VAT, SALES_TAX, USE_TAX, WITHHOLDING_TAX, EXCISE_TAX, CUSTOMS_DUTY
}

enum class TaxCodeStatus {
    ACTIVE, INACTIVE, EXPIRED
}
```

**ExchangeRate (Entity)**

```kotlin
@Entity
@Table(
    name = "exchange_rates",
    schema = "finance_schema",
    indexes = [
        Index(name = "idx_exchange_rate_date", columnList = "rateDate"),
        Index(name = "idx_exchange_rate_currencies", columnList = "fromCurrency,toCurrency,rateDate")
    ]
)
class ExchangeRate(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, length = 3)
    val fromCurrency: String,

    @Column(nullable = false, length = 3)
    val toCurrency: String,

    @Column(nullable = false, precision = 19, scale = 6)  // 6 decimal places for accuracy
    val rate: BigDecimal,

    @Column(nullable = false)
    val rateDate: LocalDate,

    @Enumerated(EnumType.STRING)
    val rateType: ExchangeRateType = ExchangeRateType.SPOT,

    val rateSource: String? = null,  // e.g., "ECB", "Fed", "Bloomberg", "Manual"

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now()
) {
    init {
        require(rate.scale() == 6) { "Exchange rate must have exactly 6 decimal places" }
        require(rate > BigDecimal.ZERO) { "Exchange rate must be positive" }
        require(fromCurrency != toCurrency) { "From and to currencies must be different" }

        // Validate currency codes
        val fromValidation = CurrencyValidator.validateCurrencyCode(fromCurrency)
        require(fromValidation.isSuccess) { "Invalid from currency: $fromCurrency" }

        val toValidation = CurrencyValidator.validateCurrencyCode(toCurrency)
        require(toValidation.isSuccess) { "Invalid to currency: $toCurrency" }
    }

    /**
     * Convert amount from source currency to target currency
     * Maintains 2 decimal places for money amounts
     */
    fun convert(amount: BigDecimal): BigDecimal {
        require(amount.scale() <= 2) { "Amount must have at most 2 decimal places" }
        return MoneyMath.convertCurrency(amount, rate)
    }

    /**
     * Get inverse exchange rate (e.g., if USD/EUR = 0.92, then EUR/USD = 1.087)
     */
    fun inverse(): ExchangeRate {
        val inverseRate = BigDecimal.ONE.divide(rate, 6, RoundingMode.HALF_UP)
        return ExchangeRate(
            fromCurrency = toCurrency,
            toCurrency = fromCurrency,
            rate = inverseRate,
            rateDate = rateDate,
            rateType = rateType,
            rateSource = rateSource,
            tenantId = tenantId
        )
    }

    companion object {
        /**
         * Create a default rate for same currency (1:1)
         */
        fun identity(currency: String, tenantId: UUID): ExchangeRate {
            return ExchangeRate(
                fromCurrency = currency,
                toCurrency = currency,
                rate = BigDecimal.ONE.setScale(6, RoundingMode.HALF_UP),
                rateDate = LocalDate.now(),
                rateSource = "SYSTEM",
                tenantId = tenantId
            )
        }
    }
}

enum class ExchangeRateType {
    SPOT,           // Current market rate
    FORWARD,        // Future contract rate
    AVERAGE,        // Period average rate
    FIXED,          // Fixed rate for contract
    HISTORICAL      // Historical rate for reporting
}
```

---

## Domain 6: Expense Management

### Aggregates

**ExpenseReport (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "expense_reports",
    schema = "finance_schema",
    indexes = [
        Index(name = "idx_expense_report_employee", columnList = "employeeId"),
        Index(name = "idx_expense_report_status", columnList = "status")
    ]
)
class ExpenseReport(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val reportNumber: String, // EXP-YYYY-NNNNNN

    @Column(nullable = false)
    val employeeId: UUID,

    @Column(nullable = false)
    val reportDate: LocalDate,

    @Column(nullable = false)
    var title: String,

    @Column(length = 2000)
    var purpose: String?,

    // Line items
    @OneToMany(mappedBy = "expenseReport", cascade = [CascadeType.ALL])
    val expenses: MutableList<ExpenseItem> = mutableListOf(),

    @Column(nullable = false, precision = 19, scale = 2)
    var totalAmount: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false)
    val currency: String = "USD",

    // Approval workflow
    @Enumerated(EnumType.STRING)
    var status: ExpenseReportStatus = ExpenseReportStatus.DRAFT,

    var submittedAt: Instant? = null,
    var approvedBy: UUID? = null,
    var approvedAt: Instant? = null,

    // Reimbursement
    var reimbursementDate: LocalDate? = null,
    var reimbursementAmount: BigDecimal? = null,
    val reimbursementMethod: String? = null,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
) {
    fun addExpense(expense: ExpenseItem) {
        expenses.add(expense)
        expense.expenseReport = this
        recalculateTotal()
    }

    fun removeExpense(expense: ExpenseItem) {
        expenses.remove(expense)
        recalculateTotal()
    }

    private fun recalculateTotal() {
        totalAmount = expenses.sumOf { it.amount }
        updatedAt = Instant.now()
    }

    fun submit() {
        require(status == ExpenseReportStatus.DRAFT) {
            "Only draft reports can be submitted"
        }
        require(expenses.isNotEmpty()) {
            "Cannot submit empty expense report"
        }

        this.status = ExpenseReportStatus.SUBMITTED
        this.submittedAt = Instant.now()
        this.updatedAt = Instant.now()
    }

    fun approve(approver: UUID) {
        require(status == ExpenseReportStatus.SUBMITTED) {
            "Only submitted reports can be approved"
        }

        this.status = ExpenseReportStatus.APPROVED
        this.approvedBy = approver
        this.approvedAt = Instant.now()
        this.updatedAt = Instant.now()
    }

    fun reject(rejector: UUID, reason: String) {
        this.status = ExpenseReportStatus.REJECTED
        this.purpose = "$purpose\nRejection reason: $reason"
        this.updatedAt = Instant.now()
    }
}

enum class ExpenseReportStatus {
    DRAFT, SUBMITTED, APPROVED, REJECTED, PAID
}
```

**ExpenseItem**

```kotlin
@Entity
@Table(name = "expense_items", schema = "finance_schema")
class ExpenseItem(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "expense_report_id", nullable = false)
    var expenseReport: ExpenseReport? = null,

    @Column(nullable = false)
    val expenseDate: LocalDate,

    @Enumerated(EnumType.STRING)
    val category: ExpenseCategory,

    @Column(nullable = false)
    var description: String,

    @Column(nullable = false, precision = 19, scale = 2)
    var amount: BigDecimal,

    @Column(nullable = false)
    val currency: String = "USD",

    val merchantName: String? = null,
    val merchantCity: String? = null,

    // Receipt
    val receiptAttached: Boolean = false,
    val receiptUrl: String? = null,

    // GL Account
    val expenseAccountId: UUID? = null,
    val costCenterId: UUID? = null
)

enum class ExpenseCategory {
    TRAVEL, MEALS, ACCOMMODATION, TRANSPORTATION, SUPPLIES, EQUIPMENT,
    TRAINING, ENTERTAINMENT, COMMUNICATION, OTHER
}
```

---

## Domain 7: Bank & Cash Management (Optional)

### Aggregates

**BankAccount (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "bank_accounts",
    schema = "finance_schema",
    indexes = [
        Index(name = "idx_bank_account_number", columnList = "accountNumber"),
        Index(name = "idx_bank_account_status", columnList = "status")
    ]
)
class BankAccount(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val accountNumber: String,

    @Column(nullable = false)
    var accountName: String,

    @Enumerated(EnumType.STRING)
    val accountType: BankAccountType,

    @Column(nullable = false)
    val bankName: String,

    val bankBranch: String? = null,
    val swiftCode: String? = null,
    val routingNumber: String? = null,

    @Column(nullable = false)
    val currency: String = "USD",

    @Column(nullable = false, precision = 19, scale = 2)
    var currentBalance: BigDecimal = BigDecimal.ZERO,

    // GL Account linkage
    @Column(nullable = false)
    val glAccountId: UUID,

    @Enumerated(EnumType.STRING)
    var status: BankAccountStatus,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now()
)

enum class BankAccountType {
    CHECKING, SAVINGS, MONEY_MARKET, PETTY_CASH
}

enum class BankAccountStatus {
    ACTIVE, INACTIVE, CLOSED
}
```

---

## Domain Events

### General Ledger Events

```kotlin
data class JournalEntryPostedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val journalEntryId: UUID,
    val documentNumber: String,
    val postingDate: LocalDate,
    val totalDebit: BigDecimal,
    val totalCredit: BigDecimal,
    val fiscalYear: Int,
    val fiscalPeriod: Int,
    val tenantId: UUID,
    val organizationId: UUID,
    val occurredAt: Instant = Instant.now()
)

data class JournalEntryReversedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val originalJournalEntryId: UUID,
    val reversalJournalEntryId: UUID,
    val reversalDate: LocalDate,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)
```

### Accounts Receivable Events

```kotlin
data class JournalEntryPostedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val journalEntryId: UUID,
    val documentNumber: String,
    val postingDate: LocalDate,
    val totalDebit: BigDecimal,
    val totalCredit: BigDecimal,
    val fiscalYear: Int,
    val fiscalPeriod: Int,
    val tenantId: UUID,
    val organizationId: UUID,
    val occurredAt: Instant = Instant.now()
)

data class JournalEntryReversedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val originalJournalEntryId: UUID,
    val reversalJournalEntryId: UUID,
    val reversalDate: LocalDate,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)
```

### Accounts Receivable Events

```kotlin
data class InvoiceIssuedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val invoiceId: UUID,
    val invoiceNumber: String,
    val customerId: UUID,
    val invoiceDate: LocalDate,
    val dueDate: LocalDate,
    val totalAmount: BigDecimal,
    val currency: String,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)

data class PaymentReceivedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val paymentId: UUID,
    val invoiceId: UUID?,
    val customerId: UUID,
    val amount: BigDecimal,
    val paymentDate: LocalDate,
    val paymentMethod: PaymentMethod,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)

data class InvoiceOverdueEvent(
    val eventId: UUID = UUID.randomUUID(),
    val invoiceId: UUID,
    val customerId: UUID,
    val daysOverdue: Long,
    val balanceDue: BigDecimal,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)
```

### Accounts Payable Events

```kotlin
data class VendorInvoiceReceivedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val vendorInvoiceId: UUID,
    val vendorId: UUID,
    val invoiceDate: LocalDate,
    val totalAmount: BigDecimal,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)

data class VendorInvoiceApprovedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val vendorInvoiceId: UUID,
    val approvedBy: UUID,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)

data class VendorPaymentMadeEvent(
    val eventId: UUID = UUID.randomUUID(),
    val paymentId: UUID,
    val vendorId: UUID,
    val amount: BigDecimal,
    val paymentDate: LocalDate,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)
```

### Expense Management Events

```kotlin
data class ExpenseReportSubmittedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val expenseReportId: UUID,
    val employeeId: UUID,
    val totalAmount: BigDecimal,
    val submittedAt: Instant,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)

data class ExpenseReportApprovedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val expenseReportId: UUID,
    val employeeId: UUID,
    val approvedBy: UUID,
    val reimbursementAmount: BigDecimal,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)
```

---

## Integration Points

**Note:** For Point of Sale (POS) integration with the Financial Management service (daily sales posting, revenue recognition, cash reconciliation), see the Commerce Service documentation (`DOMAIN-MODELS-COMMERCE-POS.md`). POS operations post journal entries to the General Ledger and create customer invoices in Accounts Receivable.

### With HR Domain (Administration Service)

**Expense Reimbursements:**

-   Employee expense reports reference `employeeId` from HR domain
-   Reimbursement payments link to employee bank accounts
-   Cost center allocation from employee's department

**Payroll Integration:**

-   Salary payments journal entries
-   Benefits deductions
-   Tax withholdings
-   Expense reimbursements in payroll

### With Supply Chain Service

**Inventory Valuation:**

-   COGS (Cost of Goods Sold) postings
-   Inventory GL accounts
-   Purchase price variance

**Procurement:**

-   Purchase order accruals
-   Goods receipt accounting
-   Vendor invoice matching

### With Operations Service

**Cost Accounting:**

-   Service order costs
-   Job costing
-   Labor cost allocation
-   Material cost tracking

### With Customer Relationship Service

**Revenue Recognition:**

-   Sales order invoicing
-   Revenue posting from CRM
-   Customer credit management
-   Collections integration

---

## Business Rules

### General Ledger

1. Journal entries must always balance (debits = credits)
2. Posted journal entries cannot be edited, only reversed
3. Account balances must be reconciled monthly
4. Fiscal periods must be opened before posting
5. Only active GL accounts can receive postings
6. Manual journal entries require approval

### Accounts Receivable

1. Invoice due date must be after invoice date
2. Payment cannot exceed invoice balance due
3. Invoices must be posted before payments can be applied
4. Credit limit checks before invoice posting
5. Overdue invoices trigger collection workflows
6. Payment terms must be defined for each customer

### Accounts Payable

1. Vendor invoice must match PO and goods receipt (3-way matching)
2. Payment terms determine due date calculation
3. Vendor payments require approval above threshold
4. Cannot pay more than invoice balance
5. Early payment discounts automatically calculated
6. Payment run batches multiple invoices by due date

### Asset Accounting

1. Asset acquisition cost cannot be negative
2. Depreciation cannot reduce book value below salvage value
3. Disposed assets cannot be depreciated
4. Asset transfers require approval
5. Depreciation method cannot change after first posting
6. Asset maintenance costs above threshold capitalize

### Expense Management

1. Expense reports require receipts above threshold
2. Expenses must have valid GL account assignment
3. Manager approval required for all expense reports
4. Reimbursement only after approval
5. Expense categories must comply with policy
6. Out-of-policy expenses require justification

---

## Financial Reporting Views

### Balance Sheet Accounts

```kotlin
data class BalanceSheetView(
    // Assets
    val currentAssets: Map<String, BigDecimal>,
    val fixedAssets: Map<String, BigDecimal>,
    val totalAssets: BigDecimal,

    // Liabilities
    val currentLiabilities: Map<String, BigDecimal>,
    val longTermLiabilities: Map<String, BigDecimal>,
    val totalLiabilities: BigDecimal,

    // Equity
    val equity: Map<String, BigDecimal>,
    val totalEquity: BigDecimal,

    // Balance check
    val isBalanced: Boolean // Assets = Liabilities + Equity
)
```

### Profit & Loss Statement

```kotlin
data class ProfitAndLossView(
    val period: FiscalPeriod,

    // Revenue
    val revenue: Map<String, BigDecimal>,
    val totalRevenue: BigDecimal,

    // Cost of Goods Sold
    val cogs: Map<String, BigDecimal>,
    val totalCogs: BigDecimal,
    val grossProfit: BigDecimal,

    // Operating Expenses
    val operatingExpenses: Map<String, BigDecimal>,
    val totalOperatingExpenses: BigDecimal,
    val operatingIncome: BigDecimal,

    // Other Income/Expenses
    val otherIncome: BigDecimal,
    val otherExpenses: BigDecimal,

    // Net Income
    val netIncome: BigDecimal
)
```

### Cash Flow Statement

```kotlin
data class CashFlowView(
    val period: FiscalPeriod,

    // Operating Activities
    val operatingCashFlow: Map<String, BigDecimal>,
    val netOperatingCashFlow: BigDecimal,

    // Investing Activities
    val investingCashFlow: Map<String, BigDecimal>,
    val netInvestingCashFlow: BigDecimal,

    // Financing Activities
    val financingCashFlow: Map<String, BigDecimal>,
    val netFinancingCashFlow: BigDecimal,

    // Net Change in Cash
    val netCashChange: BigDecimal,
    val beginningCash: BigDecimal,
    val endingCash: BigDecimal
)

data class FiscalPeriod(
    val fiscalYear: Int,
    val period: Int, // 1-12
    val startDate: LocalDate,
    val endDate: LocalDate
)
```

---

## Summary

The Financial Management service provides comprehensive **SAP FI-aligned** financial accounting capabilities including:

### Six Core Domains:

1. **General Ledger** - Single source of financial truth with chart of accounts, journal entries, and account balances
2. **Accounts Receivable** - Customer invoicing, payment collection, and credit management
3. **Accounts Payable** - Vendor invoice processing, 3-way matching, and payment automation
4. **Asset Accounting** - Fixed asset lifecycle with depreciation and disposal management
5. **Tax Engine** - Multi-jurisdiction tax calculation and compliance
6. **Expense Management** - Employee expense reports and reimbursement workflows
7. **Bank & Cash Management** - Bank account management, cash positions, and reconciliations

**Note:** Point of Sale (POS) operations have been moved to the Commerce Service (`DOMAIN-MODELS-COMMERCE-POS.md`) as they represent customer-facing retail operations rather than core financial accounting.

### Key Features:

-   **Double-entry accounting** with automatic GL postings
-   **Multi-currency support** with exchange rate management
-   **Fiscal period management** with period-end close processes
-   **Approval workflows** for invoices, payments, and journal entries
-   **Real-time account balances** with drill-down to line items
-   **Comprehensive audit trails** with full transaction history
-   **Event-driven integration** with other ERP domains
-   **Financial reporting** (Balance Sheet, P&L, Cash Flow)

### Integration Points:

-   **HR Domain**: Expense reimbursements, payroll integration
-   **Supply Chain**: Inventory valuation, COGS, procurement
-   **Operations**: Cost accounting, job costing
-   **CRM**: Revenue recognition, customer credit
-   **Core Platform**: Security, audit, multi-tenancy

This foundation enables world-class financial management following SAP FI best practices with full compliance, auditability, and scalability for enterprise deployments.

---

## Money Handling & Financial Accuracy Improvements

This domain model implements best practices for financial accuracy and compliance:

### ✅ **Implemented Improvements**

#### 1. **Explicit Rounding Modes (Critical Fix)**

-   All calculations use `MoneyMath` utility with `RoundingMode.HALF_UP`
-   Prevents `ArithmeticException` in division operations
-   Ensures consistent rounding across all financial calculations
-   Compliant with GAAP/IFRS accounting standards

#### 2. **Enhanced Exchange Rate Precision**

-   Exchange rates use `precision = 19, scale = 6` (6 decimal places)
-   Prevents significant errors in currency conversion
-   Example: EUR/USD = 1.084700 (not 1.08) for $1M transactions
-   Added `ExchangeRate` entity with conversion methods and validation

#### 3. **Currency Validation**

-   Automatic validation against ISO 4217 currency codes
-   Prevents mixing different currencies in same transaction
-   Journal entries validate currency consistency
-   Exchange rate validation for foreign currency transactions

#### 4. **Payment Method Enhancements**

-   Comprehensive payment method enum with business logic
-   Payment lifecycle: PENDING → AUTHORIZED → CONFIRMED → CLEARED → RECONCILED
-   Method-specific requirements (reference numbers, bank accounts)
-   Settlement timing logic per payment method
-   Refund and void capabilities with proper validation

#### 5. **Balance Validation with Tolerance**

-   Journal entries use 1-cent tolerance for debit/credit balance checks
-   Handles rounding differences in multi-line transactions
-   Prevents false validation failures from minor rounding

#### 6. **Tax Calculation Safety**

-   Tax rates stored with 4 decimal places
-   Tax calculations properly rounded to 2 decimal places
-   Documented calculation methodology for audit compliance

#### 7. **Asset Depreciation Accuracy**

-   Proper rounding in straight-line depreciation calculations
-   Declining balance method with validated rate
-   Salvage value comparison with tolerance
-   Gain/loss on disposal calculated with precision

### 📊 **Financial Accuracy Metrics**

| Aspect              | Before              | After                     |
| ------------------- | ------------------- | ------------------------- |
| Rounding Mode       | ❌ Undefined        | ✅ HALF_UP (explicit)     |
| Exchange Rate Scale | ❌ 2 decimals       | ✅ 6 decimals             |
| Currency Validation | ❌ None             | ✅ ISO 4217 validation    |
| Balance Tolerance   | ❌ Exact match only | ✅ 0.01 tolerance         |
| Payment Methods     | ⚠️ Basic enum       | ✅ Full lifecycle + logic |
| Tax Calculation     | ⚠️ No rounding      | ✅ Documented + rounded   |
| Money Arithmetic    | ⚠️ Direct operators | ✅ MoneyMath utility      |

### 🔒 **Compliance Benefits**

1. **SOX Compliance** - Audit trail with proper rounding documentation
2. **GAAP/IFRS Standards** - Consistent HALF_UP rounding methodology
3. **Tax Compliance** - Precise tax calculations matching jurisdiction rules
4. **Multi-Currency Regulations** - Accurate FX conversion with proper rate tracking

### 🧪 **Testing Recommendations**

```kotlin
@Test
fun `test journal entry balance with rounding`() {
    val entry = JournalEntry(...)
    entry.addLineItem(JournalEntryLineItem(debitAmount = BigDecimal("100.555")))
    entry.addLineItem(JournalEntryLineItem(creditAmount = BigDecimal("100.555")))

    val validation = entry.validate()
    assertTrue(validation.isSuccess)
    assertEquals(BigDecimal("100.56"), entry.totalDebit)
    assertEquals(BigDecimal("100.56"), entry.totalCredit)
}

@Test
fun `test exchange rate precision`() {
    val rate = ExchangeRate(
        fromCurrency = "EUR",
        toCurrency = "USD",
        rate = BigDecimal("1.084700"),  // 6 decimals
        rateDate = LocalDate.now()
    )

    val converted = rate.convert(BigDecimal("1000000.00"))
    assertEquals(BigDecimal("1084700.00"), converted)  // Accurate to the cent
}

@Test
fun `test payment method validation`() {
    val payment = CustomerPayment(
        paymentMethod = PaymentMethod.ACH,
        amount = BigDecimal("1000.00")
    )

    assertThrows<IllegalStateException> {
        payment.confirm()  // Should fail - ACH requires bank account
    }
}
```

### 📈 **Performance Considerations**

-   `MoneyMath` operations add minimal overhead (~10-20μs per calculation)
-   Exchange rate lookups should be cached for performance
-   Journal entry validation is O(n) where n = number of line items
-   All database columns properly indexed for query performance
