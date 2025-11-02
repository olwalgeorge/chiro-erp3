# Customer & Client Account Management Architecture

## Executive Summary

ChiroERP implements a **strategic separation of concerns** between **Customer Master Data** (CRM) and **Customer Financial Accounts** (AR) following industry best practices from SAP and Oracle ERP systems.

### Key Architectural Decisions

1. **Customer Master Data** lives in **CRM Schema** (`crm_schema`) - Customer Relationship service
2. **Customer Financial Accounts** live in **Finance Schema** (`finance_schema`) - Financial Management service
3. **Integration** via UUID references and domain events
4. **Single Source of Truth**: CRM for customer profile, Finance for transactional data

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CUSTOMER RELATIONSHIP SERVICE                     │
│                        (crm_schema)                                  │
│                                                                      │
│  ┌────────────────────────────────────────────────────────┐        │
│  │  Customer (Aggregate Root)                             │        │
│  │  ─────────────────────────────                         │        │
│  │  - id: UUID                                            │        │
│  │  - customerNumber: String (CUST-YYYY-NNNNNN)          │        │
│  │  - personalInfo: PersonalInfo (name, dob, etc.)       │        │
│  │  - contactInfo: ContactInfo (email, phone, etc.)      │        │
│  │  - customerType: CustomerType (B2B, B2C, B2G)         │        │
│  │  - industryType: IndustryType (20+ industries)        │        │
│  │  - status: CustomerStatus (ACTIVE, SUSPENDED, etc.)   │        │
│  │  - segment: CustomerSegment (ENTERPRISE, SMB, VIP)    │        │
│  │  - creditInfo: CreditInfo (limits, balance)           │        │
│  │  - tags: Set<String> (vip, regulated, etc.)           │        │
│  │  - customAttributes: JSONB (industry-specific)        │        │
│  │  - metadata: CustomerMetadata (tax, compliance)       │        │
│  └────────────────────────────────────────────────────────┘        │
│                          ↓ ↓ ↓                                      │
│                    DOMAIN EVENTS                                    │
│  - CustomerCreated                                                  │
│  - CustomerUpdated                                                  │
│  - CustomerStatusChanged                                            │
│  - CreditLimitChanged                                               │
└─────────────────────────────────────────────────────────────────────┘
                            ↓ (Kafka Events)
                            ↓
┌─────────────────────────────────────────────────────────────────────┐
│                  FINANCIAL MANAGEMENT SERVICE                        │
│                      (finance_schema)                                │
│                                                                      │
│  ┌────────────────────────────────────────────────────────┐        │
│  │  CustomerAccount (Aggregate Root)                      │        │
│  │  ────────────────────────────────                      │        │
│  │  - id: UUID                                            │        │
│  │  - customerId: UUID (references CRM.Customer.id)      │        │
│  │  - accountNumber: String (AR-YYYY-NNNNNN)             │        │
│  │  - accountType: AccountType (STANDARD, PREPAID, etc.) │        │
│  │  - currency: String (ISO 4217)                        │        │
│  │  - creditLimit: BigDecimal(19,2)                      │        │
│  │  - creditUsed: BigDecimal(19,2)                       │        │
│  │  - availableCredit: BigDecimal(19,2)                  │        │
│  │  - totalOutstanding: BigDecimal(19,2)                 │        │
│  │  - overdueBalance: BigDecimal(19,2)                   │        │
│  │  - currentBalance: BigDecimal(19,2)                   │        │
│  │  - paymentTerms: PaymentTerms (NET30, NET60, etc.)   │        │
│  │  - creditStatus: CreditStatus (GOOD, HOLD, etc.)     │        │
│  │  - lastPaymentDate: Instant?                          │        │
│  │  - lastInvoiceDate: Instant?                          │        │
│  │  - daysSalesOutstanding: Int (DSO)                    │        │
│  │  - agingBuckets: AgingInfo (0-30, 31-60, 61-90, 90+) │        │
│  └────────────────────────────────────────────────────────┘        │
│                                                                      │
│  ┌────────────────────────────────────────────────────────┐        │
│  │  CustomerInvoice                                       │        │
│  │  ────────────────────────────────────────             │        │
│  │  - customerId: UUID                                    │        │
│  │  - customerAccountId: UUID                             │        │
│  │  - totalAmount, balance, status                        │        │
│  └────────────────────────────────────────────────────────┘        │
│                                                                      │
│  ┌────────────────────────────────────────────────────────┐        │
│  │  CustomerPayment                                       │        │
│  │  ────────────────────────────────────────             │        │
│  │  - customerId: UUID                                    │        │
│  │  - customerAccountId: UUID                             │        │
│  │  - amount, status, paymentMethod                       │        │
│  └────────────────────────────────────────────────────────┘        │
│                                                                      │
│  ┌────────────────────────────────────────────────────────┐        │
│  │  CustomerStatement (Read Model)                        │        │
│  │  ────────────────────────────────────────────         │        │
│  │  - period, transactions, aging, balance                │        │
│  └────────────────────────────────────────────────────────┘        │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Domain Boundaries

### Customer Relationship Service (`crm_schema`)

**Responsibility**: Customer identity, profile, relationship management

**Data Ownership**:

-   Customer master data (name, contact, company)
-   Customer classification (type, industry, segment)
-   Customer lifecycle (status, tags, preferences)
-   Basic credit information (for UI/business logic)
-   Custom attributes (industry-specific data)

**Business Operations**:

-   Customer onboarding
-   Profile updates
-   Segmentation and classification
-   Relationship tracking
-   Lead/Opportunity management
-   Contact management
-   Provider/Vendor management

**Does NOT Own**:

-   Invoices, payments, transactions
-   Detailed aging reports
-   Statement generation
-   Credit hold/release workflows
-   Day Sales Outstanding calculations

---

### Financial Management Service (`finance_schema`)

**Responsibility**: Accounts Receivable, financial transactions, credit management

**Data Ownership**:

-   CustomerAccount (AR account details)
-   CustomerInvoice (invoices and billing)
-   CustomerPayment (payment processing)
-   Aging information (30/60/90 day buckets)
-   Credit status and holds
-   Payment terms and schedules
-   Financial statements

**Business Operations**:

-   Invoice generation
-   Payment processing and reconciliation
-   Credit limit enforcement
-   Credit hold/release
-   Aging report generation
-   Statement generation
-   Collections workflow
-   Bad debt write-offs
-   Revenue recognition

**Does NOT Own**:

-   Customer profile information
-   Customer contact details
-   Industry classifications
-   Lead/Opportunity data

---

## Key Entities

### 1. Customer (CRM Domain)

```kotlin
@Entity
@Table(name = "customers", schema = "crm_schema")
class Customer(
    @Id val id: UUID = UUID.randomUUID(),

    // Identification
    val customerNumber: String, // CUST-2024-000001

    // Profile
    @Embedded var personalInfo: PersonalInfo,
    @Embedded var contactInfo: ContactInfo,

    // Classification
    var customerType: CustomerType, // B2B, B2C, B2G
    var industryType: IndustryType?, // HEALTHCARE, MANUFACTURING, etc.
    var companySize: CompanySize?,

    // Lifecycle
    var status: CustomerStatus, // ACTIVE, SUSPENDED, INACTIVE, CHURNED
    var segment: CustomerSegment, // ENTERPRISE, SMB, CONSUMER, VIP

    // Company (for B2B/B2G)
    var companyName: String?,
    var companyTaxId: String?,

    // Basic Credit Info (for UI/validation)
    @Embedded var creditInfo: CreditInfo,

    // Preferences
    @Embedded var preferences: CustomerPreferences,

    // Extensibility
    var customAttributes: MutableMap<String, Any>?,
    var metadata: CustomerMetadata?,
    var tags: MutableSet<String> = mutableSetOf(),

    // Multi-tenancy
    val tenantId: UUID,
    val createdAt: Instant = Instant.now(),
    var updatedAt: Instant = Instant.now(),
    val createdBy: UUID,
    var updatedBy: UUID?,

    @Version var version: Long = 0
) {
    // Business methods
    fun activate(userId: UUID)
    fun suspend(userId: UUID, reason: String)
    fun deactivate(userId: UUID)
    fun increaseCreditLimit(amount: BigDecimal, approvedBy: UUID)
    fun promoteToVIP(userId: UUID)
    fun addTag(tag: String)
    fun setCustomAttribute(key: String, value: Any)
}

// Value Objects
data class PersonalInfo(
    val firstName: String,
    val lastName: String,
    val middleName: String? = null,
    val title: String? = null,
    val suffix: String? = null,
    val dateOfBirth: LocalDate? = null,
    val nationality: String? = null
)

data class ContactInfo(
    val primaryEmail: String,
    val secondaryEmail: String? = null,
    val primaryPhone: String,
    val secondaryPhone: String? = null,
    val mobilePhone: String? = null,
    val fax: String? = null,
    val website: String? = null,
    val preferredContactMethod: ContactMethod = ContactMethod.EMAIL
)

data class CreditInfo(
    val creditLimit: BigDecimal = BigDecimal.ZERO,
    val availableCredit: BigDecimal = BigDecimal.ZERO,
    val creditRating: String? = null,
    val paymentTerms: String? = null
) {
    fun increaseLimit(amount: BigDecimal): CreditInfo
    fun decreaseLimit(amount: BigDecimal): CreditInfo
    fun consumeCredit(amount: BigDecimal): CreditInfo
    fun releaseCredit(amount: BigDecimal): CreditInfo
}

// Enums
enum class CustomerType {
    B2B,        // Business-to-Business
    B2C,        // Business-to-Consumer
    B2G,        // Business-to-Government
    PARTNER,    // Strategic Partner
    RESELLER,   // Reseller/Distributor
    INTERNAL    // Internal customer
}

enum class CustomerStatus {
    PROSPECT,   // Potential customer
    ACTIVE,     // Active customer
    SUSPENDED,  // Temporarily suspended
    INACTIVE,   // Inactive but can be reactivated
    CHURNED,    // Lost customer
    BLOCKED     // Permanently blocked
}

enum class CustomerSegment {
    ENTERPRISE, // Large enterprise (1000+ employees)
    MID_MARKET, // Mid-market (100-999 employees)
    SMB,        // Small-medium business (10-99 employees)
    MICRO,      // Micro business (1-9 employees)
    CONSUMER,   // Individual consumer
    VIP,        // VIP customer
    GOVERNMENT, // Government entity
    NON_PROFIT  // Non-profit organization
}

enum class IndustryType {
    HEALTHCARE, PHARMACEUTICALS, MEDICAL_DEVICES,
    MANUFACTURING, AUTOMOTIVE, AEROSPACE,
    FINANCIAL_SERVICES, BANKING, INSURANCE,
    TECHNOLOGY, SOFTWARE, TELECOMMUNICATIONS,
    RETAIL, ECOMMERCE, WHOLESALE,
    GOVERNMENT, DEFENSE, PUBLIC_SECTOR,
    EDUCATION, RESEARCH,
    ENERGY, UTILITIES,
    CONSTRUCTION, REAL_ESTATE,
    AGRICULTURE, FOOD_BEVERAGE,
    TRANSPORTATION, LOGISTICS,
    HOSPITALITY, TOURISM,
    MEDIA, ENTERTAINMENT,
    OTHER
}
```

---

### 2. CustomerAccount (Financial Domain)

```kotlin
@Entity
@Table(
    name = "customer_accounts",
    schema = "finance_schema",
    indexes = [
        Index(name = "idx_customer_account_customer_id", columnList = "customerId"),
        Index(name = "idx_customer_account_number", columnList = "accountNumber"),
        Index(name = "idx_customer_account_status", columnList = "creditStatus")
    ]
)
class CustomerAccount(
    @Id val id: UUID = UUID.randomUUID(),

    // ============================================
    // CUSTOMER REFERENCE (to CRM domain)
    // ============================================

    /**
     * Reference to Customer in CRM domain
     * This is the ONLY link to customer master data
     */
    @Column(nullable = false)
    val customerId: UUID,

    // ============================================
    // ACCOUNT IDENTIFICATION
    // ============================================

    @Column(nullable = false, unique = true)
    val accountNumber: String, // AR-YYYY-NNNNNN

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    var accountType: AccountType = AccountType.STANDARD,

    // ============================================
    // FINANCIAL DETAILS
    // ============================================

    @Column(nullable = false, length = 3)
    var currency: String = "USD", // ISO 4217

    // Credit Management
    @Column(precision = 19, scale = 2)
    var creditLimit: BigDecimal = BigDecimal.ZERO,

    @Column(precision = 19, scale = 2)
    var creditUsed: BigDecimal = BigDecimal.ZERO,

    @Column(precision = 19, scale = 2)
    var availableCredit: BigDecimal = BigDecimal.ZERO,

    // Balance Information
    @Column(precision = 19, scale = 2)
    var totalOutstanding: BigDecimal = BigDecimal.ZERO,

    @Column(precision = 19, scale = 2)
    var overdueBalance: BigDecimal = BigDecimal.ZERO,

    @Column(precision = 19, scale = 2)
    var currentBalance: BigDecimal = BigDecimal.ZERO,

    // ============================================
    // PAYMENT TERMS
    // ============================================

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    var paymentTerms: PaymentTerms = PaymentTerms.NET_30,

    @Column
    var discountPercentage: BigDecimal? = null, // Early payment discount

    @Column
    var discountDays: Int? = null, // Days for early payment discount

    // ============================================
    // CREDIT STATUS
    // ============================================

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    var creditStatus: CreditStatus = CreditStatus.GOOD_STANDING,

    @Column
    var creditHoldReason: String? = null,

    @Column
    var creditHoldDate: Instant? = null,

    @Column
    var creditHoldBy: UUID? = null,

    // ============================================
    // AGING INFORMATION
    // ============================================

    @Embedded
    var agingInfo: AgingInfo = AgingInfo(),

    @Column
    var daysSalesOutstanding: Int = 0, // DSO

    // ============================================
    // TRANSACTION HISTORY
    // ============================================

    @Column
    var lastInvoiceDate: Instant? = null,

    @Column
    var lastPaymentDate: Instant? = null,

    @Column(precision = 19, scale = 2)
    var lastPaymentAmount: BigDecimal? = null,

    @Column
    var totalInvoicesIssued: Int = 0,

    @Column
    var totalPaymentsReceived: Int = 0,

    @Column(precision = 19, scale = 2)
    var lifetimeRevenue: BigDecimal = BigDecimal.ZERO,

    // ============================================
    // STATEMENT CONFIGURATION
    // ============================================

    @Enumerated(EnumType.STRING)
    @Column
    var statementFrequency: StatementFrequency = StatementFrequency.MONTHLY,

    @Column
    var lastStatementDate: Instant? = null,

    @Column
    var lastStatementBalance: BigDecimal? = null,

    // ============================================
    // LIFECYCLE
    // ============================================

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @Column(nullable = false)
    val createdBy: UUID,

    var updatedBy: UUID? = null,

    @Version
    var version: Long = 0
) {
    companion object {
        fun generateAccountNumber(year: Int = LocalDate.now().year, sequence: Long): String {
            return "AR-$year-${sequence.toString().padStart(6, '0')}"
        }
    }

    // ============================================
    // BUSINESS METHODS - INVOICE PROCESSING
    // ============================================

    /**
     * Apply invoice to customer account
     */
    fun applyInvoice(invoiceAmount: BigDecimal, invoiceDate: Instant, userId: UUID) {
        require(invoiceAmount > BigDecimal.ZERO) {
            "Invoice amount must be positive"
        }

        this.totalOutstanding = MoneyMath.add(this.totalOutstanding, invoiceAmount)
        this.currentBalance = MoneyMath.add(this.currentBalance, invoiceAmount)
        this.lastInvoiceDate = invoiceDate
        this.totalInvoicesIssued++
        this.lifetimeRevenue = MoneyMath.add(this.lifetimeRevenue, invoiceAmount)
        this.updatedBy = userId
        this.updatedAt = Instant.now()

        // Update aging information
        refreshAging()
    }

    /**
     * Apply payment to customer account
     */
    fun applyPayment(paymentAmount: BigDecimal, paymentDate: Instant, userId: UUID) {
        require(paymentAmount > BigDecimal.ZERO) {
            "Payment amount must be positive"
        }
        require(paymentAmount <= totalOutstanding) {
            "Payment amount cannot exceed outstanding balance"
        }

        this.totalOutstanding = MoneyMath.subtract(this.totalOutstanding, paymentAmount)
        this.currentBalance = MoneyMath.subtract(this.currentBalance, paymentAmount)
        this.lastPaymentDate = paymentDate
        this.lastPaymentAmount = paymentAmount
        this.totalPaymentsReceived++
        this.updatedBy = userId
        this.updatedAt = Instant.now()

        // Update aging information
        refreshAging()
    }

    // ============================================
    // BUSINESS METHODS - CREDIT MANAGEMENT
    // ============================================

    /**
     * Check if customer can purchase (has available credit)
     */
    fun canPurchase(amount: BigDecimal): Boolean {
        if (creditStatus != CreditStatus.GOOD_STANDING) {
            return false
        }
        return availableCredit >= amount
    }

    /**
     * Reserve credit for pending order/invoice
     */
    fun reserveCredit(amount: BigDecimal, userId: UUID) {
        require(canPurchase(amount)) {
            "Insufficient credit available"
        }

        this.creditUsed = MoneyMath.add(this.creditUsed, amount)
        this.availableCredit = MoneyMath.subtract(this.availableCredit, amount)
        this.updatedBy = userId
        this.updatedAt = Instant.now()
    }

    /**
     * Release reserved credit (order cancelled)
     */
    fun releaseCredit(amount: BigDecimal, userId: UUID) {
        require(amount <= creditUsed) {
            "Cannot release more credit than currently used"
        }

        this.creditUsed = MoneyMath.subtract(this.creditUsed, amount)
        this.availableCredit = MoneyMath.add(this.availableCredit, amount)
        this.updatedBy = userId
        this.updatedAt = Instant.now()
    }

    /**
     * Increase credit limit (requires approval)
     */
    fun increaseCreditLimit(amount: BigDecimal, approvedBy: UUID) {
        require(amount > BigDecimal.ZERO) {
            "Credit limit increase must be positive"
        }

        this.creditLimit = MoneyMath.add(this.creditLimit, amount)
        this.availableCredit = MoneyMath.add(this.availableCredit, amount)
        this.updatedBy = approvedBy
        this.updatedAt = Instant.now()
    }

    /**
     * Decrease credit limit (requires approval)
     */
    fun decreaseCreditLimit(amount: BigDecimal, approvedBy: UUID) {
        require(amount > BigDecimal.ZERO) {
            "Credit limit decrease must be positive"
        }
        require(amount <= availableCredit) {
            "Cannot decrease credit limit below currently used amount"
        }

        this.creditLimit = MoneyMath.subtract(this.creditLimit, amount)
        this.availableCredit = MoneyMath.subtract(this.availableCredit, amount)
        this.updatedBy = approvedBy
        this.updatedAt = Instant.now()
    }

    /**
     * Place account on credit hold
     */
    fun placeOnCreditHold(reason: String, userId: UUID) {
        require(creditStatus == CreditStatus.GOOD_STANDING) {
            "Account is already on hold or blocked"
        }

        this.creditStatus = CreditStatus.CREDIT_HOLD
        this.creditHoldReason = reason
        this.creditHoldDate = Instant.now()
        this.creditHoldBy = userId
        this.updatedBy = userId
        this.updatedAt = Instant.now()
    }

    /**
     * Remove credit hold
     */
    fun removeCreditHold(userId: UUID) {
        require(creditStatus == CreditStatus.CREDIT_HOLD) {
            "Account is not on credit hold"
        }

        this.creditStatus = CreditStatus.GOOD_STANDING
        this.creditHoldReason = null
        this.creditHoldDate = null
        this.creditHoldBy = null
        this.updatedBy = userId
        this.updatedAt = Instant.now()
    }

    // ============================================
    // BUSINESS METHODS - AGING & DSO
    // ============================================

    /**
     * Refresh aging buckets based on outstanding invoices
     */
    fun refreshAging() {
        // This would query all outstanding invoices and bucket them by age
        // Implementation would be in application service
        this.daysSalesOutstanding = calculateDSO()
        this.updatedAt = Instant.now()
    }

    private fun calculateDSO(): Int {
        if (lifetimeRevenue == BigDecimal.ZERO) {
            return 0
        }
        // DSO = (Accounts Receivable / Revenue) × Days in Period
        // Simplified calculation: (totalOutstanding / lifetimeRevenue) × 365
        return MoneyMath.divide(totalOutstanding, lifetimeRevenue)
            .multiply(BigDecimal(365))
            .toInt()
    }

    /**
     * Check if account is overdue
     */
    fun isOverdue(): Boolean {
        return overdueBalance > BigDecimal.ZERO
    }

    /**
     * Check if account is severely overdue (90+ days)
     */
    fun isSeverelyOverdue(): Boolean {
        return agingInfo.over90Days > BigDecimal.ZERO
    }

    // ============================================
    // BUSINESS METHODS - STATEMENT GENERATION
    // ============================================

    /**
     * Mark statement as generated
     */
    fun markStatementGenerated(statementDate: Instant, balance: BigDecimal) {
        this.lastStatementDate = statementDate
        this.lastStatementBalance = balance
        this.updatedAt = Instant.now()
    }

    /**
     * Check if statement is due
     */
    fun isStatementDue(): Boolean {
        if (lastStatementDate == null) {
            return true
        }

        val daysSinceLastStatement = Duration.between(lastStatementDate, Instant.now()).toDays()

        return when (statementFrequency) {
            StatementFrequency.WEEKLY -> daysSinceLastStatement >= 7
            StatementFrequency.BI_WEEKLY -> daysSinceLastStatement >= 14
            StatementFrequency.MONTHLY -> daysSinceLastStatement >= 30
            StatementFrequency.QUARTERLY -> daysSinceLastStatement >= 90
            StatementFrequency.ANNUALLY -> daysSinceLastStatement >= 365
            StatementFrequency.ON_DEMAND -> false
        }
    }
}

// ============================================
// VALUE OBJECTS
// ============================================

@Embeddable
data class AgingInfo(
    @Column(precision = 19, scale = 2)
    var current: BigDecimal = BigDecimal.ZERO, // 0-30 days

    @Column(precision = 19, scale = 2)
    var days31to60: BigDecimal = BigDecimal.ZERO,

    @Column(precision = 19, scale = 2)
    var days61to90: BigDecimal = BigDecimal.ZERO,

    @Column(precision = 19, scale = 2)
    var over90Days: BigDecimal = BigDecimal.ZERO
) {
    fun total(): BigDecimal {
        return MoneyMath.add(
            MoneyMath.add(current, days31to60),
            MoneyMath.add(days61to90, over90Days)
        )
    }
}

// ============================================
// ENUMS
// ============================================

enum class AccountType {
    STANDARD,    // Standard credit account
    PREPAID,     // Prepaid account (pay before invoice)
    COD,         // Cash on delivery
    CREDIT_CARD, // Automatic credit card charging
    SUBSCRIPTION // Subscription-based billing
}

enum class PaymentTerms {
    IMMEDIATE,   // Payment due immediately
    NET_7,       // Payment due in 7 days
    NET_10,      // Payment due in 10 days
    NET_15,      // Payment due in 15 days
    NET_30,      // Payment due in 30 days (most common)
    NET_45,      // Payment due in 45 days
    NET_60,      // Payment due in 60 days
    NET_90,      // Payment due in 90 days
    NET_120,     // Payment due in 120 days
    EOM,         // End of month
    EOM_PLUS_15, // 15 days after end of month
    EOM_PLUS_30, // 30 days after end of month
    TWO_10_NET_30, // 2% discount if paid within 10 days, net 30
    ONE_15_NET_30, // 1% discount if paid within 15 days, net 30
    CUSTOM       // Custom payment terms
}

enum class CreditStatus {
    GOOD_STANDING,  // Account in good standing
    CREDIT_HOLD,    // Temporary credit hold
    PAST_DUE,       // Payment overdue
    COLLECTIONS,    // Sent to collections
    WRITE_OFF,      // Bad debt write-off
    BLOCKED         // Permanently blocked
}

enum class StatementFrequency {
    WEEKLY,
    BI_WEEKLY,
    MONTHLY,
    QUARTERLY,
    ANNUALLY,
    ON_DEMAND
}
```

---

## Integration Patterns

### 1. Customer Creation Flow

```kotlin
// CRM Service - Customer Relationship Domain
@ApplicationScoped
class CustomerApplicationService(
    private val customerRepository: CustomerRepository,
    private val eventPublisher: EventPublisher
) {
    suspend fun createCustomer(command: CreateCustomerCommand): Customer {
        // 1. Create customer in CRM
        val customer = Customer(
            customerNumber = Customer.generateCustomerNumber(sequence = getNextSequence()),
            personalInfo = command.personalInfo,
            contactInfo = command.contactInfo,
            customerType = command.customerType,
            status = CustomerStatus.PROSPECT,
            segment = command.segment,
            creditInfo = CreditInfo(creditLimit = command.initialCreditLimit),
            tenantId = command.tenantId,
            createdBy = command.userId
        )

        customerRepository.save(customer)

        // 2. Publish domain event
        eventPublisher.publish(
            CustomerCreatedEvent(
                customerId = customer.id,
                customerNumber = customer.customerNumber,
                customerType = customer.customerType,
                creditLimit = customer.creditInfo.creditLimit,
                paymentTerms = command.paymentTerms,
                tenantId = customer.tenantId,
                createdAt = customer.createdAt
            )
        )

        return customer
    }
}

// Financial Service - Accounts Receivable Domain
@ApplicationScoped
class CustomerAccountEventHandler(
    private val customerAccountService: CustomerAccountService
) {
    @Incoming("customer-events")
    suspend fun handleCustomerCreated(event: CustomerCreatedEvent) {
        // Automatically create AR account when customer is created
        customerAccountService.createCustomerAccount(
            CreateCustomerAccountCommand(
                customerId = event.customerId,
                currency = "USD",
                creditLimit = event.creditLimit,
                paymentTerms = event.paymentTerms ?: PaymentTerms.NET_30,
                accountType = AccountType.STANDARD,
                tenantId = event.tenantId,
                createdBy = SYSTEM_USER_ID
            )
        )
    }
}
```

### 2. Credit Limit Change Flow

```kotlin
// CRM Service - Update credit limit
@ApplicationScoped
class CustomerApplicationService(
    private val customerRepository: CustomerRepository,
    private val eventPublisher: EventPublisher
) {
    suspend fun increaseCreditLimit(
        customerId: UUID,
        amount: BigDecimal,
        approvedBy: UUID
    ): Customer {
        val customer = customerRepository.findById(customerId)
            ?: throw CustomerNotFoundException(customerId)

        // Update credit limit in CRM
        customer.increaseCreditLimit(amount, approvedBy)
        customerRepository.update(customer)

        // Publish event
        eventPublisher.publish(
            CreditLimitChangedEvent(
                customerId = customer.id,
                oldLimit = customer.creditInfo.creditLimit - amount,
                newLimit = customer.creditInfo.creditLimit,
                changedBy = approvedBy,
                changedAt = Instant.now()
            )
        )

        return customer
    }
}

// Financial Service - Sync credit limit to AR account
@ApplicationScoped
class CustomerAccountEventHandler(
    private val customerAccountRepository: CustomerAccountRepository
) {
    @Incoming("customer-events")
    suspend fun handleCreditLimitChanged(event: CreditLimitChangedEvent) {
        // Find AR account by customerId
        val account = customerAccountRepository.findByCustomerId(event.customerId)
            ?: return

        // Sync credit limit
        val increase = event.newLimit - event.oldLimit
        if (increase > BigDecimal.ZERO) {
            account.increaseCreditLimit(increase, event.changedBy)
        } else {
            account.decreaseCreditLimit(increase.abs(), event.changedBy)
        }

        customerAccountRepository.update(account)
    }
}
```

### 3. Invoice Creation Flow

```kotlin
// Financial Service - Accounts Receivable Domain
@ApplicationScoped
class InvoiceApplicationService(
    private val invoiceRepository: InvoiceRepository,
    private val customerAccountRepository: CustomerAccountRepository,
    private val crmIntegrationService: CRMIntegrationService // Anti-corruption layer
) {
    suspend fun createInvoice(command: CreateInvoiceCommand): CustomerInvoice {
        // 1. Verify customer exists in CRM (via ACL)
        val customerInfo = crmIntegrationService.getCustomerInfo(command.customerId)
            ?: throw CustomerNotFoundException(command.customerId)

        // 2. Get or create AR account
        val account = customerAccountRepository.findByCustomerId(command.customerId)
            ?: throw CustomerAccountNotFoundException(command.customerId)

        // 3. Check credit limit
        if (!account.canPurchase(command.totalAmount)) {
            throw InsufficientCreditException(
                "Customer ${customerInfo.customerNumber} has insufficient credit. " +
                "Available: ${account.availableCredit}, Required: ${command.totalAmount}"
            )
        }

        // 4. Create invoice
        val invoice = CustomerInvoice(
            invoiceNumber = CustomerInvoice.generateInvoiceNumber(sequence = getNextSequence()),
            customerId = command.customerId,
            customerAccountId = account.id,
            currency = account.currency,
            totalAmount = command.totalAmount,
            balance = command.totalAmount,
            dueDate = calculateDueDate(account.paymentTerms),
            status = InvoiceStatus.PENDING,
            tenantId = command.tenantId,
            createdBy = command.userId
        )

        // Add line items
        command.lineItems.forEach { lineItem ->
            invoice.addLineItem(
                description = lineItem.description,
                quantity = lineItem.quantity,
                unitPrice = lineItem.unitPrice,
                taxRate = lineItem.taxRate
            )
        }

        invoice.finalize(command.userId)
        invoiceRepository.save(invoice)

        // 5. Update customer account
        account.applyInvoice(
            invoiceAmount = invoice.totalAmount,
            invoiceDate = invoice.createdAt,
            userId = command.userId
        )
        customerAccountRepository.update(account)

        return invoice
    }
}
```

### 4. Anti-Corruption Layer (ACL)

```kotlin
// Financial Service - Anti-Corruption Layer for CRM
@ApplicationScoped
class CRMIntegrationService(
    private val customerClient: RestClient // or Kafka consumer
) {
    /**
     * Get customer information from CRM service
     * Translates CRM customer model to Finance domain model
     */
    suspend fun getCustomerInfo(customerId: UUID): CustomerInfoDTO? {
        return try {
            val crmCustomer = customerClient.getCustomer(customerId)

            // Translate CRM model to Finance model
            CustomerInfoDTO(
                customerId = crmCustomer.id,
                customerNumber = crmCustomer.customerNumber,
                name = "${crmCustomer.personalInfo.firstName} ${crmCustomer.personalInfo.lastName}",
                email = crmCustomer.contactInfo.primaryEmail,
                phone = crmCustomer.contactInfo.primaryPhone,
                customerType = crmCustomer.customerType,
                status = mapCustomerStatus(crmCustomer.status),
                segment = crmCustomer.segment
            )
        } catch (e: Exception) {
            logger.warn("Failed to fetch customer from CRM: ${e.message}")
            null // Graceful degradation
        }
    }

    private fun mapCustomerStatus(crmStatus: CustomerStatus): CustomerFinancialStatus {
        return when (crmStatus) {
            CustomerStatus.ACTIVE -> CustomerFinancialStatus.ACTIVE
            CustomerStatus.SUSPENDED -> CustomerFinancialStatus.SUSPENDED
            CustomerStatus.INACTIVE -> CustomerFinancialStatus.INACTIVE
            CustomerStatus.CHURNED -> CustomerFinancialStatus.INACTIVE
            CustomerStatus.BLOCKED -> CustomerFinancialStatus.BLOCKED
            else -> CustomerFinancialStatus.INACTIVE
        }
    }
}

// Data Transfer Object (Finance domain's view of customer)
data class CustomerInfoDTO(
    val customerId: UUID,
    val customerNumber: String,
    val name: String,
    val email: String,
    val phone: String,
    val customerType: CustomerType,
    val status: CustomerFinancialStatus,
    val segment: CustomerSegment
)

enum class CustomerFinancialStatus {
    ACTIVE,
    SUSPENDED,
    INACTIVE,
    BLOCKED
}
```

---

## Domain Events

### Customer Events (from CRM)

```kotlin
// Event: Customer created
data class CustomerCreatedEvent(
    val customerId: UUID,
    val customerNumber: String,
    val customerType: CustomerType,
    val creditLimit: BigDecimal,
    val paymentTerms: PaymentTerms?,
    val tenantId: UUID,
    val createdAt: Instant,
    override val eventId: UUID = UUID.randomUUID(),
    override val timestamp: Instant = Instant.now()
) : DomainEvent

// Event: Customer updated
data class CustomerUpdatedEvent(
    val customerId: UUID,
    val changes: Map<String, Any>,
    val updatedBy: UUID,
    val updatedAt: Instant,
    override val eventId: UUID = UUID.randomUUID(),
    override val timestamp: Instant = Instant.now()
) : DomainEvent

// Event: Customer status changed
data class CustomerStatusChangedEvent(
    val customerId: UUID,
    val oldStatus: CustomerStatus,
    val newStatus: CustomerStatus,
    val reason: String?,
    val changedBy: UUID,
    val changedAt: Instant,
    override val eventId: UUID = UUID.randomUUID(),
    override val timestamp: Instant = Instant.now()
) : DomainEvent

// Event: Credit limit changed
data class CreditLimitChangedEvent(
    val customerId: UUID,
    val oldLimit: BigDecimal,
    val newLimit: BigDecimal,
    val changedBy: UUID,
    val changedAt: Instant,
    override val eventId: UUID = UUID.randomUUID(),
    override val timestamp: Instant = Instant.now()
) : DomainEvent

// Event: Customer segment changed
data class CustomerSegmentChangedEvent(
    val customerId: UUID,
    val oldSegment: CustomerSegment,
    val newSegment: CustomerSegment,
    val changedBy: UUID,
    val changedAt: Instant,
    override val eventId: UUID = UUID.randomUUID(),
    override val timestamp: Instant = Instant.now()
) : DomainEvent
```

### Financial Events (from AR)

```kotlin
// Event: Customer account created
data class CustomerAccountCreatedEvent(
    val accountId: UUID,
    val customerId: UUID,
    val accountNumber: String,
    val creditLimit: BigDecimal,
    val tenantId: UUID,
    val createdAt: Instant,
    override val eventId: UUID = UUID.randomUUID(),
    override val timestamp: Instant = Instant.now()
) : DomainEvent

// Event: Invoice created
data class InvoiceCreatedEvent(
    val invoiceId: UUID,
    val invoiceNumber: String,
    val customerId: UUID,
    val amount: BigDecimal,
    val dueDate: LocalDate,
    val createdAt: Instant,
    override val eventId: UUID = UUID.randomUUID(),
    override val timestamp: Instant = Instant.now()
) : DomainEvent

// Event: Payment received
data class PaymentReceivedEvent(
    val paymentId: UUID,
    val customerId: UUID,
    val amount: BigDecimal,
    val paymentMethod: PaymentMethod,
    val paidAt: Instant,
    override val eventId: UUID = UUID.randomUUID(),
    override val timestamp: Instant = Instant.now()
) : DomainEvent

// Event: Credit hold placed
data class CreditHoldPlacedEvent(
    val customerId: UUID,
    val accountId: UUID,
    val reason: String,
    val placedBy: UUID,
    val placedAt: Instant,
    override val eventId: UUID = UUID.randomUUID(),
    override val timestamp: Instant = Instant.now()
) : DomainEvent

// Event: Account overdue
data class AccountOverdueEvent(
    val customerId: UUID,
    val accountId: UUID,
    val overdueAmount: BigDecimal,
    val daysPastDue: Int,
    val detectedAt: Instant,
    override val eventId: UUID = UUID.randomUUID(),
    override val timestamp: Instant = Instant.now()
) : DomainEvent
```

---

## Query Patterns

### 1. Get Customer with Financial Summary

```kotlin
// Use Case: Display customer dashboard with financial info
@ApplicationScoped
class CustomerDashboardQueryService(
    private val crmCustomerRepository: CustomerRepository, // CRM schema
    private val financeAccountRepository: CustomerAccountRepository, // Finance schema
    private val invoiceRepository: InvoiceRepository
) {
    suspend fun getCustomerDashboard(customerId: UUID): CustomerDashboardDTO {
        // 1. Get customer from CRM
        val customer = crmCustomerRepository.findById(customerId)
            ?: throw CustomerNotFoundException(customerId)

        // 2. Get AR account from Finance
        val account = financeAccountRepository.findByCustomerId(customerId)

        // 3. Get recent invoices
        val recentInvoices = if (account != null) {
            invoiceRepository.findRecentByCustomerId(customerId, limit = 10)
        } else {
            emptyList()
        }

        // 4. Combine into dashboard DTO
        return CustomerDashboardDTO(
            // From CRM
            customerId = customer.id,
            customerNumber = customer.customerNumber,
            name = "${customer.personalInfo.firstName} ${customer.personalInfo.lastName}",
            email = customer.contactInfo.primaryEmail,
            phone = customer.contactInfo.primaryPhone,
            customerType = customer.customerType,
            status = customer.status,
            segment = customer.segment,

            // From Finance
            accountNumber = account?.accountNumber,
            creditLimit = account?.creditLimit ?: BigDecimal.ZERO,
            availableCredit = account?.availableCredit ?: BigDecimal.ZERO,
            totalOutstanding = account?.totalOutstanding ?: BigDecimal.ZERO,
            overdueBalance = account?.overdueBalance ?: BigDecimal.ZERO,
            creditStatus = account?.creditStatus,
            paymentTerms = account?.paymentTerms,
            daysSalesOutstanding = account?.daysSalesOutstanding ?: 0,
            agingInfo = account?.agingInfo,

            // Recent activity
            recentInvoices = recentInvoices.map { it.toSummaryDTO() }
        )
    }
}

data class CustomerDashboardDTO(
    // CRM data
    val customerId: UUID,
    val customerNumber: String,
    val name: String,
    val email: String,
    val phone: String,
    val customerType: CustomerType,
    val status: CustomerStatus,
    val segment: CustomerSegment,

    // Finance data
    val accountNumber: String?,
    val creditLimit: BigDecimal,
    val availableCredit: BigDecimal,
    val totalOutstanding: BigDecimal,
    val overdueBalance: BigDecimal,
    val creditStatus: CreditStatus?,
    val paymentTerms: PaymentTerms?,
    val daysSalesOutstanding: Int,
    val agingInfo: AgingInfo?,

    // Recent activity
    val recentInvoices: List<InvoiceSummaryDTO>
)
```

### 2. Customer Aging Report

```kotlin
@ApplicationScoped
class CustomerAgingReportService(
    private val customerAccountRepository: CustomerAccountRepository,
    private val crmIntegrationService: CRMIntegrationService
) {
    suspend fun generateAgingReport(tenantId: UUID): List<CustomerAgingReportRow> {
        // 1. Get all accounts with outstanding balance
        val accounts = customerAccountRepository.findAllWithOutstandingBalance(tenantId)

        // 2. Get customer info from CRM (batch)
        val customerIds = accounts.map { it.customerId }
        val customersMap = crmIntegrationService.getCustomersBatch(customerIds)
            .associateBy { it.customerId }

        // 3. Combine into report rows
        return accounts.map { account ->
            val customer = customersMap[account.customerId]

            CustomerAgingReportRow(
                customerId = account.customerId,
                customerNumber = customer?.customerNumber ?: "UNKNOWN",
                customerName = customer?.name ?: "UNKNOWN",
                accountNumber = account.accountNumber,
                totalOutstanding = account.totalOutstanding,
                current = account.agingInfo.current,
                days31to60 = account.agingInfo.days31to60,
                days61to90 = account.agingInfo.days61to90,
                over90Days = account.agingInfo.over90Days,
                creditLimit = account.creditLimit,
                creditStatus = account.creditStatus,
                daysSalesOutstanding = account.daysSalesOutstanding
            )
        }.sortedByDescending { it.totalOutstanding }
    }
}

data class CustomerAgingReportRow(
    val customerId: UUID,
    val customerNumber: String,
    val customerName: String,
    val accountNumber: String,
    val totalOutstanding: BigDecimal,
    val current: BigDecimal,
    val days31to60: BigDecimal,
    val days61to90: BigDecimal,
    val over90Days: BigDecimal,
    val creditLimit: BigDecimal,
    val creditStatus: CreditStatus,
    val daysSalesOutstanding: Int
)
```

### 3. Customer Statement Generation

```kotlin
@ApplicationScoped
class CustomerStatementService(
    private val customerAccountRepository: CustomerAccountRepository,
    private val invoiceRepository: InvoiceRepository,
    private val paymentRepository: PaymentRepository,
    private val crmIntegrationService: CRMIntegrationService
) {
    suspend fun generateStatement(
        customerId: UUID,
        startDate: LocalDate,
        endDate: LocalDate
    ): CustomerStatement {
        // 1. Get customer info from CRM
        val customer = crmIntegrationService.getCustomerInfo(customerId)
            ?: throw CustomerNotFoundException(customerId)

        // 2. Get AR account
        val account = customerAccountRepository.findByCustomerId(customerId)
            ?: throw CustomerAccountNotFoundException(customerId)

        // 3. Get transactions in date range
        val invoices = invoiceRepository.findByCustomerAndDateRange(
            customerId, startDate, endDate
        )
        val payments = paymentRepository.findByCustomerAndDateRange(
            customerId, startDate, endDate
        )

        // 4. Calculate opening and closing balance
        val openingBalance = calculateOpeningBalance(account, startDate)
        val closingBalance = account.currentBalance

        // 5. Build statement
        val transactions = buildTransactionList(invoices, payments)

        return CustomerStatement(
            statementNumber = generateStatementNumber(),
            customerId = customerId,
            customerNumber = customer.customerNumber,
            customerName = customer.name,
            accountNumber = account.accountNumber,
            statementDate = LocalDate.now(),
            periodStart = startDate,
            periodEnd = endDate,
            openingBalance = openingBalance,
            closingBalance = closingBalance,
            totalInvoiced = invoices.sumOf { it.totalAmount },
            totalPaid = payments.sumOf { it.amount },
            transactions = transactions,
            agingInfo = account.agingInfo,
            creditLimit = account.creditLimit,
            availableCredit = account.availableCredit
        )
    }

    private fun buildTransactionList(
        invoices: List<CustomerInvoice>,
        payments: List<CustomerPayment>
    ): List<StatementTransaction> {
        val transactions = mutableListOf<StatementTransaction>()

        invoices.forEach { invoice ->
            transactions.add(
                StatementTransaction(
                    date = invoice.createdAt.atZone(ZoneId.systemDefault()).toLocalDate(),
                    type = TransactionType.INVOICE,
                    reference = invoice.invoiceNumber,
                    description = "Invoice ${invoice.invoiceNumber}",
                    debit = invoice.totalAmount,
                    credit = BigDecimal.ZERO,
                    balance = invoice.balance
                )
            )
        }

        payments.forEach { payment ->
            transactions.add(
                StatementTransaction(
                    date = payment.paidAt.atZone(ZoneId.systemDefault()).toLocalDate(),
                    type = TransactionType.PAYMENT,
                    reference = payment.paymentNumber,
                    description = "Payment ${payment.paymentNumber}",
                    debit = BigDecimal.ZERO,
                    credit = payment.amount,
                    balance = BigDecimal.ZERO // Updated after sorting
                )
            )
        }

        return transactions.sortedBy { it.date }
    }
}

data class CustomerStatement(
    val statementNumber: String,
    val customerId: UUID,
    val customerNumber: String,
    val customerName: String,
    val accountNumber: String,
    val statementDate: LocalDate,
    val periodStart: LocalDate,
    val periodEnd: LocalDate,
    val openingBalance: BigDecimal,
    val closingBalance: BigDecimal,
    val totalInvoiced: BigDecimal,
    val totalPaid: BigDecimal,
    val transactions: List<StatementTransaction>,
    val agingInfo: AgingInfo,
    val creditLimit: BigDecimal,
    val availableCredit: BigDecimal
)

data class StatementTransaction(
    val date: LocalDate,
    val type: TransactionType,
    val reference: String,
    val description: String,
    val debit: BigDecimal,
    val credit: BigDecimal,
    val balance: BigDecimal
)

enum class TransactionType {
    INVOICE,
    PAYMENT,
    CREDIT_NOTE,
    ADJUSTMENT
}
```

---

## Collections Workflow

### 1. Overdue Detection (Scheduled Job)

```kotlin
@ApplicationScoped
class OverdueAccountDetectionService(
    private val customerAccountRepository: CustomerAccountRepository,
    private val invoiceRepository: InvoiceRepository,
    private val eventPublisher: EventPublisher
) {
    @Scheduled(cron = "0 0 2 * * ?") // Run daily at 2 AM
    suspend fun detectOverdueAccounts() {
        val today = LocalDate.now()

        // Find all accounts with outstanding balance
        val accounts = customerAccountRepository.findAllWithOutstandingBalance()

        accounts.forEach { account ->
            // Find overdue invoices
            val overdueInvoices = invoiceRepository.findOverdueByCustomer(account.customerId, today)

            if (overdueInvoices.isNotEmpty()) {
                val overdueAmount = overdueInvoices.sumOf { it.balance }
                val oldestInvoice = overdueInvoices.minBy { it.dueDate }
                val daysPastDue = ChronoUnit.DAYS.between(oldestInvoice.dueDate, today).toInt()

                // Update account
                account.overdueBalance = overdueAmount
                account.updatedAt = Instant.now()
                customerAccountRepository.update(account)

                // Escalate based on severity
                when {
                    daysPastDue >= 90 -> {
                        // Severe: Block account
                        account.creditStatus = CreditStatus.COLLECTIONS
                        eventPublisher.publish(
                            AccountOverdueEvent(
                                customerId = account.customerId,
                                accountId = account.id,
                                overdueAmount = overdueAmount,
                                daysPastDue = daysPastDue,
                                detectedAt = Instant.now()
                            )
                        )
                    }
                    daysPastDue >= 60 -> {
                        // Major: Credit hold
                        if (account.creditStatus == CreditStatus.GOOD_STANDING) {
                            account.placeOnCreditHold(
                                reason = "Payment overdue by $daysPastDue days",
                                userId = SYSTEM_USER_ID
                            )
                        }
                    }
                    daysPastDue >= 30 -> {
                        // Minor: Warning
                        account.creditStatus = CreditStatus.PAST_DUE
                    }
                }

                customerAccountRepository.update(account)
            }
        }
    }
}
```

### 2. Collections Workflow

```kotlin
@ApplicationScoped
class CollectionsWorkflowService(
    private val customerAccountRepository: CustomerAccountRepository,
    private val crmIntegrationService: CRMIntegrationService,
    private val notificationService: NotificationService
) {
    suspend fun processCollections() {
        val overdueAccounts = customerAccountRepository.findOverdueAccounts()

        overdueAccounts.forEach { account ->
            val customer = crmIntegrationService.getCustomerInfo(account.customerId)
                ?: return@forEach

            when {
                // 1st reminder: 7 days past due
                account.daysSalesOutstanding in 7..14 -> {
                    sendPaymentReminder(customer, account, severity = ReminderSeverity.GENTLE)
                }

                // 2nd reminder: 15 days past due
                account.daysSalesOutstanding in 15..29 -> {
                    sendPaymentReminder(customer, account, severity = ReminderSeverity.FIRM)
                }

                // Final notice: 30 days past due
                account.daysSalesOutstanding in 30..59 -> {
                    sendPaymentReminder(customer, account, severity = ReminderSeverity.FINAL_NOTICE)
                }

                // Collections: 60+ days past due
                account.daysSalesOutstanding >= 60 -> {
                    escalateToCollections(customer, account)
                }
            }
        }
    }

    private suspend fun sendPaymentReminder(
        customer: CustomerInfoDTO,
        account: CustomerAccount,
        severity: ReminderSeverity
    ) {
        notificationService.sendEmail(
            to = customer.email,
            subject = when (severity) {
                ReminderSeverity.GENTLE -> "Payment Reminder: Account ${account.accountNumber}"
                ReminderSeverity.FIRM -> "Urgent: Payment Required for Account ${account.accountNumber}"
                ReminderSeverity.FINAL_NOTICE -> "FINAL NOTICE: Account ${account.accountNumber} Past Due"
            },
            body = buildReminderEmail(customer, account, severity)
        )
    }

    private suspend fun escalateToCollections(
        customer: CustomerInfoDTO,
        account: CustomerAccount
    ) {
        // Place account in collections
        account.creditStatus = CreditStatus.COLLECTIONS
        account.placeOnCreditHold(
            reason = "Account escalated to collections",
            userId = SYSTEM_USER_ID
        )
        customerAccountRepository.update(account)

        // Notify collections team
        notificationService.notifyCollectionsTeam(
            customerId = customer.customerId,
            accountNumber = account.accountNumber,
            overdueAmount = account.overdueBalance,
            daysPastDue = account.daysSalesOutstanding
        )
    }
}

enum class ReminderSeverity {
    GENTLE,
    FIRM,
    FINAL_NOTICE
}
```

---

## Summary

### ✅ What This Architecture Provides

1. **Clear Domain Boundaries**

    - CRM owns customer identity and profile
    - Finance owns transactional data and financial accounts
    - Each domain is autonomous

2. **Loose Coupling**

    - Services communicate via events
    - Anti-corruption layers protect domain integrity
    - UUID references instead of foreign keys

3. **High Cohesion**

    - Customer lifecycle in CRM
    - Financial transactions in Finance
    - Related data grouped together

4. **Scalability**

    - Services can scale independently
    - CRM can handle millions of customers
    - Finance can process high transaction volumes

5. **Flexibility**

    - Add new customer types in CRM without touching Finance
    - Add new payment methods in Finance without touching CRM
    - Industry-specific customizations via JSONB

6. **Enterprise Features**
    - Credit management
    - Aging reports
    - Collections workflow
    - Statement generation
    - Day Sales Outstanding (DSO)

### 🎯 Key Takeaways

-   **Customer master data** → CRM service (`crm_schema`)
-   **Customer financial accounts** → Financial service (`finance_schema`)
-   **Integration** → Domain events + Anti-corruption layers
-   **Pattern** → Strategic DDD with bounded contexts
-   **Inspiration** → SAP FI (SD-FI integration), Oracle AR

This architecture follows proven patterns from SAP, Oracle, and Microsoft Dynamics ERP systems! 🚀
