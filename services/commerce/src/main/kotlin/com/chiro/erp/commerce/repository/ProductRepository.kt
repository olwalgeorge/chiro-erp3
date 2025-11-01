package com.chiro.erp.commerce.repository

import com.chiro.erp.commerce.entity.Product
import io.quarkus.hibernate.reactive.panache.kotlin.PanacheRepositoryBase
import io.smallrye.mutiny.Uni
import jakarta.enterprise.context.ApplicationScoped

@ApplicationScoped
class ProductRepository : PanacheRepositoryBase<Product, Long> {
    fun findByCategory(category: String): Uni<List<Product>> {
        return find("category = ?1 AND isActive = true", category).list()
    }

    fun findBySku(sku: String): Uni<Product?> {
        return find("sku = ?1", sku).firstResult()
    }

    fun findActiveProducts(): Uni<List<Product>> {
        return find("isActive = true").list()
    }

    fun searchByName(name: String): Uni<List<Product>> {
        return find("LOWER(name) LIKE LOWER(?1)", "%$name%").list()
    }

    fun updateStock(
        productId: Long,
        newQuantity: Int,
    ): Uni<Product?> {
        return findById(productId)
            .onItem().ifNotNull().invoke { product ->
                product.stockQuantity = newQuantity
                product.updatedAt = java.time.LocalDateTime.now()
            }
            .onItem().ifNotNull().call { product ->
                persistAndFlush(product)
            }
    }
}
