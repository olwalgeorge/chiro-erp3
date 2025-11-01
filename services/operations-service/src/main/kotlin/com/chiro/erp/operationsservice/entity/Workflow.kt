package com.chiro.erp.operationsservice.entity

import io.quarkus.hibernate.reactive.panache.kotlin.PanacheEntity
import jakarta.persistence.*
import java.time.LocalDateTime

@Entity
@Table(name = "workflows")
class Workflow : PanacheEntity() {
    
    @Column(nullable = false, unique = true)
    lateinit var workflowName: String
    
    @Column(nullable = false)
    lateinit var description: String
    
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    lateinit var status: WorkflowStatus
    
    @Column
    var ownerId: String? = null
    
    @Column
    var priority: Int = 1
    
    @Column
    var estimatedDuration: Int? = null // in minutes
    
    @Column
    var actualDuration: Int? = null // in minutes
    
    @Column(nullable = false)
    lateinit var startDate: LocalDateTime
    
    @Column
    var endDate: LocalDateTime? = null
    
    @Column
    var dueDate: LocalDateTime? = null
    
    @Column(nullable = false)
    var createdAt: LocalDateTime = LocalDateTime.now()
    
    @Column(nullable = false)
    var updatedAt: LocalDateTime = LocalDateTime.now()
}

enum class WorkflowStatus {
    PENDING,
    IN_PROGRESS,
    ON_HOLD,
    COMPLETED,
    CANCELLED,
    FAILED
}
