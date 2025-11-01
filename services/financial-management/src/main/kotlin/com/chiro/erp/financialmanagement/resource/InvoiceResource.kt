package com.chiro.erp.financialmanagement.resource

import com.chiro.erp.financialmanagement.entity.Invoice
import com.chiro.erp.financialmanagement.entity.InvoiceStatus
import com.chiro.erp.financialmanagement.repository.InvoiceRepository
import io.quarkus.hibernate.reactive.panache.common.WithTransaction
import io.smallrye.mutiny.Uni
import jakarta.inject.Inject
import jakarta.ws.rs.*
import jakarta.ws.rs.core.MediaType
import jakarta.ws.rs.core.Response
import java.time.LocalDateTime

@Path("/api/invoices")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
class InvoiceResource {
    @Inject
    lateinit var invoiceRepository: InvoiceRepository

    @GET
    fun getAllInvoices(): Uni<List<Invoice>> = invoiceRepository.listAll()

    @GET
    @Path("/{id}")
    fun getInvoice(
        @PathParam("id") id: Long,
    ): Uni<Response> {
        return invoiceRepository.findById(id)
            .onItem().transform { invoice ->
                if (invoice != null) {
                    Response.ok(invoice).build()
                } else {
                    Response.status(Response.Status.NOT_FOUND).build()
                }
            }
    }

    @GET
    @Path("/number/{invoiceNumber}")
    fun getInvoiceByNumber(
        @PathParam("invoiceNumber") invoiceNumber: String,
    ): Uni<Response> {
        return invoiceRepository.findByInvoiceNumber(invoiceNumber)
            .onItem().transform { invoice ->
                if (invoice != null) {
                    Response.ok(invoice).build()
                } else {
                    Response.status(Response.Status.NOT_FOUND).build()
                }
            }
    }

    @GET
    @Path("/customer/{customerId}")
    fun getInvoicesByCustomer(
        @PathParam("customerId") customerId: String,
    ): Uni<List<Invoice>> = invoiceRepository.findByCustomerId(customerId)

    @GET
    @Path("/status/{status}")
    fun getInvoicesByStatus(
        @PathParam("status") status: InvoiceStatus,
    ): Uni<List<Invoice>> = invoiceRepository.findByStatus(status)

    @GET
    @Path("/overdue")
    fun getOverdueInvoices(): Uni<List<Invoice>> = invoiceRepository.findOverdueInvoices()

    @POST
    @WithTransaction
    fun createInvoice(invoice: Invoice): Uni<Response> {
        invoice.createdAt = LocalDateTime.now()
        invoice.updatedAt = LocalDateTime.now()
        return invoiceRepository.persist(invoice)
            .onItem().transform { Response.status(Response.Status.CREATED).entity(it).build() }
    }

    @PUT
    @Path("/{id}")
    @WithTransaction
    fun updateInvoice(
        @PathParam("id") id: Long,
        invoice: Invoice,
    ): Uni<Response> {
        return invoiceRepository.findById(id)
            .onItem().transformToUni { existingInvoice ->
                if (existingInvoice != null) {
                    existingInvoice.customerId = invoice.customerId
                    existingInvoice.amount = invoice.amount
                    existingInvoice.status = invoice.status
                    existingInvoice.dueDate = invoice.dueDate
                    existingInvoice.description = invoice.description
                    existingInvoice.updatedAt = LocalDateTime.now()
                    invoiceRepository.persist(existingInvoice)
                        .onItem().transform { Response.ok(it).build() }
                } else {
                    Uni.createFrom().item(Response.status(Response.Status.NOT_FOUND).build())
                }
            }
    }

    @DELETE
    @Path("/{id}")
    @WithTransaction
    fun deleteInvoice(
        @PathParam("id") id: Long,
    ): Uni<Response> {
        return invoiceRepository.deleteById(id)
            .onItem().transform { deleted ->
                if (deleted) {
                    Response.noContent().build()
                } else {
                    Response.status(Response.Status.NOT_FOUND).build()
                }
            }
    }

    @GET
    @Path("/search")
    fun searchInvoices(
        @QueryParam("description") description: String?,
    ): Uni<List<Invoice>> {
        return if (!description.isNullOrBlank()) {
            invoiceRepository.searchByDescription(description)
        } else {
            invoiceRepository.listAll()
        }
    }
}
