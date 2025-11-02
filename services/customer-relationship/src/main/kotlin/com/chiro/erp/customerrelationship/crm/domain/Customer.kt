package com.chiro.erp.customerrelationship.crm.domain

import com.chiro.erp.coreplatform.shared.events.CustomerType
import java.time.Instant
import java.util.UUID

/**
 * Customer aggregate root. Simplified version for demonstration of event publishing.
 *
 * In a full implementation, this would include:
 * - JPA annotations
 * - Rich business logic
 * - Value objects (PersonalInfo, ContactInfo, etc.)
 * - All business rules and invariants
 */
data class Customer(
        val id: UUID,
        val customerNumber: String,
        val firstName: String,
        val lastName: String,
        val email: String,
        val phone: String?,
        val customerType: CustomerType,
        val tenantId: UUID,
        val createdAt: Instant = Instant.now(),
        val createdBy: UUID,
        var updatedAt: Instant = Instant.now(),
        var updatedBy: UUID? = null
) {
    fun fullName(): String = "$firstName $lastName"

    fun activate(userId: UUID) {
        updatedBy = userId
        updatedAt = Instant.now()
    }
}
