package com.chiro.erp.supplychainmanufacturing.entity

import io.quarkus.hibernate.reactive.panache.kotlin.PanacheEntity
import jakarta.persistence.*
import java.time.LocalDateTime

@Entity
@Table(name = "suppliers")
class Supplier : PanacheEntity() {
    @Column(nullable = false, unique = true)
    lateinit var supplierCode: String

    @Column(nullable = false)
    lateinit var name: String

    @Column
    var contactPerson: String? = null

    @Column
    var email: String? = null

    @Column
    var phone: String? = null

    @Column
    var address: String? = null

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    lateinit var status: SupplierStatus

    @Column
    var rating: Int? = null // 1-5 scale

    @Column
    var paymentTerms: String? = null

    @Column
    var leadTimeDays: Int? = null

    @Column(nullable = false)
    var createdAt: LocalDateTime = LocalDateTime.now()

    @Column(nullable = false)
    var updatedAt: LocalDateTime = LocalDateTime.now()
}

enum class SupplierStatus {
    ACTIVE,
    INACTIVE,
    PENDING_APPROVAL,
    BLACKLISTED,
}
