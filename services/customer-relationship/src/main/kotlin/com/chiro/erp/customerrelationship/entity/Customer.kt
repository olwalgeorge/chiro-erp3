package com.chiro.erp.customerrelationship.entity

import io.quarkus.hibernate.reactive.panache.kotlin.PanacheEntity
import jakarta.persistence.*
import java.time.LocalDateTime

@Entity
@Table(name = "customers")
class Customer : PanacheEntity() {
    @Column(nullable = false)
    var firstName: String = ""

    @Column(nullable = false)
    var lastName: String = ""

    @Column(nullable = false, unique = true)
    var email: String = ""

    var phone: String? = null

    var company: String? = null

    @Column(nullable = false)
    @Enumerated(EnumType.STRING)
    var status: CustomerStatus = CustomerStatus.ACTIVE

    @Column(nullable = false)
    var createdAt: LocalDateTime = LocalDateTime.now()

    var updatedAt: LocalDateTime? = null

    var lastContactAt: LocalDateTime? = null
}

enum class CustomerStatus {
    ACTIVE,
    INACTIVE,
    PROSPECT,
    CHURNED,
}
