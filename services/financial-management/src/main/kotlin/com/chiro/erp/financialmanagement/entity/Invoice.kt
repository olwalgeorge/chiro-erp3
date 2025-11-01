package com.chiro.erp.financialmanagement.entity

import io.quarkus.hibernate.reactive.panache.kotlin.PanacheEntity
import jakarta.persistence.*
import java.math.BigDecimal
import java.time.LocalDateTime

@Entity
@Table(name = "invoices")
class Invoice : PanacheEntity() {
    
    @Column(nullable = false, unique = true)
    lateinit var invoiceNumber: String
    
    @Column(nullable = false)
    lateinit var customerId: String
    
    @Column(nullable = false)
    lateinit var amount: BigDecimal
    
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    lateinit var status: InvoiceStatus
    
    @Column(nullable = false)
    lateinit var issueDate: LocalDateTime
    
    @Column
    var dueDate: LocalDateTime? = null
    
    @Column
    var paidDate: LocalDateTime? = null
    
    @Column
    var description: String? = null
    
    @Column(nullable = false)
    var createdAt: LocalDateTime = LocalDateTime.now()
    
    @Column(nullable = false)
    var updatedAt: LocalDateTime = LocalDateTime.now()
}

enum class InvoiceStatus {
    DRAFT,
    SENT,
    PAID,
    OVERDUE,
    CANCELLED
}
