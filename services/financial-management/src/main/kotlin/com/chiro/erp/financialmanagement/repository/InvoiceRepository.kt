package com.chiro.erp.financialmanagement.repository

import com.chiro.erp.financialmanagement.entity.Invoice
import com.chiro.erp.financialmanagement.entity.InvoiceStatus
import io.quarkus.hibernate.reactive.panache.kotlin.PanacheRepository
import io.smallrye.mutiny.Uni
import jakarta.enterprise.context.ApplicationScoped

@ApplicationScoped  
class InvoiceRepository : PanacheRepository<Invoice> {

    fun findByInvoiceNumber(invoiceNumber: String): Uni<Invoice?> =
        find("invoiceNumber", invoiceNumber).firstResult()

    fun findByCustomerId(customerId: String): Uni<List<Invoice>> =
        find("customerId", customerId).list()

    fun findByStatus(status: InvoiceStatus): Uni<List<Invoice>> =
        find("status", status).list()

    fun findOverdueInvoices(): Uni<List<Invoice>> =
        find("status = ?1 AND dueDate < NOW()", InvoiceStatus.SENT).list()

    fun searchByDescription(description: String): Uni<List<Invoice>> =
        find("LOWER(description) LIKE LOWER(?1)", "%$description%").list()
}
