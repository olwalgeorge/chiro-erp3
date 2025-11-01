package com.chiro.erp.supplychainmanufacturing.entity

import io.quarkus.hibernate.reactive.panache.kotlin.PanacheEntity
import jakarta.persistence.*
import java.math.BigDecimal
import java.time.LocalDateTime

@Entity
@Table(name = "products")
class Product : PanacheEntity() {
    @Column(nullable = false, unique = true)
    lateinit var sku: String

    @Column(nullable = false)
    lateinit var name: String

    @Column
    var description: String? = null

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    lateinit var category: ProductCategory

    @Column(nullable = false)
    lateinit var unitPrice: BigDecimal

    @Column(nullable = false)
    var stockQuantity: Int = 0

    @Column(nullable = false)
    var minimumStock: Int = 0

    @Column
    var supplierId: String? = null

    @Column
    var manufacturingCost: BigDecimal? = null

    @Column
    var leadTimeDays: Int? = null

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    lateinit var status: ProductStatus

    @Column(nullable = false)
    var createdAt: LocalDateTime = LocalDateTime.now()

    @Column(nullable = false)
    var updatedAt: LocalDateTime = LocalDateTime.now()
}

enum class ProductCategory {
    RAW_MATERIAL,
    COMPONENT,
    FINISHED_GOOD,
    WORK_IN_PROGRESS,
    CONSUMABLE,
}

enum class ProductStatus {
    ACTIVE,
    DISCONTINUED,
    OUT_OF_STOCK,
    LOW_STOCK,
    BACKORDERED,
}
