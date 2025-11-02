# Domain Models - Human Resources (HR) Domain

## Schema: `administration_schema`

This domain implements **world-class HR management patterns** following SAP HCM (Human Capital Management) principles for enterprise-grade employee lifecycle management.

---

## Overview

The HR domain is responsible for managing the complete employee lifecycle from recruitment through retirement, including organizational structure, compensation, performance management, and compliance.

### Key Responsibilities

-   Employee master data management
-   Organizational structure (departments, positions, teams)
-   Employment contracts and assignments
-   Time and attendance tracking
-   Leave and absence management
-   Performance evaluations and reviews
-   Training and development programs
-   Payroll integration and benefits administration
-   Compliance and regulatory reporting

---

## Domain 1: Employee Master Data

### Aggregates

**Employee (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "employees",
    schema = "administration_schema",
    indexes = [
        Index(name = "idx_employee_number", columnList = "employeeNumber"),
        Index(name = "idx_employee_email", columnList = "email"),
        Index(name = "idx_employee_status", columnList = "status"),
        Index(name = "idx_employee_department", columnList = "departmentId"),
        Index(name = "idx_employee_manager", columnList = "managerId")
    ]
)
class Employee(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val employeeNumber: String, // EMP-YYYY-NNNNNN

    // Personal Information
    @Embedded
    var personalInfo: PersonalInfo,

    @Embedded
    var contactInfo: ContactInfo,

    @Embedded
    var emergencyContact: EmergencyContact?,

    // Employment Information
    @Column(nullable = false)
    val hireDate: LocalDate,

    val originalHireDate: LocalDate? = null, // For rehires

    var terminationDate: LocalDate? = null,
    var terminationReason: String? = null,

    @Enumerated(EnumType.STRING)
    var employmentType: EmploymentType,

    @Enumerated(EnumType.STRING)
    var employmentStatus: EmploymentStatus,

    // Organizational Assignment
    @ManyToOne
    @JoinColumn(name = "department_id")
    var department: Department? = null,

    @ManyToOne
    @JoinColumn(name = "position_id")
    var position: Position? = null,

    @ManyToOne
    @JoinColumn(name = "manager_id")
    var manager: Employee? = null,

    @OneToMany(mappedBy = "manager")
    val directReports: MutableSet<Employee> = mutableSetOf(),

    // Work Location
    @Embedded
    var workLocation: WorkLocation,

    // Compensation (reference to payroll system)
    val payrollId: UUID? = null,

    @Column(precision = 19, scale = 2)
    var currentSalary: BigDecimal? = null,

    @Column(nullable = false)
    val currency: String = "USD",

    @Enumerated(EnumType.STRING)
    val payFrequency: PayFrequency? = null,

    // Benefits
    val benefitsEligible: Boolean = false,
    val benefitsEnrollmentDate: LocalDate? = null,

    // Access & Security
    val userId: UUID? = null, // Reference to security domain
    val badgeNumber: String? = null,

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

    @Column(nullable = false)
    val createdBy: UUID,

    var updatedBy: UUID? = null,

    @Version
    var version: Long = 0
) {
    companion object {
        fun generateEmployeeNumber(year: Int, sequence: Long): String {
            return "EMP-$year-${sequence.toString().padStart(6, '0')}"
        }
    }

    fun terminate(terminationDate: LocalDate, reason: String, terminatedBy: UUID) {
        require(employmentStatus == EmploymentStatus.ACTIVE) {
            "Only active employees can be terminated"
        }

        this.employmentStatus = EmploymentStatus.TERMINATED
        this.terminationDate = terminationDate
        this.terminationReason = reason
        this.updatedAt = Instant.now()
        this.updatedBy = terminatedBy
    }

    fun promote(newPosition: Position, newDepartment: Department?, effectiveDate: LocalDate) {
        this.position = newPosition
        if (newDepartment != null) {
            this.department = newDepartment
        }
        this.updatedAt = Instant.now()
    }

    fun transfer(newDepartment: Department, newManager: Employee?, effectiveDate: LocalDate) {
        this.department = newDepartment
        if (newManager != null) {
            this.manager = newManager
        }
        this.updatedAt = Instant.now()
    }

    fun updateCompensation(newSalary: BigDecimal, effectiveDate: LocalDate, updatedBy: UUID) {
        this.currentSalary = newSalary
        this.updatedAt = Instant.now()
        this.updatedBy = updatedBy
    }

    fun isActive(): Boolean = employmentStatus == EmploymentStatus.ACTIVE

    fun getYearsOfService(): Long {
        val endDate = terminationDate ?: LocalDate.now()
        return ChronoUnit.YEARS.between(hireDate, endDate)
    }

    fun getFullName(): String = "${personalInfo.firstName} ${personalInfo.lastName}"
}

@Embeddable
data class PersonalInfo(
    @Column(nullable = false)
    val firstName: String,

    val middleName: String? = null,

    @Column(nullable = false)
    val lastName: String,

    val preferredName: String? = null,

    @Column(nullable = false)
    val dateOfBirth: LocalDate,

    @Enumerated(EnumType.STRING)
    val gender: Gender? = null,

    @Enumerated(EnumType.STRING)
    val maritalStatus: MaritalStatus? = null,

    val nationalId: String? = null, // SSN, National ID, etc.
    val passportNumber: String? = null,
    val nationality: String? = null
)

@Embeddable
data class ContactInfo(
    @Column(nullable = false, unique = true)
    val email: String,

    val personalEmail: String? = null,

    @Column(nullable = false)
    val phoneNumber: String,

    val mobileNumber: String? = null,

    @Embedded
    val address: Address
)

@Embeddable
data class Address(
    @Column(nullable = false)
    val street: String,

    val street2: String? = null,

    @Column(nullable = false)
    val city: String,

    val stateProvince: String? = null,

    @Column(nullable = false)
    val postalCode: String,

    @Column(nullable = false)
    val country: String
)

@Embeddable
data class EmergencyContact(
    @Column(nullable = false)
    val name: String,

    @Column(nullable = false)
    val relationship: String,

    @Column(nullable = false)
    val phoneNumber: String,

    val alternatePhone: String? = null,

    val email: String? = null
)

@Embeddable
data class WorkLocation(
    val locationId: UUID? = null,

    @Column(nullable = false)
    val locationName: String,

    val building: String? = null,
    val floor: String? = null,
    val office: String? = null,

    val isRemote: Boolean = false,

    val timezone: String = "UTC"
)

enum class EmploymentType {
    FULL_TIME, PART_TIME, CONTRACT, TEMPORARY, INTERN, CONSULTANT
}

enum class EmploymentStatus {
    ACTIVE, ON_LEAVE, SUSPENDED, TERMINATED, RETIRED
}

enum class Gender {
    MALE, FEMALE, NON_BINARY, PREFER_NOT_TO_SAY
}

enum class MaritalStatus {
    SINGLE, MARRIED, DIVORCED, WIDOWED, SEPARATED
}

enum class PayFrequency {
    WEEKLY, BI_WEEKLY, SEMI_MONTHLY, MONTHLY, ANNUALLY
}
```

---

## Domain 2: Organizational Structure

### Aggregates

**Department (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "departments",
    schema = "administration_schema",
    indexes = [
        Index(name = "idx_dept_code", columnList = "code"),
        Index(name = "idx_dept_parent", columnList = "parentDepartmentId")
    ]
)
class Department(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val code: String, // e.g., "FIN", "IT", "HR", "SALES"

    @Column(nullable = false)
    var name: String,

    @Column(length = 2000)
    var description: String?,

    // Hierarchical structure
    @ManyToOne
    @JoinColumn(name = "parent_department_id")
    var parentDepartment: Department? = null,

    @OneToMany(mappedBy = "parentDepartment")
    val subDepartments: MutableSet<Department> = mutableSetOf(),

    // Department Head
    @ManyToOne
    @JoinColumn(name = "department_head_id")
    var departmentHead: Employee? = null,

    // Cost Center (integration with financial management)
    val costCenterId: UUID? = null,

    @Column(nullable = false)
    val isActive: Boolean = true,

    val establishedDate: LocalDate? = null,

    // Location
    val locationId: UUID? = null,
    val building: String? = null,
    val floor: String? = null,

    @Column(length = 1000)
    var notes: String? = null,

    // Multi-tenancy
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
    fun addSubDepartment(subDepartment: Department) {
        subDepartments.add(subDepartment)
        subDepartment.parentDepartment = this
        updatedAt = Instant.now()
    }

    fun removeSubDepartment(subDepartment: Department) {
        subDepartments.remove(subDepartment)
        subDepartment.parentDepartment = null
        updatedAt = Instant.now()
    }

    fun getFullPath(): String {
        return if (parentDepartment != null) {
            "${parentDepartment!!.getFullPath()} > $name"
        } else {
            name
        }
    }

    fun getLevel(): Int {
        return if (parentDepartment != null) {
            parentDepartment!!.getLevel() + 1
        } else {
            0
        }
    }
}
```

**Position (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "positions",
    schema = "administration_schema",
    indexes = [
        Index(name = "idx_position_code", columnList = "code"),
        Index(name = "idx_position_level", columnList = "level")
    ]
)
class Position(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val code: String, // e.g., "MGR-001", "DEV-SR-001"

    @Column(nullable = false)
    var title: String,

    @Column(length = 2000)
    var description: String?,

    @Enumerated(EnumType.STRING)
    val level: PositionLevel,

    @Enumerated(EnumType.STRING)
    val category: PositionCategory,

    // Reporting structure
    @ManyToOne
    @JoinColumn(name = "reports_to_position_id")
    var reportsTo: Position? = null,

    // Compensation range
    @Column(precision = 19, scale = 2)
    val minSalary: BigDecimal? = null,

    @Column(precision = 19, scale = 2)
    val maxSalary: BigDecimal? = null,

    @Column(nullable = false)
    val currency: String = "USD",

    // Requirements
    @ElementCollection
    @CollectionTable(
        name = "position_requirements",
        schema = "administration_schema",
        joinColumns = [JoinColumn(name = "position_id")]
    )
    @Column(name = "requirement")
    val requirements: MutableSet<String> = mutableSetOf(),

    @ElementCollection
    @CollectionTable(
        name = "position_responsibilities",
        schema = "administration_schema",
        joinColumns = [JoinColumn(name = "position_id")]
    )
    @Column(name = "responsibility")
    val responsibilities: MutableSet<String> = mutableSetOf(),

    @Column(nullable = false)
    val isActive: Boolean = true,

    // Multi-tenancy
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
    fun addRequirement(requirement: String) {
        requirements.add(requirement)
        updatedAt = Instant.now()
    }

    fun addResponsibility(responsibility: String) {
        responsibilities.add(responsibility)
        updatedAt = Instant.now()
    }

    fun isWithinSalaryRange(salary: BigDecimal): Boolean {
        if (minSalary == null || maxSalary == null) return true
        return salary >= minSalary && salary <= maxSalary
    }
}

enum class PositionLevel {
    EXECUTIVE,      // C-Level, VP
    SENIOR_MANAGEMENT, // Senior Director, Director
    MIDDLE_MANAGEMENT, // Manager, Senior Manager
    SUPERVISOR,     // Team Lead, Supervisor
    SENIOR,         // Senior Individual Contributor
    INTERMEDIATE,   // Mid-level Individual Contributor
    JUNIOR,         // Junior, Entry-level
    INTERN          // Intern, Trainee
}

enum class PositionCategory {
    EXECUTIVE_LEADERSHIP,
    ENGINEERING,
    PRODUCT_MANAGEMENT,
    DESIGN,
    SALES,
    MARKETING,
    CUSTOMER_SUCCESS,
    OPERATIONS,
    FINANCE,
    HUMAN_RESOURCES,
    LEGAL,
    ADMINISTRATION,
    OTHER
}
```

---

## Domain 3: Time & Attendance

### Aggregates

**TimeEntry (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "time_entries",
    schema = "administration_schema",
    indexes = [
        Index(name = "idx_time_entry_employee", columnList = "employeeId"),
        Index(name = "idx_time_entry_date", columnList = "workDate"),
        Index(name = "idx_time_entry_status", columnList = "status")
    ]
)
class TimeEntry(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false)
    val employeeId: UUID,

    @Column(nullable = false)
    val workDate: LocalDate,

    @Column(nullable = false)
    val checkInTime: Instant,

    var checkOutTime: Instant? = null,

    @Enumerated(EnumType.STRING)
    val entryType: TimeEntryType,

    // Calculated hours
    @Column(precision = 5, scale = 2)
    var regularHours: BigDecimal = BigDecimal.ZERO,

    @Column(precision = 5, scale = 2)
    var overtimeHours: BigDecimal = BigDecimal.ZERO,

    @Column(precision = 5, scale = 2)
    var totalHours: BigDecimal = BigDecimal.ZERO,

    // Break time
    @Column(precision = 5, scale = 2)
    var breakMinutes: BigDecimal = BigDecimal.ZERO,

    // Location tracking
    val checkInLocation: String? = null,
    val checkOutLocation: String? = null,

    // Project/Task allocation (optional)
    val projectId: UUID? = null,
    val taskId: UUID? = null,

    @Enumerated(EnumType.STRING)
    var status: TimeEntryStatus = TimeEntryStatus.PENDING,

    var approvedBy: UUID? = null,
    var approvedAt: Instant? = null,

    @Column(length = 1000)
    var notes: String? = null,

    // Multi-tenancy
    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
) {
    fun checkOut(checkOutTime: Instant, location: String? = null) {
        require(this.checkOutTime == null) { "Already checked out" }
        require(checkOutTime.isAfter(checkInTime)) { "Check-out time must be after check-in time" }

        this.checkOutTime = checkOutTime
        this.checkOutLocation = location
        calculateHours()
        this.updatedAt = Instant.now()
    }

    private fun calculateHours() {
        if (checkOutTime == null) return

        val duration = Duration.between(checkInTime, checkOutTime)
        val totalMinutes = duration.toMinutes()
        val workMinutes = totalMinutes - breakMinutes.toLong()

        totalHours = BigDecimal(workMinutes).divide(BigDecimal(60), 2, RoundingMode.HALF_UP)

        // Standard work day is 8 hours
        val standardHours = BigDecimal(8)
        if (totalHours > standardHours) {
            regularHours = standardHours
            overtimeHours = totalHours - standardHours
        } else {
            regularHours = totalHours
            overtimeHours = BigDecimal.ZERO
        }
    }

    fun approve(approverId: UUID) {
        require(status == TimeEntryStatus.PENDING) { "Only pending entries can be approved" }
        require(checkOutTime != null) { "Cannot approve without check-out time" }

        this.status = TimeEntryStatus.APPROVED
        this.approvedBy = approverId
        this.approvedAt = Instant.now()
        this.updatedAt = Instant.now()
    }

    fun reject(reason: String) {
        this.status = TimeEntryStatus.REJECTED
        this.notes = "$notes\nRejection: $reason"
        this.updatedAt = Instant.now()
    }
}

enum class TimeEntryType {
    REGULAR, REMOTE, OVERTIME, WEEKEND, HOLIDAY
}

enum class TimeEntryStatus {
    PENDING, APPROVED, REJECTED, PROCESSED
}
```

---

## Domain 4: Leave & Absence Management

### Aggregates

**LeaveRequest (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "leave_requests",
    schema = "administration_schema",
    indexes = [
        Index(name = "idx_leave_employee", columnList = "employeeId"),
        Index(name = "idx_leave_status", columnList = "status"),
        Index(name = "idx_leave_dates", columnList = "startDate,endDate")
    ]
)
class LeaveRequest(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val requestNumber: String, // LVR-YYYY-NNNNNN

    @Column(nullable = false)
    val employeeId: UUID,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    val leaveType: LeaveType,

    @Column(nullable = false)
    val startDate: LocalDate,

    @Column(nullable = false)
    val endDate: LocalDate,

    @Column(nullable = false)
    val isHalfDay: Boolean = false,

    @Enumerated(EnumType.STRING)
    val halfDayPeriod: HalfDayPeriod? = null,

    @Column(nullable = false, precision = 5, scale = 2)
    var totalDays: BigDecimal,

    @Column(length = 2000)
    var reason: String?,

    @Enumerated(EnumType.STRING)
    var status: LeaveRequestStatus = LeaveRequestStatus.PENDING,

    // Approval workflow
    var submittedAt: Instant? = null,

    var reviewedBy: UUID? = null,
    var reviewedAt: Instant? = null,

    @Column(length = 1000)
    var reviewComments: String? = null,

    // Coverage during absence
    val coveringEmployeeId: UUID? = null,

    // Attachment (medical certificate, etc.)
    val attachmentUrl: String? = null,

    // Multi-tenancy
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
        fun generateRequestNumber(year: Int, sequence: Long): String {
            return "LVR-$year-${sequence.toString().padStart(6, '0')}"
        }

        fun calculateBusinessDays(startDate: LocalDate, endDate: LocalDate, isHalfDay: Boolean): BigDecimal {
            var days = 0
            var current = startDate
            while (!current.isAfter(endDate)) {
                if (current.dayOfWeek != DayOfWeek.SATURDAY && current.dayOfWeek != DayOfWeek.SUNDAY) {
                    days++
                }
                current = current.plusDays(1)
            }
            return if (isHalfDay && days > 0) {
                BigDecimal(days).subtract(BigDecimal("0.5"))
            } else {
                BigDecimal(days)
            }
        }
    }

    init {
        require(endDate >= startDate) { "End date must be on or after start date" }
        totalDays = calculateBusinessDays(startDate, endDate, isHalfDay)
    }

    fun submit() {
        require(status == LeaveRequestStatus.DRAFT) { "Only draft requests can be submitted" }

        this.status = LeaveRequestStatus.PENDING
        this.submittedAt = Instant.now()
        this.updatedAt = Instant.now()
    }

    fun approve(reviewerId: UUID, comments: String? = null) {
        require(status == LeaveRequestStatus.PENDING) { "Only pending requests can be approved" }

        this.status = LeaveRequestStatus.APPROVED
        this.reviewedBy = reviewerId
        this.reviewedAt = Instant.now()
        this.reviewComments = comments
        this.updatedAt = Instant.now()
    }

    fun reject(reviewerId: UUID, reason: String) {
        require(status == LeaveRequestStatus.PENDING) { "Only pending requests can be rejected" }

        this.status = LeaveRequestStatus.REJECTED
        this.reviewedBy = reviewerId
        this.reviewedAt = Instant.now()
        this.reviewComments = reason
        this.updatedAt = Instant.now()
    }

    fun cancel(reason: String) {
        require(status != LeaveRequestStatus.CANCELLED) { "Already cancelled" }
        require(status != LeaveRequestStatus.COMPLETED) { "Cannot cancel completed leave" }

        this.status = LeaveRequestStatus.CANCELLED
        this.reviewComments = "Cancelled: $reason"
        this.updatedAt = Instant.now()
    }

    fun isOverlapping(other: LeaveRequest): Boolean {
        return !(endDate.isBefore(other.startDate) || startDate.isAfter(other.endDate))
    }
}

enum class LeaveType {
    ANNUAL_LEAVE,
    SICK_LEAVE,
    PERSONAL_LEAVE,
    MATERNITY_LEAVE,
    PATERNITY_LEAVE,
    BEREAVEMENT_LEAVE,
    STUDY_LEAVE,
    UNPAID_LEAVE,
    SABBATICAL,
    COMPENSATORY_LEAVE
}

enum class LeaveRequestStatus {
    DRAFT, PENDING, APPROVED, REJECTED, CANCELLED, COMPLETED
}

enum class HalfDayPeriod {
    MORNING, AFTERNOON
}
```

**LeaveBalance (Entity)**

```kotlin
@Entity
@Table(
    name = "leave_balances",
    schema = "administration_schema",
    indexes = [
        Index(name = "idx_leave_balance_employee", columnList = "employeeId,fiscalYear")
    ],
    uniqueConstraints = [
        UniqueConstraint(
            name = "uk_leave_balance",
            columnNames = ["employeeId", "fiscalYear", "leaveType"]
        )
    ]
)
class LeaveBalance(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false)
    val employeeId: UUID,

    @Column(nullable = false)
    val fiscalYear: Int,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    val leaveType: LeaveType,

    @Column(nullable = false, precision = 5, scale = 2)
    var totalEntitlement: BigDecimal,

    @Column(nullable = false, precision = 5, scale = 2)
    var used: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false, precision = 5, scale = 2)
    var pending: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false, precision = 5, scale = 2)
    var available: BigDecimal,

    @Column(nullable = false, precision = 5, scale = 2)
    var carriedForward: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val updatedAt: Instant = Instant.now()
) {
    init {
        recalculateAvailable()
    }

    fun recalculateAvailable() {
        available = totalEntitlement + carriedForward - used - pending
    }

    fun allocateLeave(days: BigDecimal) {
        pending += days
        recalculateAvailable()
    }

    fun confirmLeave(days: BigDecimal) {
        pending -= days
        used += days
        recalculateAvailable()
    }

    fun cancelLeave(days: BigDecimal, wasApproved: Boolean) {
        if (wasApproved) {
            used -= days
        } else {
            pending -= days
        }
        recalculateAvailable()
    }

    fun hasAvailableBalance(requestedDays: BigDecimal): Boolean {
        return available >= requestedDays
    }
}
```

---

## Domain 5: Performance Management

### Aggregates

**PerformanceReview (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "performance_reviews",
    schema = "administration_schema",
    indexes = [
        Index(name = "idx_review_employee", columnList = "employeeId"),
        Index(name = "idx_review_period", columnList = "reviewPeriod"),
        Index(name = "idx_review_status", columnList = "status")
    ]
)
class PerformanceReview(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val reviewNumber: String, // PR-YYYY-NNNNNN

    @Column(nullable = false)
    val employeeId: UUID,

    @Column(nullable = false)
    val reviewerId: UUID, // Usually the manager

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    val reviewType: ReviewType,

    @Column(nullable = false)
    val reviewPeriod: String, // e.g., "Q1 2025", "Annual 2024"

    @Column(nullable = false)
    val periodStartDate: LocalDate,

    @Column(nullable = false)
    val periodEndDate: LocalDate,

    val reviewDate: LocalDate? = null,

    // Overall Rating
    @Enumerated(EnumType.STRING)
    var overallRating: PerformanceRating? = null,

    @Column(precision = 3, scale = 2)
    var overallScore: BigDecimal? = null, // 0.00 to 5.00

    // Review sections
    @OneToMany(mappedBy = "review", cascade = [CascadeType.ALL], orphanRemoval = true)
    val sections: MutableList<ReviewSection> = mutableListOf(),

    // Goals and objectives
    @OneToMany(mappedBy = "review", cascade = [CascadeType.ALL], orphanRemoval = true)
    val goals: MutableList<PerformanceGoal> = mutableListOf(),

    // Comments
    @Column(length = 5000)
    var reviewerComments: String? = null,

    @Column(length = 5000)
    var employeeComments: String? = null,

    // Development plan
    @Column(length = 3000)
    var developmentPlan: String? = null,

    @Enumerated(EnumType.STRING)
    var status: ReviewStatus = ReviewStatus.DRAFT,

    // Workflow
    var completedAt: Instant? = null,
    var acknowledgedBy: UUID? = null,
    var acknowledgedAt: Instant? = null,

    // Multi-tenancy
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
        fun generateReviewNumber(year: Int, sequence: Long): String {
            return "PR-$year-${sequence.toString().padStart(6, '0')}"
        }
    }

    fun addSection(section: ReviewSection) {
        sections.add(section)
        section.review = this
        recalculateOverallScore()
    }

    fun addGoal(goal: PerformanceGoal) {
        goals.add(goal)
        goal.review = this
        updatedAt = Instant.now()
    }

    private fun recalculateOverallScore() {
        if (sections.isEmpty()) {
            overallScore = null
            return
        }

        val totalWeightedScore = sections
            .filter { it.score != null && it.weight != null }
            .sumOf { (it.score!! * it.weight!!).divide(BigDecimal(100)) }

        overallScore = totalWeightedScore

        // Determine overall rating based on score
        overallRating = when {
            overallScore!! >= BigDecimal("4.5") -> PerformanceRating.OUTSTANDING
            overallScore!! >= BigDecimal("3.5") -> PerformanceRating.EXCEEDS_EXPECTATIONS
            overallScore!! >= BigDecimal("2.5") -> PerformanceRating.MEETS_EXPECTATIONS
            overallScore!! >= BigDecimal("1.5") -> PerformanceRating.NEEDS_IMPROVEMENT
            else -> PerformanceRating.UNSATISFACTORY
        }

        updatedAt = Instant.now()
    }

    fun complete(completedDate: Instant) {
        require(status == ReviewStatus.DRAFT || status == ReviewStatus.IN_PROGRESS) {
            "Only draft or in-progress reviews can be completed"
        }
        require(sections.isNotEmpty()) { "Review must have at least one section" }
        require(overallRating != null) { "Overall rating must be set" }

        this.status = ReviewStatus.COMPLETED
        this.completedAt = completedDate
        this.updatedAt = Instant.now()
    }

    fun acknowledge(employeeId: UUID) {
        require(status == ReviewStatus.COMPLETED) { "Only completed reviews can be acknowledged" }

        this.acknowledgedBy = employeeId
        this.acknowledgedAt = Instant.now()
        this.status = ReviewStatus.ACKNOWLEDGED
        this.updatedAt = Instant.now()
    }
}

@Entity
@Table(name = "review_sections", schema = "administration_schema")
class ReviewSection(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "review_id", nullable = false)
    var review: PerformanceReview? = null,

    @Column(nullable = false)
    val sectionName: String, // e.g., "Technical Skills", "Communication", "Leadership"

    @Column(length = 2000)
    var description: String?,

    @Column(precision = 3, scale = 2)
    var score: BigDecimal? = null, // 1.00 to 5.00

    @Column(precision = 5, scale = 2)
    val weight: BigDecimal? = null, // Percentage weight (0-100)

    @Enumerated(EnumType.STRING)
    var rating: PerformanceRating? = null,

    @Column(length = 2000)
    var comments: String?
)

@Entity
@Table(name = "performance_goals", schema = "administration_schema")
class PerformanceGoal(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "review_id", nullable = false)
    var review: PerformanceReview? = null,

    @Column(nullable = false)
    val goalTitle: String,

    @Column(length = 2000)
    var description: String?,

    val targetDate: LocalDate? = null,

    @Enumerated(EnumType.STRING)
    var status: GoalStatus = GoalStatus.NOT_STARTED,

    @Column(precision = 5, scale = 2)
    var completionPercentage: BigDecimal = BigDecimal.ZERO,

    @Column(length = 1000)
    var notes: String?
)

enum class ReviewType {
    ANNUAL, SEMI_ANNUAL, QUARTERLY, PROBATION, PROJECT_END, AD_HOC
}

enum class PerformanceRating {
    OUTSTANDING,           // 5 - Far exceeds expectations
    EXCEEDS_EXPECTATIONS,  // 4 - Consistently exceeds expectations
    MEETS_EXPECTATIONS,    // 3 - Fully meets all expectations
    NEEDS_IMPROVEMENT,     // 2 - Does not consistently meet expectations
    UNSATISFACTORY         // 1 - Fails to meet expectations
}

enum class ReviewStatus {
    DRAFT, IN_PROGRESS, COMPLETED, ACKNOWLEDGED, ARCHIVED
}

enum class GoalStatus {
    NOT_STARTED, IN_PROGRESS, COMPLETED, DEFERRED, CANCELLED
}
```

---

## Domain 6: Training & Development

### Aggregates

**TrainingProgram (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "training_programs",
    schema = "administration_schema",
    indexes = [
        Index(name = "idx_training_code", columnList = "code"),
        Index(name = "idx_training_category", columnList = "category")
    ]
)
class TrainingProgram(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val code: String, // TRN-XXX

    @Column(nullable = false)
    var title: String,

    @Column(length = 3000)
    var description: String?,

    @Enumerated(EnumType.STRING)
    val category: TrainingCategory,

    @Enumerated(EnumType.STRING)
    val level: TrainingLevel,

    @Column(precision = 5, scale = 2)
    val durationHours: BigDecimal,

    @Enumerated(EnumType.STRING)
    val deliveryMethod: DeliveryMethod,

    val providerId: UUID? = null, // External training provider
    val providerName: String? = null,

    @Column(precision = 19, scale = 2)
    val cost: BigDecimal? = null,

    @Column(nullable = false)
    val currency: String = "USD",

    val maxParticipants: Int? = null,

    // Prerequisites
    @ElementCollection
    @CollectionTable(
        name = "training_prerequisites",
        schema = "administration_schema",
        joinColumns = [JoinColumn(name = "training_id")]
    )
    @Column(name = "prerequisite_id")
    val prerequisites: MutableSet<UUID> = mutableSetOf(),

    // Learning objectives
    @ElementCollection
    @CollectionTable(
        name = "training_objectives",
        schema = "administration_schema",
        joinColumns = [JoinColumn(name = "training_id")]
    )
    @Column(name = "objective", length = 500)
    val learningObjectives: MutableSet<String> = mutableSetOf(),

    val isMandatory: Boolean = false,
    val validityMonths: Int? = null, // Certification validity

    @Column(nullable = false)
    val isActive: Boolean = true,

    // Multi-tenancy
    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
)

enum class TrainingCategory {
    TECHNICAL_SKILLS,
    SOFT_SKILLS,
    LEADERSHIP,
    COMPLIANCE,
    SAFETY,
    PRODUCT_KNOWLEDGE,
    SALES,
    CUSTOMER_SERVICE,
    OTHER
}

enum class TrainingLevel {
    BEGINNER, INTERMEDIATE, ADVANCED, EXPERT
}

enum class DeliveryMethod {
    IN_PERSON, VIRTUAL, HYBRID, SELF_PACED_ONLINE, ON_THE_JOB
}
```

**TrainingEnrollment (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "training_enrollments",
    schema = "administration_schema",
    indexes = [
        Index(name = "idx_enrollment_employee", columnList = "employeeId"),
        Index(name = "idx_enrollment_program", columnList = "trainingProgramId"),
        Index(name = "idx_enrollment_status", columnList = "status")
    ]
)
class TrainingEnrollment(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false)
    val employeeId: UUID,

    @Column(nullable = false)
    val trainingProgramId: UUID,

    val sessionId: UUID? = null, // Specific training session

    @Column(nullable = false)
    val enrollmentDate: LocalDate,

    val scheduledStartDate: LocalDate? = null,
    val scheduledEndDate: LocalDate? = null,

    val actualStartDate: LocalDate? = null,
    val actualCompletionDate: LocalDate? = null,

    @Enumerated(EnumType.STRING)
    var status: EnrollmentStatus = EnrollmentStatus.ENROLLED,

    // Results
    @Column(precision = 5, scale = 2)
    var score: BigDecimal? = null,

    var passed: Boolean? = null,

    val certificateUrl: String? = null,
    val certificateIssuedDate: LocalDate? = null,
    val certificateExpiryDate: LocalDate? = null,

    // Feedback
    @Column(precision = 2, scale = 1)
    var feedbackRating: BigDecimal? = null, // 1.0 to 5.0

    @Column(length = 2000)
    var feedbackComments: String? = null,

    val requestedBy: UUID? = null, // Manager or employee
    val approvedBy: UUID? = null,

    @Column(length = 1000)
    var notes: String? = null,

    // Multi-tenancy
    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
) {
    fun startTraining(startDate: LocalDate) {
        require(status == EnrollmentStatus.ENROLLED) { "Can only start enrolled training" }

        this.actualStartDate = startDate
        this.status = EnrollmentStatus.IN_PROGRESS
        this.updatedAt = Instant.now()
    }

    fun complete(completionDate: LocalDate, score: BigDecimal?, passed: Boolean) {
        require(status == EnrollmentStatus.IN_PROGRESS) { "Can only complete in-progress training" }

        this.actualCompletionDate = completionDate
        this.score = score
        this.passed = passed
        this.status = if (passed) EnrollmentStatus.COMPLETED else EnrollmentStatus.FAILED
        this.updatedAt = Instant.now()
    }

    fun cancel(reason: String) {
        require(status != EnrollmentStatus.COMPLETED) { "Cannot cancel completed training" }

        this.status = EnrollmentStatus.CANCELLED
        this.notes = "$notes\nCancellation: $reason"
        this.updatedAt = Instant.now()
    }

    fun issueCertificate(certificateUrl: String, issuedDate: LocalDate, validityMonths: Int?) {
        require(status == EnrollmentStatus.COMPLETED) { "Can only issue certificate for completed training" }
        require(passed == true) { "Can only issue certificate if training was passed" }

        this.certificateUrl = certificateUrl
        this.certificateIssuedDate = issuedDate
        this.certificateExpiryDate = validityMonths?.let { issuedDate.plusMonths(it.toLong()) }
        this.updatedAt = Instant.now()
    }
}

enum class EnrollmentStatus {
    ENROLLED, IN_PROGRESS, COMPLETED, FAILED, CANCELLED, WITHDRAWN
}
```

---

## Domain Events

### Employee Events

```kotlin
data class EmployeeHiredEvent(
    val eventId: UUID = UUID.randomUUID(),
    val employeeId: UUID,
    val employeeNumber: String,
    val fullName: String,
    val email: String,
    val departmentId: UUID?,
    val positionId: UUID?,
    val hireDate: LocalDate,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)

data class EmployeeTerminatedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val employeeId: UUID,
    val employeeNumber: String,
    val terminationDate: LocalDate,
    val reason: String?,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)

data class EmployeeTransferredEvent(
    val eventId: UUID = UUID.randomUUID(),
    val employeeId: UUID,
    val fromDepartmentId: UUID?,
    val toDepartmentId: UUID,
    val effectiveDate: LocalDate,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)

data class EmployeePromotedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val employeeId: UUID,
    val fromPositionId: UUID,
    val toPositionId: UUID,
    val effectiveDate: LocalDate,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)
```

### Leave Events

```kotlin
data class LeaveRequestSubmittedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val leaveRequestId: UUID,
    val requestNumber: String,
    val employeeId: UUID,
    val leaveType: LeaveType,
    val startDate: LocalDate,
    val endDate: LocalDate,
    val totalDays: BigDecimal,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)

data class LeaveRequestApprovedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val leaveRequestId: UUID,
    val employeeId: UUID,
    val approvedBy: UUID,
    val leaveType: LeaveType,
    val startDate: LocalDate,
    val endDate: LocalDate,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)

data class LeaveRequestRejectedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val leaveRequestId: UUID,
    val employeeId: UUID,
    val rejectedBy: UUID,
    val reason: String,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)
```

### Training Events

```kotlin
data class TrainingCompletedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val enrollmentId: UUID,
    val employeeId: UUID,
    val trainingProgramId: UUID,
    val completionDate: LocalDate,
    val score: BigDecimal?,
    val passed: Boolean,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)

data class CertificateIssuedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val enrollmentId: UUID,
    val employeeId: UUID,
    val trainingProgramId: UUID,
    val certificateUrl: String,
    val issuedDate: LocalDate,
    val expiryDate: LocalDate?,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)
```

---

## Integration Points

### With Financial Management Service

-   **Expense Management**: Employee expense reports and reimbursements
-   **Cost Center**: Department cost allocation
-   **Payroll**: Employee compensation and benefits

### With Core Platform Service

-   **Security**: User authentication and authorization
-   **Organization**: Multi-tenant organization structure
-   **Audit**: Comprehensive audit trails for HR operations

### With Operations Service

-   **Scheduling**: Technician availability and scheduling
-   **Field Service**: Employee assignments to service orders

### With Project Management

-   **Resource Allocation**: Employee assignment to projects
-   **Time Tracking**: Project time tracking and billing

---

## Business Rules

### Employee Management

1. Employee number must be unique across the organization
2. Email must be unique across the organization
3. An employee must belong to a department and have a position
4. Termination date must be on or after hire date
5. Only active employees can be assigned to projects or scheduled for work

### Leave Management

1. Employee cannot request leave for past dates
2. Leave requests cannot overlap for the same employee
3. Leave balance must be sufficient before approval
4. Half-day leave can only be taken on weekdays
5. Leave must be approved before it can be taken

### Performance Reviews

1. Reviews must be conducted by the employee's direct manager or above
2. Review period cannot overlap for the same employee
3. All sections must be scored before review can be completed
4. Employee must acknowledge completed reviews
5. Goals should be SMART (Specific, Measurable, Achievable, Relevant, Time-bound)

### Training & Development

1. Mandatory training must be completed within specified timeframe
2. Prerequisites must be met before enrolling in advanced training
3. Certificates have expiration dates and must be renewed
4. Training budget must be approved before enrollment
5. Training completion must be recorded and certificated

---

## Summary

The HR domain provides comprehensive employee lifecycle management from hire to retire, including:

-   **Complete employee master data** with personal, employment, and organizational information
-   **Hierarchical organizational structure** with departments and positions
-   **Time and attendance tracking** with check-in/check-out and overtime calculation
-   **Leave management** with balance tracking, approval workflows, and compliance
-   **Performance management** with reviews, goals, and ratings following SAP HCM patterns
-   **Training and development** with enrollment, completion tracking, and certification

The domain follows **world-class ERP patterns** with:

-   Multi-tenant architecture
-   Complete audit trails
-   Event-driven integration
-   SAP HCM-aligned processes
-   Compliance and regulatory support
-   Flexible approval workflows

This foundation enables the administration service to effectively manage human capital while integrating seamlessly with other ERP domains.
