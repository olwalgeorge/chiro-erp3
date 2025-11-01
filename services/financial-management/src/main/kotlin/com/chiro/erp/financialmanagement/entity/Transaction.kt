package com.chiro.erp.financialmanagement.entity

import io.quarkus.hibernate.reactive.panache.kotlin.PanacheEntity
import jakarta.persistence.*
import java.math.BigDecimal
import java.time.LocalDateTime

@Entity
@Table(name = "transactions")
class Transaction : PanacheEntity() {
    @Column(nullable = false, unique = true)
    lateinit var transactionNumber: String

    @Column(nullable = false)
    lateinit var accountId: String

    @Column(nullable = false)
    lateinit var amount: BigDecimal

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    lateinit var type: TransactionType

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    lateinit var status: TransactionStatus

    @Column(nullable = false)
    lateinit var transactionDate: LocalDateTime

    @Column
    var description: String? = null

    @Column
    var referenceNumber: String? = null

    @Column(nullable = false)
    var createdAt: LocalDateTime = LocalDateTime.now()

    @Column(nullable = false)
    var updatedAt: LocalDateTime = LocalDateTime.now()
}

enum class TransactionType {
    CREDIT,
    DEBIT,
}

enum class TransactionStatus {
    PENDING,
    COMPLETED,
    FAILED,
    CANCELLED,
}
