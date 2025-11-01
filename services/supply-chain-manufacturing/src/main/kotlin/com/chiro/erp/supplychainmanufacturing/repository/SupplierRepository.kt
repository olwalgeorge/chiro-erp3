package com.chiro.erp.supplychainmanufacturing.repository

import com.chiro.erp.supplychainmanufacturing.entity.Supplier
import com.chiro.erp.supplychainmanufacturing.entity.SupplierStatus
import io.quarkus.hibernate.reactive.panache.kotlin.PanacheRepository
import io.smallrye.mutiny.Uni
import jakarta.enterprise.context.ApplicationScoped

@ApplicationScoped
class SupplierRepository : PanacheRepository<Supplier> {

    fun findBySupplierCode(supplierCode: String): Uni<Supplier?> =
        find("supplierCode", supplierCode).firstResult()

    fun findByStatus(status: SupplierStatus): Uni<List<Supplier>> =
        find("status", status).list()

    fun findByRating(rating: Int): Uni<List<Supplier>> =
        find("rating", rating).list()

    fun findActiveSuppliers(): Uni<List<Supplier>> =
        find("status", SupplierStatus.ACTIVE).list()

    fun findByRatingGreaterThan(rating: Int): Uni<List<Supplier>> =
        find("rating > ?1", rating).list()

    fun searchByName(name: String): Uni<List<Supplier>> =
        find("LOWER(name) LIKE LOWER(?1)", "%$name%").list()

    fun findByEmail(email: String): Uni<Supplier?> =
        find("email", email).firstResult()
}
