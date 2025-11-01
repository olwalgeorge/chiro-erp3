package com.chiro.erp.operationsservice.entity

import io.quarkus.hibernate.reactive.panache.kotlin.PanacheEntity
import jakarta.persistence.*
import java.time.LocalDateTime

@Entity
@Table(name = "tasks")
class Task : PanacheEntity() {
    
    @Column(nullable = false)
    lateinit var title: String
    
    @Column
    var description: String? = null
    
    @Column
    var workflowId: Long? = null
    
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    lateinit var status: TaskStatus
    
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    lateinit var priority: TaskPriority
    
    @Column
    var assigneeId: String? = null
    
    @Column
    var estimatedHours: Int? = null
    
    @Column
    var actualHours: Int? = null
    
    @Column
    var startDate: LocalDateTime? = null
    
    @Column
    var endDate: LocalDateTime? = null
    
    @Column
    var dueDate: LocalDateTime? = null
    
    @Column(nullable = false)
    var createdAt: LocalDateTime = LocalDateTime.now()
    
    @Column(nullable = false)
    var updatedAt: LocalDateTime = LocalDateTime.now()
}

enum class TaskStatus {
    BACKLOG,
    TODO,
    IN_PROGRESS,
    REVIEW,
    DONE,
    CANCELLED
}

enum class TaskPriority {
    LOW,
    MEDIUM,
    HIGH,
    URGENT
}
