package com.chiro.erp.supplychainmanufacturing.repository

import com.chiro.erp.supplychainmanufacturing.entity.Product
import com.chiro.erp.supplychainmanufacturing.entity.ProductCategory
import com.chiro.erp.supplychainmanufacturing.entity.ProductStatus
import io.quarkus.hibernate.reactive.panache.kotlin.PanacheRepository
import io.smallrye.mutiny.Uni
import jakarta.enterprise.context.ApplicationScoped

@ApplicationScoped
class ProductRepository : PanacheRepository<Product> {

    fun findBySku(sku: String): Uni<Product?> =
        find("sku", sku).firstResult()

    fun findByCategory(category: ProductCategory): Uni<List<Product>> =
        find("category", category).list()

    fun findByStatus(status: ProductStatus): Uni<List<Product>> =
        find("status", status).list()

    fun findBySupplierId(supplierId: String): Uni<List<Product>> =
        find("supplierId", supplierId).list()

    fun findLowStockProducts(): Uni<List<Product>> =
        find("stockQuantity <= minimumStock").list()

    fun findOutOfStockProducts(): Uni<List<Product>> =
        find("stockQuantity = 0").list()

    fun findActiveProducts(): Uni<List<Product>> =
        find("status", ProductStatus.ACTIVE).list()

    fun searchByName(name: String): Uni<List<Product>> =
        find("LOWER(name) LIKE LOWER(?1)", "%$name%").list()

    fun findByCategoryAndStatus(category: ProductCategory, status: ProductStatus): Uni<List<Product>> =
        find("category = ?1 AND status = ?2", category, status).list()
}
