package com.chiro.erp.commerce.entity

import io.quarkus.hibernate.reactive.panache.kotlin.PanacheEntity
import jakarta.persistence.*
import java.math.BigDecimal
import java.time.LocalDateTime

@Entity
@Table(name = "products")
class Product : PanacheEntity() {
    @Column(nullable = false)
    var name: String = ""

    @Column(length = 1000)
    var description: String? = null

    @Column(nullable = false, precision = 10, scale = 2)
    var price: BigDecimal = BigDecimal.ZERO

    @Column(nullable = false)
    var stockQuantity: Int = 0

    @Column(nullable = false)
    var category: String = ""

    @Column(nullable = false)
    var sku: String = ""

    @Column(nullable = false)
    var isActive: Boolean = true

    @Column(nullable = false)
    var createdAt: LocalDateTime = LocalDateTime.now()

    var updatedAt: LocalDateTime? = null
}
