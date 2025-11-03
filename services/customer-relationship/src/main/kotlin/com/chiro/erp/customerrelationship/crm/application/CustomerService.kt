package com.chiro.erp.customerrelationship.crm.application

import com.chiro.erp.shared.events.CustomerContactInfo as EventContactInfo
import com.chiro.erp.shared.events.CustomerCreatedEvent
import com.chiro.erp.shared.events.CustomerPersonalInfo as EventPersonalInfo
import com.chiro.erp.shared.events.CustomerStatus
import com.chiro.erp.shared.events.CustomerType
import com.chiro.erp.shared.events.EventMetadata
import com.chiro.erp.shared.events.EventPublisher
import com.chiro.erp.customerrelationship.crm.domain.Customer
import jakarta.enterprise.context.ApplicationScoped
import jakarta.inject.Inject
import jakarta.transaction.Transactional
import java.util.UUID
import org.jboss.logging.Logger

/**
 * Application service for Customer aggregate. Handles customer operations and publishes domain
 * events.
 */
@ApplicationScoped
class CustomerService {

    @Inject lateinit var eventPublisher: EventPublisher

    private val logger = Logger.getLogger(CustomerService::class.java)

    /** Creates a new customer and publishes CustomerCreatedEvent */
    @Transactional
    fun createCustomer(command: CreateCustomerCommand): CustomerCreatedResult {
        logger.info("Creating customer: ${command.email}")

        // Generate customer number
        val customerNumber = generateCustomerNumber()

        // Create customer domain object (simplified for demonstration)
        val customer =
                Customer(
                        id = UUID.randomUUID(),
                        customerNumber = customerNumber,
                        firstName = command.firstName,
                        lastName = command.lastName,
                        email = command.email,
                        phone = command.phone,
                        customerType = command.customerType,
                        tenantId = command.tenantId,
                        createdBy = command.userId
                )

        // In a real implementation, this would be persisted to database
        // customerRepository.persist(customer)

        // Publish domain event
        publishCustomerCreatedEvent(customer, command.userId)

        logger.info("Customer created successfully: $customerNumber")

        return CustomerCreatedResult(customerId = customer.id, customerNumber = customerNumber)
    }

    /** Publishes CustomerCreatedEvent to Kafka */
    private fun publishCustomerCreatedEvent(customer: Customer, userId: UUID) {
        val event =
                CustomerCreatedEvent(
                        aggregateId = customer.id,
                        tenantId = customer.tenantId,
                        metadata =
                                EventMetadata(
                                        correlationId = UUID.randomUUID(),
                                        userId = userId,
                                        source = "customer-relationship"
                                ),
                        customerId = customer.id,
                        customerNumber = customer.customerNumber,
                        customerType = customer.customerType,
                        status = CustomerStatus.ACTIVE, // New customers are active by default
                        personalInfo =
                                EventPersonalInfo(
                                        firstName = customer.firstName,
                                        lastName = customer.lastName,
                                        fullName = "${customer.firstName} ${customer.lastName}",
                                        email = customer.email
                                ),
                        contactInfo =
                                EventContactInfo(
                                        primaryEmail = customer.email,
                                        primaryPhone = customer.phone ?: ""
                                )
                )

        eventPublisher.publish(event)
        logger.info("Published CustomerCreatedEvent for: ${customer.customerNumber}")
    }

    /** Generates a unique customer number */
    private fun generateCustomerNumber(): String {
        val year = java.time.LocalDate.now().year
        val sequence = System.currentTimeMillis() % 1000000 // Simple sequence for demo
        return "CUST-$year-${sequence.toString().padStart(6, '0')}"
    }
}

/** Command to create a new customer */
data class CreateCustomerCommand(
        val firstName: String,
        val lastName: String,
        val email: String,
        val phone: String?,
        val customerType: CustomerType,
        val tenantId: UUID,
        val userId: UUID // Who is creating this customer
)

/** Result of customer creation */
data class CustomerCreatedResult(val customerId: UUID, val customerNumber: String)
