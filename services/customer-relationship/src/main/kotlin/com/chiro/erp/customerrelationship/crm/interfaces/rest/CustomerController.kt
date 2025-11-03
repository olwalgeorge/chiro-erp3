package com.chiro.erp.customerrelationship.crm.interfaces.rest

import com.chiro.erp.shared.events.CustomerType
import com.chiro.erp.customerrelationship.crm.application.CreateCustomerCommand
import com.chiro.erp.customerrelationship.crm.application.CustomerService
import jakarta.inject.Inject
import jakarta.ws.rs.*
import jakarta.ws.rs.core.MediaType
import jakarta.ws.rs.core.Response
import java.util.UUID
import org.jboss.logging.Logger

/**
 * REST API for Customer operations. Demonstrates integration with EventPublisher for domain events.
 */
@Path("/api/crm/customers")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
class CustomerController {

    @Inject lateinit var customerService: CustomerService

    private val logger = Logger.getLogger(CustomerController::class.java)

    /** Create a new customer POST /api/crm/customers */
    @POST
    fun createCustomer(request: CreateCustomerRequest): Response {
        logger.info("Received request to create customer: ${request.email}")

        return try {
            val command =
                    CreateCustomerCommand(
                            firstName = request.firstName,
                            lastName = request.lastName,
                            email = request.email,
                            phone = request.phone,
                            customerType = request.customerType ?: CustomerType.B2C,
                            tenantId = request.tenantId
                                            ?: UUID.randomUUID(), // In real app, get from
                            // JWT/context
                            userId = request.userId ?: UUID.randomUUID() // In real app, get from
                            // JWT/context
                            )

            val result = customerService.createCustomer(command)

            Response.status(Response.Status.CREATED)
                    .entity(
                            CreateCustomerResponse(
                                    success = true,
                                    message = "Customer created successfully",
                                    customerId = result.customerId,
                                    customerNumber = result.customerNumber
                            )
                    )
                    .build()
        } catch (e: Exception) {
            logger.error("Failed to create customer", e)
            Response.status(Response.Status.INTERNAL_SERVER_ERROR)
                    .entity(
                            CreateCustomerResponse(
                                    success = false,
                                    message = "Failed to create customer: ${e.message}",
                                    customerId = null,
                                    customerNumber = null
                            )
                    )
                    .build()
        }
    }

    /** Health check endpoint */
    @GET
    @Path("/health")
    fun health(): Response {
        return Response.ok(mapOf("status" to "UP", "service" to "customer-crm")).build()
    }
}

/** Request body for creating a customer */
data class CreateCustomerRequest(
        val firstName: String,
        val lastName: String,
        val email: String,
        val phone: String? = null,
        val customerType: CustomerType? = null,
        val tenantId: UUID? = null,
        val userId: UUID? = null
)

/** Response for customer creation */
data class CreateCustomerResponse(
        val success: Boolean,
        val message: String,
        val customerId: UUID?,
        val customerNumber: String?
)
