# Hexagonal Architecture Visual Guide

## 🏗️ Complete Service Structure

```
chiro-erp/
├── services/
│   ├── core-platform/              [6 domains - Enterprise Foundation]
│   │   ├── security/               ← service-security-framework
│   │   ├── organization/           ← service-organization-master
│   │   ├── audit/                  ← service-audit-logging
│   │   ├── configuration/          ← service-configuration-management
│   │   ├── notification/           ← service-notification-engine
│   │   └── integration/            ← service-integration-platform
│   │
│   ├── customer-relationship/      [5 domains - CRM & Customer Experience]
│   │   ├── crm/                    ← service-crm
│   │   ├── client/                 ← service-client-management
│   │   ├── provider/               ← service-provider-management
│   │   ├── subscription/           ← service-subscriptions
│   │   └── promotion/              ← service-retail-promotions
│   │
│   ├── operations-service/         [4 domains - Service Management]
│   │   ├── field-service/          ← service-field-service-management
│   │   ├── scheduling/             ← service-resource-scheduling
│   │   ├── records/                ← service-records-management
│   │   └── repair-rma/             ← service-repair-rma
│   │
│   ├── commerce/                   [4 domains - Omnichannel Commerce]
│   │   ├── ecommerce/              ← service-ecomm-storefront
│   │   ├── portal/                 ← service-customer-portal
│   │   ├── communication/          ← service-communication-portal
│   │   └── pos/                    ← service-point-of-sale
│   │
│   ├── financial-management/       [6 domains - SAP FI Alignment]
│   │   ├── general-ledger/         ← service-accounting-core
│   │   ├── accounts-payable/       ← service-ap-automation
│   │   ├── accounts-receivable/    ← service-billing-invoicing
│   │   ├── asset-accounting/       ← service-asset-management
│   │   ├── tax-engine/             ← service-tax-compliance
│   │   └── expense-management/     ← service-expense-reports
│   │
│   ├── supply-chain-manufacturing/ [5 domains - SAP MM/CO Alignment]
│   │   ├── production/             ← service-mrp-production
│   │   ├── quality/                ← service-quality-management
│   │   ├── inventory/              ← service-inventory-management
│   │   ├── product-costing/        ← service-cost-accounting
│   │   └── procurement/            ← service-procurement-management
│   │
│   └── administration/             [4 domains - Business Administration]
│       ├── hr/                     ← service-hr-management
│       ├── logistics-transportation/ ← service-logistics-transportation
│       ├── analytics-intelligence/ ← service-analytics-intelligence
│       └── project-management/     ← service-project-management
```

---

## 🎯 Hexagonal Architecture per Domain

### Layer Structure Visualization

```
┌─────────────────────────────────────────────────────────────────┐
│                         INTERFACES LAYER                         │
│  (Entry Points - Adapters that receive external input)          │
├─────────────────────────────────────────────────────────────────┤
│  rest/          graphql/         events/                        │
│  - Controllers   - Resolvers     - Event Listeners              │
│  - DTOs         - Schemas        - Event Publishers             │
│  - Validators   - Mutations      - Message Handlers             │
└────────────────────────┬────────────────────────────────────────┘
                         │ calls
                         ↓
┌─────────────────────────────────────────────────────────────────┐
│                       APPLICATION LAYER                          │
│  (Use Case Orchestration - Application Services)                │
├─────────────────────────────────────────────────────────────────┤
│  - Use Case Implementations (Commands & Queries)                │
│  - Transaction Management                                        │
│  - Security & Authorization Checks                              │
│  - Event Publishing Coordination                                │
└────────────────────────┬────────────────────────────────────────┘
                         │ uses
                         ↓
┌─────────────────────────────────────────────────────────────────┐
│                          DOMAIN LAYER                            │
│  (Pure Business Logic - Zero Infrastructure Dependencies)       │
├─────────────────────────────────────────────────────────────────┤
│  models/                                                         │
│  ├── Entities (Aggregate Roots)                                │
│  ├── Value Objects                                              │
│  └── Domain Events                                              │
│                                                                  │
│  services/                                                       │
│  └── Domain Services (Complex Business Rules)                   │
│                                                                  │
│  ports/                                                          │
│  ├── inbound/  (What the domain offers - Use Case Interfaces)  │
│  └── outbound/ (What the domain needs - Repository Interfaces)  │
└────────────────────────┬────────────────────────────────────────┘
                         │ depends on (via interfaces)
                         ↓
┌─────────────────────────────────────────────────────────────────┐
│                      INFRASTRUCTURE LAYER                        │
│  (Technical Implementations - Adapters for external systems)    │
├─────────────────────────────────────────────────────────────────┤
│  persistence/        messaging/           external/             │
│  - JPA Repositories  - Kafka Producers    - REST Clients        │
│  - Database Config   - Kafka Consumers    - SOAP Clients        │
│  - Query DSL         - Event Handlers     - Third-party APIs    │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Data Flow Example: Customer Order

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. REST Controller (interfaces/rest)                            │
│    POST /api/orders                                              │
│    ↓ validates request                                           │
│    ↓ converts DTO to domain model                               │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────────┐
│ 2. Application Service (application)                            │
│    CreateOrderUseCase.execute(command)                          │
│    ↓ begins transaction                                         │
│    ↓ checks authorization                                       │
│    ↓ orchestrates domain operations                             │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────────┐
│ 3. Domain Layer (domain)                                        │
│    Order.create(customer, items)                                │
│    ↓ validates business rules                                   │
│    ↓ calculates totals                                          │
│    ↓ publishes OrderCreated event                               │
│    └─→ calls OrderRepository.save() (port interface)            │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────────────────┐
│ 4. Infrastructure Layer (infrastructure)                        │
│    JpaOrderRepository.save()                                    │
│    ↓ persists to database                                       │
│    KafkaEventPublisher.publish(OrderCreated)                   │
│    ↓ publishes event to Kafka                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔗 Cross-Service Integration Patterns

### Event-Driven Integration

```
┌──────────────────────┐
│  Commerce Service    │
│  (ecommerce domain)  │
│  Order Created       │
└──────────┬───────────┘
           │ publishes event
           ↓
    ┌──────────────┐
    │ Kafka Topic  │
    │ order-events │
    └──────┬───────┘
           │ subscribes
           ├──────────────────────────────────┐
           ↓                                  ↓
┌──────────────────────┐         ┌──────────────────────┐
│ Financial Service    │         │ Supply Chain Service │
│ (accounts-receivable)│         │ (inventory)          │
│ Create Invoice       │         │ Reserve Stock        │
└──────────────────────┘         └──────────────────────┘
```

### Synchronous Integration (when needed)

```
┌──────────────────────┐
│  Operations Service  │
│  (field-service)     │
│  Schedule Service    │
└──────────┬───────────┘
           │ HTTP/gRPC call
           ↓
┌──────────────────────┐
│  Customer Service    │
│  (crm)               │
│  Get Customer Info   │
└──────────────────────┘
           │ returns data
           ↓
┌──────────────────────┐
│  Operations Service  │
│  Creates Work Order  │
└──────────────────────┘
```

---

## 📦 Package Naming Convention

### Pattern

```
com.chiro.erp.{service-package}.{domain-name}.{layer}.{component}
```

### Examples

```kotlin
// Core Platform - Security Domain
com.chiro.erp.coreplatform.security.domain.models.User
com.chiro.erp.coreplatform.security.domain.ports.inbound.AuthenticateUserUseCase
com.chiro.erp.coreplatform.security.application.AuthenticateUserService
com.chiro.erp.coreplatform.security.infrastructure.persistence.JpaUserRepository
com.chiro.erp.coreplatform.security.interfaces.rest.AuthController

// Customer Relationship - CRM Domain
com.chiro.erp.customerrelationship.crm.domain.models.Customer
com.chiro.erp.customerrelationship.crm.domain.ports.inbound.CreateCustomerUseCase
com.chiro.erp.customerrelationship.crm.application.CreateCustomerService
com.chiro.erp.customerrelationship.crm.infrastructure.persistence.JpaCustomerRepository
com.chiro.erp.customerrelationship.crm.interfaces.rest.CustomerController

// Financial Management - General Ledger
com.chiro.erp.financialmanagement.generalledger.domain.models.JournalEntry
com.chiro.erp.financialmanagement.generalledger.domain.ports.inbound.PostJournalEntryUseCase
com.chiro.erp.financialmanagement.generalledger.application.PostJournalEntryService
com.chiro.erp.financialmanagement.generalledger.infrastructure.persistence.JpaJournalEntryRepository
com.chiro.erp.financialmanagement.generalledger.interfaces.rest.JournalEntryController

// Supply Chain - Inventory Domain
com.chiro.erp.supplychainmanufacturing.inventory.domain.models.StockItem
com.chiro.erp.supplychainmanufacturing.inventory.domain.ports.inbound.AdjustInventoryUseCase
com.chiro.erp.supplychainmanufacturing.inventory.application.AdjustInventoryService
com.chiro.erp.supplychainmanufacturing.inventory.infrastructure.persistence.JpaStockItemRepository
com.chiro.erp.supplychainmanufacturing.inventory.interfaces.rest.InventoryController
```

---

## 🧪 Testing Structure

### Test Organization Mirrors Main Source

```
services/{service-name}/src/
├── main/kotlin/com/chiro/erp/{service-package}/{domain-name}/
│   ├── domain/
│   ├── application/
│   ├── infrastructure/
│   └── interfaces/
│
└── test/kotlin/com/chiro/erp/{service-package}/{domain-name}/
    ├── domain/
    │   ├── models/
    │   │   └── CustomerTest.kt              # Unit tests for domain entities
    │   └── services/
    │       └── PricingServiceTest.kt        # Unit tests for domain services
    │
    ├── application/
    │   └── CreateCustomerServiceTest.kt     # Use case tests (mock repos)
    │
    ├── infrastructure/
    │   ├── persistence/
    │   │   └── JpaCustomerRepositoryTest.kt # Integration tests with DB
    │   └── messaging/
    │       └── KafkaEventPublisherTest.kt   # Integration tests with Kafka
    │
    └── interfaces/
        └── rest/
            └── CustomerControllerTest.kt    # API integration tests
```

### Test Types by Layer

| Layer              | Test Type         | Dependencies                   | Focus                                          |
| ------------------ | ----------------- | ------------------------------ | ---------------------------------------------- |
| **Domain**         | Unit Tests        | None (pure logic)              | Business rules, calculations, validations      |
| **Application**    | Unit Tests        | Mocked repositories            | Use case orchestration, transaction boundaries |
| **Infrastructure** | Integration Tests | Real DB/Kafka (testcontainers) | Persistence, messaging, external APIs          |
| **Interfaces**     | Integration Tests | Spring context, MockMvc        | API contracts, request/response handling       |

---

## 🎯 Dependency Direction

### The Dependency Rule

**All dependencies point INWARD toward the domain**

```
┌─────────────────────────────────────────────────┐
│              OUTER LAYERS                        │
│  (Interfaces & Infrastructure)                  │
│                                                  │
│  ┌─────────────────────────────────────────┐   │
│  │         APPLICATION LAYER                │   │
│  │                                          │   │
│  │  ┌──────────────────────────────────┐  │   │
│  │  │      DOMAIN LAYER                │  │   │
│  │  │   (Business Logic Core)          │  │   │
│  │  │   • No outward dependencies      │  │   │
│  │  │   • Pure business rules          │  │   │
│  │  │   • Framework-agnostic           │  │   │
│  │  └──────────────────────────────────┘  │   │
│  │         ↑                                │   │
│  │         │ depends on                    │   │
│  │         │ (uses interfaces)             │   │
│  └─────────┼───────────────────────────────┘   │
│            ↑                                    │
│            │ depends on                         │
│            │ (implements interfaces)            │
└────────────┼────────────────────────────────────┘
             │
             └─ All arrows point INWARD
```

---

## 🚀 Quick Start Commands

### Generate Complete Structure

```powershell
# From project root
.\scripts\create-complete-structure.ps1
```

### Navigate to a Domain

```powershell
# Example: Navigate to CRM domain in customer-relationship service
cd services/customer-relationship/src/main/kotlin/com/chiro/erp/customerrelationship/crm
```

### Create a New Entity

```kotlin
// File: services/customer-relationship/src/main/kotlin/com/chiro/erp/customerrelationship/crm/domain/models/Customer.kt

package com.chiro.erp.customerrelationship.crm.domain.models

import jakarta.persistence.*
import java.time.Instant
import java.util.UUID

@Entity
@Table(name = "customers", schema = "crm_schema")
class Customer(
    @Id
    val id: UUID = UUID.randomUUID(),

    @Column(nullable = false)
    var name: String,

    @Column(nullable = false)
    val tenantId: UUID,

    @Column(nullable = false)
    val createdAt: Instant = Instant.now(),

    @Version
    var version: Long = 0
) {
    // Business methods here
    fun activate() {
        // Business logic
    }
}
```

### Create a Use Case Interface (Inbound Port)

```kotlin
// File: services/customer-relationship/src/main/kotlin/com/chiro/erp/customerrelationship/crm/domain/ports/inbound/CreateCustomerUseCase.kt

package com.chiro.erp.customerrelationship.crm.domain.ports.inbound

import java.util.UUID

interface CreateCustomerUseCase {
    suspend fun execute(command: CreateCustomerCommand): UUID
}

data class CreateCustomerCommand(
    val name: String,
    val email: String,
    val tenantId: UUID
)
```

### Implement Use Case (Application Service)

```kotlin
// File: services/customer-relationship/src/main/kotlin/com/chiro/erp/customerrelationship/crm/application/CreateCustomerService.kt

package com.chiro.erp.customerrelationship.crm.application

import com.chiro.erp.customerrelationship.crm.domain.models.Customer
import com.chiro.erp.customerrelationship.crm.domain.ports.inbound.CreateCustomerCommand
import com.chiro.erp.customerrelationship.crm.domain.ports.inbound.CreateCustomerUseCase
import com.chiro.erp.customerrelationship.crm.domain.ports.outbound.CustomerRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.UUID

@Service
@Transactional
class CreateCustomerService(
    private val customerRepository: CustomerRepository
) : CreateCustomerUseCase {

    override suspend fun execute(command: CreateCustomerCommand): UUID {
        val customer = Customer(
            name = command.name,
            tenantId = command.tenantId
        )

        customerRepository.save(customer)

        return customer.id
    }
}
```

---

## 📊 Statistics Dashboard

```
┌─────────────────────────────────────────────────────────────┐
│             CHIRO ERP ARCHITECTURE METRICS                   │
├─────────────────────────────────────────────────────────────┤
│  Total Services:              7                              │
│  Total Domains:               36                             │
│  Original Microservices:      30+                            │
│  Complexity Reduction:        75%                            │
│                                                              │
│  Layered Architecture:        Hexagonal (Ports & Adapters)  │
│  Domain Pattern:              DDD (Domain-Driven Design)    │
│  Integration:                 Event-Driven + REST           │
│  Database Strategy:           Single shared database        │
│  Security:                    Zero-trust, Multi-tenant      │
│                                                              │
│  SAP Alignment:                                             │
│    - Financial (FI):          ✅ Complete                   │
│    - Materials Mgmt (MM):     ✅ Complete                   │
│    - Controlling (CO):        ✅ Complete                   │
│                                                              │
│  Implementation Timeline:     30 weeks (6 phases)           │
│  Estimated Team Size:         15-20 developers              │
└─────────────────────────────────────────────────────────────┘
```

---

This visual guide provides a comprehensive overview of the hexagonal architecture implementation across all 7 services and 36 domains in the Chiro ERP system.
