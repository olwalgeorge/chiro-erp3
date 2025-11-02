# Domain Models - Project Management Domain

## Schema: `administration_schema`

This domain implements **world-class project management patterns** following PMI PMBOK (Project Management Body of Knowledge) and modern agile methodologies for enterprise-grade project delivery and resource management.

---

## Overview

The Project Management domain is responsible for managing the complete project lifecycle from initiation through closure, including project planning, resource allocation, budget tracking, risk management, and stakeholder communication.

### Key Responsibilities

-   Project portfolio management
-   Project planning and scheduling (WBS, Gantt charts)
-   Resource allocation and capacity planning
-   Budget and cost management
-   Time tracking and billing
-   Risk and issue management
-   Milestone and deliverable tracking
-   Stakeholder management and communication
-   Document and knowledge management
-   Project performance reporting and analytics

---

## Domain 1: Project Portfolio Management

### Aggregates

**Project (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "projects",
    schema = "administration_schema",
    indexes = [
        Index(name = "idx_project_code", columnList = "projectCode"),
        Index(name = "idx_project_status", columnList = "status"),
        Index(name = "idx_project_manager", columnList = "projectManagerId"),
        Index(name = "idx_project_client", columnList = "clientId"),
        Index(name = "idx_project_dates", columnList = "startDate,endDate")
    ]
)
class Project(
    @Id val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, unique = true)
    val projectCode: String, // PRJ-YYYY-NNNNNN

    @Column(nullable = false)
    var name: String,

    @Column(length = 5000)
    var description: String?,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    val projectType: ProjectType,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    var status: ProjectStatus,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    val priority: Priority,

    // Dates
    @Column(nullable = false)
    val startDate: LocalDate,

    @Column(nullable = false)
    var plannedEndDate: LocalDate,

    var actualEndDate: LocalDate? = null,

    // Stakeholders
    @Column(nullable = false)
    val projectManagerId: UUID,

    val projectSponsorId: UUID? = null,

    @ElementCollection
    @CollectionTable(
        name = "project_team_members",
        schema = "administration_schema",
        joinColumns = [JoinColumn(name = "project_id")]
    )
    @Column(name = "employee_id")
    val teamMemberIds: MutableSet<UUID> = mutableSetOf(),

    // Client/Customer
    val clientId: UUID? = null, // Reference to customer relationship service
    val clientContactId: UUID? = null,

    // Budget
    @Column(precision = 19, scale = 2)
    var budgetAmount: BigDecimal? = null,

    @Column(precision = 19, scale = 2)
    var actualCost: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false)
    val currency: String = "USD",

    @Enumerated(EnumType.STRING)
    val billingType: BillingType? = null,

    // Progress tracking
    @Column(precision = 5, scale = 2)
    var completionPercentage: BigDecimal = BigDecimal.ZERO,

    @Column(precision = 19, scale = 2)
    var earnedValue: BigDecimal = BigDecimal.ZERO,

    // Health indicators
    @Enumerated(EnumType.STRING)
    var healthStatus: HealthStatus = HealthStatus.GREEN,

    @Column(length = 2000)
    var healthComments: String? = null,

    // Relationships
    val parentProjectId: UUID? = null,

    @OneToMany(mappedBy = "project", cascade = [CascadeType.ALL])
    val milestones: MutableList<Milestone> = mutableListOf(),

    @OneToMany(mappedBy = "project", cascade = [CascadeType.ALL])
    val risks: MutableList<Risk> = mutableListOf(),

    @OneToMany(mappedBy = "project", cascade = [CascadeType.ALL])
    val issues: MutableList<Issue> = mutableListOf(),

    // Metadata
    @Column(length = 3000)
    var objectives: String? = null,

    @Column(length = 3000)
    var scope: String? = null,

    @Column(length = 2000)
    var assumptions: String? = null,

    @Column(length = 2000)
    var constraints: String? = null,

    @Column(length = 2000)
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

    @Column(nullable = false)
    val createdBy: UUID,

    var updatedBy: UUID? = null,

    @Version
    var version: Long = 0
) {
    companion object {
        fun generateProjectCode(year: Int, sequence: Long): String {
            return "PRJ-$year-${sequence.toString().padStart(6, '0')}"
        }
    }

    fun start(startedBy: UUID) {
        require(status == ProjectStatus.PLANNED) { "Only planned projects can be started" }

        this.status = ProjectStatus.IN_PROGRESS
        this.updatedAt = Instant.now()
        this.updatedBy = startedBy
    }

    fun complete(completionDate: LocalDate, completedBy: UUID) {
        require(status == ProjectStatus.IN_PROGRESS) { "Only in-progress projects can be completed" }

        this.status = ProjectStatus.COMPLETED
        this.actualEndDate = completionDate
        this.completionPercentage = BigDecimal(100)
        this.updatedAt = Instant.now()
        this.updatedBy = completedBy
    }

    fun cancel(reason: String, cancelledBy: UUID) {
        require(status != ProjectStatus.COMPLETED) { "Cannot cancel completed project" }
        require(status != ProjectStatus.CANCELLED) { "Project already cancelled" }

        this.status = ProjectStatus.CANCELLED
        this.notes = "$notes\nCancellation reason: $reason"
        this.updatedAt = Instant.now()
        this.updatedBy = cancelledBy
    }

    fun hold(reason: String, heldBy: UUID) {
        require(status == ProjectStatus.IN_PROGRESS) { "Only in-progress projects can be put on hold" }

        this.status = ProjectStatus.ON_HOLD
        this.notes = "$notes\nOn hold reason: $reason"
        this.updatedAt = Instant.now()
        this.updatedBy = heldBy
    }

    fun resume(resumedBy: UUID) {
        require(status == ProjectStatus.ON_HOLD) { "Only on-hold projects can be resumed" }

        this.status = ProjectStatus.IN_PROGRESS
        this.updatedAt = Instant.now()
        this.updatedBy = resumedBy
    }

    fun addTeamMember(employeeId: UUID) {
        teamMemberIds.add(employeeId)
        updatedAt = Instant.now()
    }

    fun removeTeamMember(employeeId: UUID) {
        teamMemberIds.remove(employeeId)
        updatedAt = Instant.now()
    }

    fun updateProgress(percentage: BigDecimal) {
        require(percentage >= BigDecimal.ZERO && percentage <= BigDecimal(100)) {
            "Completion percentage must be between 0 and 100"
        }

        this.completionPercentage = percentage
        this.updatedAt = Instant.now()
    }

    fun updateHealthStatus(status: HealthStatus, comments: String?) {
        this.healthStatus = status
        this.healthComments = comments
        this.updatedAt = Instant.now()
    }

    fun calculateBudgetVariance(): BigDecimal {
        return if (budgetAmount != null) {
            budgetAmount!! - actualCost
        } else {
            BigDecimal.ZERO
        }
    }

    fun calculateScheduleVariance(): Long {
        val today = LocalDate.now()
        return if (today.isAfter(plannedEndDate) && status != ProjectStatus.COMPLETED) {
            ChronoUnit.DAYS.between(plannedEndDate, today)
        } else {
            0
        }
    }

    fun isOverBudget(): Boolean {
        return budgetAmount != null && actualCost > budgetAmount!!
    }

    fun isBehindSchedule(): Boolean {
        return LocalDate.now().isAfter(plannedEndDate) && status == ProjectStatus.IN_PROGRESS
    }

    fun getDurationDays(): Long {
        val endDate = actualEndDate ?: LocalDate.now()
        return ChronoUnit.DAYS.between(startDate, endDate)
    }
}

enum class ProjectType {
    INTERNAL,           // Internal company projects
    CLIENT_PROJECT,     // External client projects
    PRODUCT_DEVELOPMENT,// Product development initiatives
    RESEARCH,           // Research and development
    INFRASTRUCTURE,     // Infrastructure projects
    MAINTENANCE,        // Maintenance projects
    CONSULTING,         // Consulting engagements
    OTHER
}

enum class ProjectStatus {
    DRAFT,              // Being planned
    PLANNED,            // Approved and ready to start
    IN_PROGRESS,        // Active
    ON_HOLD,            // Temporarily paused
    COMPLETED,          // Successfully completed
    CANCELLED,          // Cancelled before completion
    ARCHIVED            // Archived for historical reference
}

enum class Priority {
    CRITICAL,
    HIGH,
    MEDIUM,
    LOW
}

enum class HealthStatus {
    GREEN,      // On track
    YELLOW,     // At risk
    RED         // Critical issues
}

enum class BillingType {
    FIXED_PRICE,        // Fixed price contract
    TIME_AND_MATERIALS, // Hourly billing
    RETAINER,           // Monthly retainer
    NON_BILLABLE       // Internal project
}
```

---

## Domain 2: Work Breakdown Structure (WBS)

### Aggregates

**Task (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "project_tasks",
    schema = "administration_schema",
    indexes = [
        Index(name = "idx_task_project", columnList = "projectId"),
        Index(name = "idx_task_parent", columnList = "parentTaskId"),
        Index(name = "idx_task_assignee", columnList = "assigneeId"),
        Index(name = "idx_task_status", columnList = "status"),
        Index(name = "idx_task_dates", columnList = "startDate,dueDate")
    ]
)
class Task(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "project_id", nullable = false)
    val project: Project,

    @Column(nullable = false)
    val taskNumber: String, // TSK-NNNNNN

    @Column(nullable = false)
    var name: String,

    @Column(length = 3000)
    var description: String?,

    // Hierarchical structure (WBS)
    @ManyToOne
    @JoinColumn(name = "parent_task_id")
    var parentTask: Task? = null,

    @OneToMany(mappedBy = "parentTask")
    val subTasks: MutableSet<Task> = mutableSetOf(),

    @Column(nullable = false)
    val wbsCode: String, // e.g., "1.2.3" for hierarchical identification

    // Assignment
    var assigneeId: UUID? = null,

    @ElementCollection
    @CollectionTable(
        name = "task_assignees",
        schema = "administration_schema",
        joinColumns = [JoinColumn(name = "task_id")]
    )
    @Column(name = "employee_id")
    val additionalAssignees: MutableSet<UUID> = mutableSetOf(),

    // Scheduling
    @Column(nullable = false)
    val startDate: LocalDate,

    @Column(nullable = false)
    var dueDate: LocalDate,

    var actualStartDate: LocalDate? = null,
    var actualEndDate: LocalDate? = null,

    @Column(precision = 8, scale = 2)
    val estimatedHours: BigDecimal,

    @Column(precision = 8, scale = 2)
    var actualHours: BigDecimal = BigDecimal.ZERO,

    // Status
    @Enumerated(EnumType.STRING)
    var status: TaskStatus = TaskStatus.NOT_STARTED,

    @Enumerated(EnumType.STRING)
    val priority: Priority,

    @Column(precision = 5, scale = 2)
    var completionPercentage: BigDecimal = BigDecimal.ZERO,

    // Dependencies
    @ManyToMany
    @JoinTable(
        name = "task_dependencies",
        schema = "administration_schema",
        joinColumns = [JoinColumn(name = "task_id")],
        inverseJoinColumns = [JoinColumn(name = "predecessor_task_id")]
    )
    val predecessors: MutableSet<Task> = mutableSetOf(),

    @Enumerated(EnumType.STRING)
    val dependencyType: DependencyType? = null,

    // Cost
    @Column(precision = 19, scale = 2)
    var estimatedCost: BigDecimal? = null,

    @Column(precision = 19, scale = 2)
    var actualCost: BigDecimal = BigDecimal.ZERO,

    // Billing
    val isBillable: Boolean = false,

    @Column(precision = 19, scale = 2)
    var billableAmount: BigDecimal? = null,

    // Metadata
    @Column(length = 2000)
    var notes: String? = null,

    @ElementCollection
    @CollectionTable(
        name = "task_tags",
        schema = "administration_schema",
        joinColumns = [JoinColumn(name = "task_id")]
    )
    @Column(name = "tag")
    val tags: MutableSet<String> = mutableSetOf(),

    // Multi-tenancy
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
    fun start(startedBy: UUID) {
        require(status == TaskStatus.NOT_STARTED || status == TaskStatus.READY) {
            "Can only start tasks that are not started or ready"
        }

        this.status = TaskStatus.IN_PROGRESS
        this.actualStartDate = LocalDate.now()
        this.updatedAt = Instant.now()
        this.updatedBy = startedBy
    }

    fun complete(completedBy: UUID) {
        require(status == TaskStatus.IN_PROGRESS) { "Only in-progress tasks can be completed" }

        this.status = TaskStatus.COMPLETED
        this.actualEndDate = LocalDate.now()
        this.completionPercentage = BigDecimal(100)
        this.updatedAt = Instant.now()
        this.updatedBy = completedBy
    }

    fun block(reason: String, blockedBy: UUID) {
        this.status = TaskStatus.BLOCKED
        this.notes = "$notes\nBlocked: $reason"
        this.updatedAt = Instant.now()
        this.updatedBy = blockedBy
    }

    fun unblock(unblockedBy: UUID) {
        require(status == TaskStatus.BLOCKED) { "Only blocked tasks can be unblocked" }

        this.status = TaskStatus.IN_PROGRESS
        this.updatedAt = Instant.now()
        this.updatedBy = unblockedBy
    }

    fun assign(employeeId: UUID) {
        this.assigneeId = employeeId
        this.updatedAt = Instant.now()
    }

    fun updateProgress(percentage: BigDecimal) {
        require(percentage >= BigDecimal.ZERO && percentage <= BigDecimal(100)) {
            "Completion percentage must be between 0 and 100"
        }

        this.completionPercentage = percentage
        this.updatedAt = Instant.now()
    }

    fun logTime(hours: BigDecimal) {
        this.actualHours = this.actualHours.add(hours)
        this.updatedAt = Instant.now()
    }

    fun addPredecessor(task: Task) {
        predecessors.add(task)
        updatedAt = Instant.now()
    }

    fun isOverdue(): Boolean {
        return LocalDate.now().isAfter(dueDate) && status != TaskStatus.COMPLETED
    }

    fun getVarianceHours(): BigDecimal {
        return estimatedHours - actualHours
    }

    fun canStart(): Boolean {
        // Check if all predecessors are completed
        return predecessors.all { it.status == TaskStatus.COMPLETED }
    }
}

enum class TaskStatus {
    NOT_STARTED,
    READY,          // Ready to start (dependencies met)
    IN_PROGRESS,
    BLOCKED,        // Blocked by dependency or issue
    COMPLETED,
    CANCELLED
}

enum class DependencyType {
    FINISH_TO_START,    // Predecessor must finish before successor can start
    START_TO_START,     // Predecessor must start before successor can start
    FINISH_TO_FINISH,   // Predecessor must finish before successor can finish
    START_TO_FINISH     // Predecessor must start before successor can finish (rare)
}
```

---

## Domain 3: Resource Management

### Aggregates

**ResourceAllocation (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "resource_allocations",
    schema = "administration_schema",
    indexes = [
        Index(name = "idx_allocation_project", columnList = "projectId"),
        Index(name = "idx_allocation_employee", columnList = "employeeId"),
        Index(name = "idx_allocation_dates", columnList = "startDate,endDate")
    ]
)
class ResourceAllocation(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "project_id", nullable = false)
    val project: Project,

    @ManyToOne
    @JoinColumn(name = "task_id")
    val task: Task? = null,

    @Column(nullable = false)
    val employeeId: UUID,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    val role: ResourceRole,

    @Column(nullable = false)
    val startDate: LocalDate,

    @Column(nullable = false)
    var endDate: LocalDate,

    // Allocation percentage (0-100%)
    @Column(nullable = false, precision = 5, scale = 2)
    var allocationPercentage: BigDecimal,

    // Hours per day/week/month
    @Column(precision = 5, scale = 2)
    var hoursPerWeek: BigDecimal? = null,

    // Cost
    @Column(precision = 19, scale = 2)
    val hourlyRate: BigDecimal? = null,

    @Column(precision = 19, scale = 2)
    var estimatedCost: BigDecimal? = null,

    @Column(precision = 19, scale = 2)
    var actualCost: BigDecimal = BigDecimal.ZERO,

    // Status
    @Enumerated(EnumType.STRING)
    var status: AllocationStatus = AllocationStatus.PLANNED,

    @Column(length = 1000)
    var notes: String? = null,

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
    init {
        calculateEstimatedCost()
    }

    private fun calculateEstimatedCost() {
        if (hourlyRate != null && hoursPerWeek != null) {
            val weeks = ChronoUnit.WEEKS.between(startDate, endDate)
            estimatedCost = hourlyRate!!.multiply(hoursPerWeek).multiply(BigDecimal(weeks))
        }
    }

    fun updateAllocation(percentage: BigDecimal, hoursPerWeek: BigDecimal?) {
        this.allocationPercentage = percentage
        this.hoursPerWeek = hoursPerWeek
        calculateEstimatedCost()
        this.updatedAt = Instant.now()
    }

    fun activate() {
        require(status == AllocationStatus.PLANNED) { "Only planned allocations can be activated" }

        this.status = AllocationStatus.ACTIVE
        this.updatedAt = Instant.now()
    }

    fun complete() {
        require(status == AllocationStatus.ACTIVE) { "Only active allocations can be completed" }

        this.status = AllocationStatus.COMPLETED
        this.updatedAt = Instant.now()
    }

    fun getUtilizationHours(actualWorkedHours: BigDecimal): BigDecimal {
        val totalAllocatedHours = if (hoursPerWeek != null) {
            val weeks = ChronoUnit.WEEKS.between(startDate, endDate)
            hoursPerWeek!!.multiply(BigDecimal(weeks))
        } else {
            BigDecimal.ZERO
        }

        return if (totalAllocatedHours > BigDecimal.ZERO) {
            actualWorkedHours.divide(totalAllocatedHours, 2, RoundingMode.HALF_UP).multiply(BigDecimal(100))
        } else {
            BigDecimal.ZERO
        }
    }
}

enum class ResourceRole {
    PROJECT_MANAGER,
    TECHNICAL_LEAD,
    ARCHITECT,
    DEVELOPER,
    DESIGNER,
    ANALYST,
    TESTER,
    CONSULTANT,
    SUBJECT_MATTER_EXPERT,
    OTHER
}

enum class AllocationStatus {
    PLANNED,
    ACTIVE,
    COMPLETED,
    CANCELLED
}
```

**TimeSheet (Entity)**

```kotlin
@Entity
@Table(
    name = "time_sheets",
    schema = "administration_schema",
    indexes = [
        Index(name = "idx_timesheet_project", columnList = "projectId"),
        Index(name = "idx_timesheet_task", columnList = "taskId"),
        Index(name = "idx_timesheet_employee", columnList = "employeeId"),
        Index(name = "idx_timesheet_date", columnList = "workDate"),
        Index(name = "idx_timesheet_status", columnList = "status")
    ]
)
class TimeSheet(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "project_id", nullable = false)
    val project: Project,

    @ManyToOne
    @JoinColumn(name = "task_id")
    val task: Task? = null,

    @Column(nullable = false)
    val employeeId: UUID,

    @Column(nullable = false)
    val workDate: LocalDate,

    @Column(nullable = false, precision = 5, scale = 2)
    var hours: BigDecimal,

    @Enumerated(EnumType.STRING)
    val activityType: ActivityType,

    @Column(length = 2000)
    var description: String?,

    val isBillable: Boolean = true,

    @Column(precision = 19, scale = 2)
    var billingRate: BigDecimal? = null,

    @Column(precision = 19, scale = 2)
    var billableAmount: BigDecimal? = null,

    @Enumerated(EnumType.STRING)
    var status: TimeSheetStatus = TimeSheetStatus.DRAFT,

    var submittedAt: Instant? = null,
    var approvedBy: UUID? = null,
    var approvedAt: Instant? = null,

    @Column(length = 1000)
    var approvalComments: String? = null,

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
    init {
        calculateBillableAmount()
    }

    private fun calculateBillableAmount() {
        if (isBillable && billingRate != null) {
            billableAmount = hours.multiply(billingRate)
        }
    }

    fun submit() {
        require(status == TimeSheetStatus.DRAFT) { "Only draft timesheets can be submitted" }

        this.status = TimeSheetStatus.SUBMITTED
        this.submittedAt = Instant.now()
        this.updatedAt = Instant.now()
    }

    fun approve(approverId: UUID, comments: String? = null) {
        require(status == TimeSheetStatus.SUBMITTED) { "Only submitted timesheets can be approved" }

        this.status = TimeSheetStatus.APPROVED
        this.approvedBy = approverId
        this.approvedAt = Instant.now()
        this.approvalComments = comments
        this.updatedAt = Instant.now()
    }

    fun reject(approverId: UUID, reason: String) {
        require(status == TimeSheetStatus.SUBMITTED) { "Only submitted timesheets can be rejected" }

        this.status = TimeSheetStatus.REJECTED
        this.approvedBy = approverId
        this.approvalComments = reason
        this.updatedAt = Instant.now()
    }

    fun updateHours(newHours: BigDecimal) {
        require(status == TimeSheetStatus.DRAFT) { "Only draft timesheets can be updated" }

        this.hours = newHours
        calculateBillableAmount()
        this.updatedAt = Instant.now()
    }
}

enum class ActivityType {
    DEVELOPMENT,
    DESIGN,
    ANALYSIS,
    TESTING,
    DOCUMENTATION,
    MEETING,
    PLANNING,
    RESEARCH,
    SUPPORT,
    ADMINISTRATION,
    OTHER
}

enum class TimeSheetStatus {
    DRAFT,
    SUBMITTED,
    APPROVED,
    REJECTED,
    INVOICED
}
```

---

## Domain 4: Milestones & Deliverables

### Aggregates

**Milestone (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "project_milestones",
    schema = "administration_schema",
    indexes = [
        Index(name = "idx_milestone_project", columnList = "projectId"),
        Index(name = "idx_milestone_date", columnList = "targetDate"),
        Index(name = "idx_milestone_status", columnList = "status")
    ]
)
class Milestone(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "project_id", nullable = false)
    var project: Project? = null,

    @Column(nullable = false)
    var name: String,

    @Column(length = 2000)
    var description: String?,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    val type: MilestoneType,

    @Column(nullable = false)
    val targetDate: LocalDate,

    var actualDate: LocalDate? = null,

    @Enumerated(EnumType.STRING)
    var status: MilestoneStatus = MilestoneStatus.PLANNED,

    @Column(precision = 5, scale = 2)
    var completionPercentage: BigDecimal = BigDecimal.ZERO,

    // Success criteria
    @ElementCollection
    @CollectionTable(
        name = "milestone_criteria",
        schema = "administration_schema",
        joinColumns = [JoinColumn(name = "milestone_id")]
    )
    @Column(name = "criterion", length = 500)
    val successCriteria: MutableList<String> = mutableListOf(),

    // Deliverables
    @OneToMany(mappedBy = "milestone", cascade = [CascadeType.ALL])
    val deliverables: MutableList<Deliverable> = mutableListOf(),

    val ownerId: UUID? = null,

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
    fun start() {
        require(status == MilestoneStatus.PLANNED) { "Only planned milestones can be started" }

        this.status = MilestoneStatus.IN_PROGRESS
        this.updatedAt = Instant.now()
    }

    fun complete(completionDate: LocalDate) {
        require(status == MilestoneStatus.IN_PROGRESS) { "Only in-progress milestones can be completed" }

        this.status = MilestoneStatus.COMPLETED
        this.actualDate = completionDate
        this.completionPercentage = BigDecimal(100)
        this.updatedAt = Instant.now()
    }

    fun addSuccessCriterion(criterion: String) {
        successCriteria.add(criterion)
        updatedAt = Instant.now()
    }

    fun addDeliverable(deliverable: Deliverable) {
        deliverables.add(deliverable)
        deliverable.milestone = this
        updatedAt = Instant.now()
    }

    fun isOverdue(): Boolean {
        return LocalDate.now().isAfter(targetDate) && status != MilestoneStatus.COMPLETED
    }

    fun getDaysUntilDue(): Long {
        return ChronoUnit.DAYS.between(LocalDate.now(), targetDate)
    }
}

@Entity
@Table(name = "milestone_deliverables", schema = "administration_schema")
class Deliverable(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "milestone_id", nullable = false)
    var milestone: Milestone? = null,

    @Column(nullable = false)
    var name: String,

    @Column(length = 2000)
    var description: String?,

    @Enumerated(EnumType.STRING)
    val type: DeliverableType,

    var dueDate: LocalDate? = null,
    var deliveryDate: LocalDate? = null,

    @Enumerated(EnumType.STRING)
    var status: DeliverableStatus = DeliverableStatus.NOT_STARTED,

    val ownerId: UUID? = null,

    // Document reference
    val documentUrl: String? = null,
    val documentVersion: String? = null,

    // Quality checks
    val requiresReview: Boolean = false,
    var reviewedBy: UUID? = null,
    var reviewedAt: Instant? = null,
    var reviewComments: String? = null,

    @Column(length = 1000)
    var notes: String? = null,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Column(nullable = false)
    var updatedAt: Instant = Instant.now()
)

enum class MilestoneType {
    PROJECT_START,
    PROJECT_END,
    PHASE_COMPLETION,
    DELIVERABLE,
    REVIEW_GATE,
    PAYMENT_TRIGGER,
    CUSTOM
}

enum class MilestoneStatus {
    PLANNED,
    IN_PROGRESS,
    COMPLETED,
    DELAYED,
    CANCELLED
}

enum class DeliverableType {
    DOCUMENT,
    SOFTWARE,
    DESIGN,
    REPORT,
    PRESENTATION,
    TRAINING,
    OTHER
}

enum class DeliverableStatus {
    NOT_STARTED,
    IN_PROGRESS,
    REVIEW,
    COMPLETED,
    REJECTED
}
```

---

## Domain 5: Risk & Issue Management

### Aggregates

**Risk (Aggregate Root)**

````kotlin
@Entity
@Table(
    name = "project_risks",
    schema = "administration_schema",
    indexes = [
        Index(name = "idx_risk_project", columnList = "projectId"),
        Index(name = "idx_risk_status", columnList = "status"),
        Index(name = "idx_risk_severity", columnList = "severity")
    ]
)
class Risk(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "project_id", nullable = false)
    var project: Project? = null,

    @Column(nullable = false, unique = true)
    val riskNumber: String, // RSK-NNNNNN

    @Column(nullable = false)
    var title: String,

    @Column(length = 3000)
    var description: String?,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    val category: RiskCategory,

    // Risk assessment
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    var probability: Probability,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    var impact: Impact,

    @Column(nullable = false)
    var riskScore: Int, // probability * impact (1-25)

    @Enumerated(EnumType.STRING)
    var severity: Severity, // Based on score

    // Dates
    @Column(nullable = false)
    val identifiedDate: LocalDate,

    var targetResolutionDate: LocalDate? = null,
    var actualResolutionDate: LocalDate? = null,

    // Ownership
    @Column(nullable = false)
    val identifiedBy: UUID,

    var ownerId: UUID? = null,

    // Mitigation
    @Column(length = 3000)
    var mitigationStrategy: String?,

    @Column(length = 3000)
    var contingencyPlan: String?,

    @Column(precision = 19, scale = 2)
    var estimatedCostImpact: BigDecimal? = null,

    var estimatedScheduleImpact: Int? = null, // Days

    // Status
    @Enumerated(EnumType.STRING)
    var status: RiskStatus = RiskStatus.IDENTIFIED,

    @Column(length = 2000)
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
    companion object {
        fun generateRiskNumber(sequence: Long): String {
            return "RSK-${sequence.toString().padStart(6, '0')}"
        }
    }

    init {
        calculateRiskScore()
    }

    fun calculateRiskScore() {
        riskScore = probability.value * impact.value
        severity = when {
            riskScore >= 15 -> Severity.CRITICAL
            riskScore >= 10 -> Severity.HIGH
            riskScore >= 5 -> Severity.MEDIUM
            else -> Severity.LOW
        }
    }

    fun updateAssessment(probability: Probability, impact: Impact) {
        this.probability = probability
        this.impact = impact
        calculateRiskScore()
        this.updatedAt = Instant.now()
    }

    fun mitigate(strategy: String) {
        this.mitigationStrategy = strategy
        this.status = RiskStatus.MITIGATING
        this.updatedAt = Instant.now()
    }

    fun resolve(resolutionDate: LocalDate) {
        this.status = RiskStatus.RESOLVED
        this.actualResolutionDate = resolutionDate
        this.updatedAt = Instant.now()
    }

    fun realize() {
        // Risk has materialized into an issue
        this.status = RiskStatus.REALIZED
        this.updatedAt = Instant.now()
    }

    fun close() {
        require(status == RiskStatus.RESOLVED || status == RiskStatus.MITIGATED) {
            "Only resolved or mitigated risks can be closed"
        }

        this.status = RiskStatus.CLOSED
        this.updatedAt = Instant.now()
    }
}

**Issue (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "project_issues",
    schema = "administration_schema",
    indexes = [
        Index(name = "idx_issue_project", columnList = "projectId"),
        Index(name = "idx_issue_status", columnList = "status"),
        Index(name = "idx_issue_priority", columnList = "priority")
    ]
)
class Issue(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "project_id", nullable = false)
    var project: Project? = null,

    @Column(nullable = false, unique = true)
    val issueNumber: String, // ISS-NNNNNN

    @Column(nullable = false)
    var title: String,

    @Column(length = 3000)
    var description: String?,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    val category: IssueCategory,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    var priority: Priority,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    var severity: Severity,

    // Dates
    @Column(nullable = false)
    val reportedDate: LocalDate,

    var targetResolutionDate: LocalDate? = null,
    var actualResolutionDate: LocalDate? = null,

    // Ownership
    @Column(nullable = false)
    val reportedBy: UUID,

    var assignedTo: UUID? = null,

    // Resolution
    @Column(length = 3000)
    var resolutionDescription: String?,

    @Column(length = 2000)
    var rootCause: String?,

    // Impact
    @Column(precision = 19, scale = 2)
    var actualCostImpact: BigDecimal? = null,

    var actualScheduleImpact: Int? = null, // Days

    // Related entities
    val relatedRiskId: UUID? = null,
    val relatedTaskId: UUID? = null,

    // Status
    @Enumerated(EnumType.STRING)
    var status: IssueStatus = IssueStatus.OPEN,

    @Column(length = 2000)
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
    companion object {
        fun generateIssueNumber(sequence: Long): String {
            return "ISS-${sequence.toString().padStart(6, '0')}"
        }
    }

    fun assign(employeeId: UUID) {
        this.assignedTo = employeeId
        this.status = IssueStatus.ASSIGNED
        this.updatedAt = Instant.now()
    }

    fun startWorking() {
        require(status == IssueStatus.ASSIGNED || status == IssueStatus.OPEN) {
            "Only open or assigned issues can be worked on"
        }

        this.status = IssueStatus.IN_PROGRESS
        this.updatedAt = Instant.now()
    }

    fun resolve(resolution: String, rootCause: String?, resolvedBy: UUID) {
        require(status == IssueStatus.IN_PROGRESS) {
            "Only in-progress issues can be resolved"
        }

        this.status = IssueStatus.RESOLVED
        this.resolutionDescription = resolution
        this.rootCause = rootCause
        this.actualResolutionDate = LocalDate.now()
        this.updatedAt = Instant.now()
    }

    fun close(closedBy: UUID) {
        require(status == IssueStatus.RESOLVED) { "Only resolved issues can be closed" }

        this.status = IssueStatus.CLOSED
        this.updatedAt = Instant.now()
    }

    fun reopen(reason: String, reopenedBy: UUID) {
        require(status == IssueStatus.CLOSED || status == IssueStatus.RESOLVED) {
            "Only closed or resolved issues can be reopened"
        }

        this.status = IssueStatus.OPEN
        this.notes = "$notes\nReopened: $reason"
        this.updatedAt = Instant.now()
    }

    fun isOverdue(): Boolean {
        return targetResolutionDate != null &&
            LocalDate.now().isAfter(targetResolutionDate) &&
            status != IssueStatus.RESOLVED &&
            status != IssueStatus.CLOSED
    }

    fun getAgeDays(): Long {
        val endDate = actualResolutionDate ?: LocalDate.now()
        return ChronoUnit.DAYS.between(reportedDate, endDate)
    }
}

enum class RiskCategory {
    TECHNICAL,
    SCHEDULE,
    BUDGET,
    RESOURCE,
    SCOPE,
    QUALITY,
    EXTERNAL,
    STAKEHOLDER,
    LEGAL_COMPLIANCE,
    OTHER
}

enum class Probability {
    VERY_LOW(1),
    LOW(2),
    MEDIUM(3),
    HIGH(4),
    VERY_HIGH(5);

    val value: Int
    constructor(value: Int) {
        this.value = value
    }
}

enum class Impact {
    VERY_LOW(1),
    LOW(2),
    MEDIUM(3),
    HIGH(4),
    VERY_HIGH(5);

    val value: Int
    constructor(value: Int) {
        this.value = value
    }
}

enum class Severity {
    LOW,
    MEDIUM,
    HIGH,
    CRITICAL
}

enum class RiskStatus {
    IDENTIFIED,
    ASSESSING,
    MITIGATING,
    MITIGATED,
    MONITORING,
    RESOLVED,
    REALIZED,       // Risk has become an issue
    CLOSED
}

enum class IssueCategory {
    TECHNICAL,
    SCOPE,
    SCHEDULE,
    BUDGET,
    RESOURCE,
    QUALITY,
    COMMUNICATION,
    STAKEHOLDER,
    EXTERNAL,
    OTHER
}

enum class IssueStatus {
    OPEN,
    ASSIGNED,
    IN_PROGRESS,
    RESOLVED,
    CLOSED,
    CANCELLED
}
````

---

## Domain 6: Project Budget & Financials

### Aggregates

**ProjectBudget (Aggregate Root)**

```kotlin
@Entity
@Table(
    name = "project_budgets",
    schema = "administration_schema",
    indexes = [
        Index(name = "idx_budget_project", columnList = "projectId"),
        Index(name = "idx_budget_category", columnList = "category")
    ]
)
class ProjectBudget(
    @Id val id: UUID = UUID.randomUUID(),

    @ManyToOne
    @JoinColumn(name = "project_id", nullable = false)
    val project: Project,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    val category: BudgetCategory,

    @Column(precision = 19, scale = 2, nullable = false)
    var budgetedAmount: BigDecimal,

    @Column(precision = 19, scale = 2)
    var committedAmount: BigDecimal = BigDecimal.ZERO,

    @Column(precision = 19, scale = 2)
    var actualAmount: BigDecimal = BigDecimal.ZERO,

    @Column(nullable = false)
    val currency: String = "USD",

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
    fun recordCommitment(amount: BigDecimal) {
        this.committedAmount = this.committedAmount.add(amount)
        this.updatedAt = Instant.now()
    }

    fun recordActual(amount: BigDecimal) {
        this.actualAmount = this.actualAmount.add(amount)
        this.updatedAt = Instant.now()
    }

    fun getAvailableAmount(): BigDecimal {
        return budgetedAmount - committedAmount
    }

    fun getVariance(): BigDecimal {
        return budgetedAmount - actualAmount
    }

    fun getVariancePercentage(): BigDecimal {
        return if (budgetedAmount > BigDecimal.ZERO) {
            getVariance().divide(budgetedAmount, 4, RoundingMode.HALF_UP).multiply(BigDecimal(100))
        } else {
            BigDecimal.ZERO
        }
    }

    fun isOverBudget(): Boolean {
        return actualAmount > budgetedAmount
    }
}

enum class BudgetCategory {
    LABOR,
    MATERIALS,
    EQUIPMENT,
    SOFTWARE,
    TRAVEL,
    CONSULTING,
    TRAINING,
    FACILITIES,
    OVERHEAD,
    CONTINGENCY,
    OTHER
}
```

---

## Domain Events

### Project Events

```kotlin
data class ProjectCreatedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val projectId: UUID,
    val projectCode: String,
    val projectName: String,
    val projectManagerId: UUID,
    val startDate: LocalDate,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)

data class ProjectStartedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val projectId: UUID,
    val projectCode: String,
    val startedBy: UUID,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)

data class ProjectCompletedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val projectId: UUID,
    val projectCode: String,
    val completionDate: LocalDate,
    val completedBy: UUID,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)

data class ProjectStatusChangedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val projectId: UUID,
    val projectCode: String,
    val oldStatus: ProjectStatus,
    val newStatus: ProjectStatus,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)
```

### Task Events

```kotlin
data class TaskCreatedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val taskId: UUID,
    val projectId: UUID,
    val taskName: String,
    val assigneeId: UUID?,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)

data class TaskAssignedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val taskId: UUID,
    val projectId: UUID,
    val assigneeId: UUID,
    val assignedBy: UUID,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)

data class TaskCompletedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val taskId: UUID,
    val projectId: UUID,
    val completedBy: UUID,
    val actualHours: BigDecimal,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)
```

### Milestone Events

```kotlin
data class MilestoneCompletedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val milestoneId: UUID,
    val projectId: UUID,
    val milestoneName: String,
    val completionDate: LocalDate,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)

data class MilestoneDelayedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val milestoneId: UUID,
    val projectId: UUID,
    val milestoneName: String,
    val targetDate: LocalDate,
    val delayDays: Long,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)
```

### Risk Events

```kotlin
data class RiskIdentifiedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val riskId: UUID,
    val projectId: UUID,
    val riskTitle: String,
    val severity: Severity,
    val identifiedBy: UUID,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)

data class RiskRealizedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val riskId: UUID,
    val projectId: UUID,
    val riskTitle: String,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)
```

### Issue Events

```kotlin
data class IssueReportedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val issueId: UUID,
    val projectId: UUID,
    val issueTitle: String,
    val severity: Severity,
    val reportedBy: UUID,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)

data class IssueResolvedEvent(
    val eventId: UUID = UUID.randomUUID(),
    val issueId: UUID,
    val projectId: UUID,
    val resolution: String,
    val resolvedBy: UUID,
    val resolutionDate: LocalDate,
    val tenantId: UUID,
    val occurredAt: Instant = Instant.now()
)
```

---

## Integration Points

### With HR Domain (Administration Service)

-   **Resource Management**: Employee availability, skills, and capacity
-   **Time Tracking**: Employee time entries for projects
-   **Performance Management**: Project contributions to performance reviews
-   **Leave Management**: Resource availability based on approved leave

### With Financial Management Service

-   **Budget Management**: Project budgets and cost allocation
-   **Billing**: Client invoicing for billable projects
-   **Expense Management**: Project-related expenses and reimbursements
-   **Cost Accounting**: Project cost tracking and profitability analysis

### With Core Platform Service

-   **Security**: User authentication and project access control
-   **Organization**: Multi-tenant organization structure
-   **Audit**: Comprehensive audit trails for project operations
-   **Notification**: Project notifications and alerts

### With Customer Relationship Service

-   **Client Management**: Client project assignments
-   **CRM Integration**: Project opportunities and sales pipeline

### With Operations Service

-   **Field Service**: Service project management
-   **Scheduling**: Resource scheduling for project tasks

---

## Business Rules

### Project Management

1. Project code must be unique across the organization
2. Project must have a project manager assigned
3. Project start date must be before or equal to end date
4. Only planned projects can be started
5. Projects cannot be deleted after they are started (only cancelled)
6. Project status must follow valid state transitions

### Task Management

1. Task WBS code must be unique within a project
2. Tasks cannot start before their predecessors are completed (based on dependency type)
3. Tasks cannot be assigned to employees not on the project team
4. Task completion percentage must be between 0 and 100
5. Parent task completion is calculated from child tasks

### Resource Management

1. Resource allocation percentage must be between 0 and 100
2. Total allocation for an employee cannot exceed 100% across all projects
3. Resource allocation dates must fall within project dates
4. Only active employees can be allocated to projects

### Time Tracking

1. Time sheets can only be created for allocated resources
2. Time sheet hours must be positive
3. Time sheets must be submitted before approval
4. Approved time sheets cannot be modified
5. Time sheet date must be within project dates

### Budget Management

1. Budget categories must be defined before recording actuals
2. Budget cannot be decreased below actual spent amount
3. Budget alerts when 80% and 100% thresholds are reached
4. All project costs must be categorized

### Milestone Management

1. Milestones must have unique names within a project
2. Milestone dates must be within project timeline
3. All deliverables must be completed before milestone completion
4. Phase milestones must be in sequence

### Risk & Issue Management

1. Risks must have probability and impact assessments
2. Risk severity is automatically calculated from probability × impact
3. High severity risks require mitigation plans
4. Issues must be assigned to a team member
5. Issues cannot be closed without resolution description

---

## Summary

The Project Management domain provides comprehensive project delivery capabilities including:

-   **Complete project lifecycle management** from initiation through closure
-   **Work breakdown structure (WBS)** with task hierarchies and dependencies
-   **Resource allocation and capacity planning** with conflict detection
-   **Time tracking and billing** with approval workflows
-   **Milestone and deliverable tracking** with success criteria
-   **Risk and issue management** with severity assessments and mitigation strategies
-   **Budget tracking and cost management** with variance analysis
-   **Project portfolio view** with health status and performance metrics

The domain follows **world-class project management patterns** with:

-   Multi-tenant architecture
-   PMI PMBOK alignment
-   Agile and waterfall methodology support
-   Complete audit trails
-   Event-driven integration
-   Real-time project health monitoring
-   Resource utilization analytics
-   Earned value management (EVM)
-   Critical path analysis support

This foundation enables the administration service to effectively manage projects while integrating seamlessly with other ERP domains for a complete enterprise solution.
