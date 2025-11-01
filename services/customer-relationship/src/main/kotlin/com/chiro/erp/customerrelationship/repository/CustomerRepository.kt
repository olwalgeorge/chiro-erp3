package com.chiro.erp.customerrelationship.repository

import com.chiro.erp.customerrelationship.entity.Customer
import com.chiro.erp.customerrelationship.entity.CustomerStatus
import io.quarkus.hibernate.reactive.panache.kotlin.PanacheRepositoryBase
import io.smallrye.mutiny.Uni
import jakarta.enterprise.context.ApplicationScoped

@ApplicationScoped
class CustomerRepository : PanacheRepositoryBase<Customer, Long> {
    fun findByEmail(email: String): Uni<Customer?> {
        return find("email = ?1", email).firstResult()
    }

    fun findByStatus(status: CustomerStatus): Uni<List<Customer>> {
        return find("status = ?1", status).list()
    }

    fun findByCompany(company: String): Uni<List<Customer>> {
        return find("company = ?1", company).list()
    }

    fun searchCustomers(query: String): Uni<List<Customer>> {
        return find(
            "LOWER(firstName) LIKE LOWER(?1) OR LOWER(lastName) LIKE LOWER(?1) OR LOWER(email) LIKE LOWER(?1) OR LOWER(company) LIKE LOWER(?1)",
            "%$query%",
        ).list()
    }

    fun updateLastContact(customerId: Long): Uni<Customer?> {
        return findById(customerId)
            .onItem().ifNotNull().invoke { customer ->
                customer.lastContactAt = java.time.LocalDateTime.now()
                customer.updatedAt = java.time.LocalDateTime.now()
            }
            .onItem().ifNotNull().call { customer ->
                persistAndFlush(customer)
            }
    }
}
