# Kafka Event Publishers - Verification Guide

## Overview
This guide provides step-by-step instructions to verify the Kafka event publisher implementation in the customer-relationship service.

## Implementation Summary

### ✅ Completed Components

**1. Shared Event Library** (Committed: 0880e3e)
- 35+ domain events across 6 business domains
- DomainEvent and IntegrationEvent interfaces
- EventMetadata for traceability (correlationId, causationId, userId)
- Comprehensive documentation

**2. EventPublisher** (Committed: 8f47a55)
- Centralized event publishing with automatic routing
- 7 dedicated Kafka channels for event topics
- Type-safe event routing to correct topics
- JSON serialization with Jackson ObjectMapper

**3. Customer-Relationship Service** (Committed: 8f47a55)
- CustomerService: Application service with event publishing
- Customer: Domain model (aggregate root)
- CustomerController: REST API endpoint
- Kafka channel configuration in application.properties

### 📍 Event Flow Architecture

```
HTTP POST → CustomerController → CustomerService.createCustomer()
  ↓
Customer Domain Model Created
  ↓
publishCustomerCreatedEvent() → EventPublisher.publish()
  ↓
EventPublisher.getEmitterForEvent() → customerEventsEmitter
  ↓
Kafka Channel: crm-customer-events → Topic: crm.customer.events
```

## Kafka Topic Configuration

| Event Category | Kafka Channel | Kafka Topic | Service |
|---------------|---------------|-------------|---------|
| Customer Events | crm-customer-events | crm.customer.events | customer-relationship |
| Order Events | commerce-order-events | commerce.order.events | commerce-management |
| Invoice Events | finance-invoice-events | finance.invoice.events | financial-management |
| Inventory Events | supply-inventory-events | supply.inventory.events | supply-chain |
| Service Order Events | operations-service-order-events | operations.service-order.events | operations-management |
| User Events | platform-user-events | platform.user.events | user-management |
| Internal Events | platform-internal-events | platform.internal.events | core-platform |

## Prerequisites

### 1. Start Kafka Infrastructure
```powershell
# Start Kafka using docker-compose
docker-compose up -d kafka zookeeper

# Verify Kafka is running
docker ps | Select-String kafka

# Check Kafka logs
docker logs chiro-kafka
```

### 2. Create Kafka Topics
```powershell
# Create the customer events topic
docker exec -it chiro-kafka kafka-topics.sh \
  --create \
  --bootstrap-server localhost:9092 \
  --topic crm.customer.events \
  --partitions 3 \
  --replication-factor 1

# Verify topic creation
docker exec -it chiro-kafka kafka-topics.sh \
  --list \
  --bootstrap-server localhost:9092
```

### 3. Build Core Platform Service
```powershell
# Build core-platform (contains shared events)
cd services\core-platform
..\..\gradlew.bat clean build -x test
```

### 4. Build Customer-Relationship Service
```powershell
# Build customer-relationship service
cd ..\customer-relationship
..\..\gradlew.bat clean build -x test
```

## Verification Steps

### Step 1: Start Services

#### Option A: Using Docker Compose
```powershell
# Start all services
docker-compose up -d

# Check customer-relationship service logs
docker logs -f chiro-customer-relationship
```

#### Option B: Manual Start (for development)
```powershell
# Terminal 1: Start customer-relationship service
cd services\customer-relationship
..\..\gradlew.bat quarkusDev

# Wait for service to start (look for "Listening on: http://0.0.0.0:8083")
```

### Step 2: Verify Service Health
```powershell
# Check health endpoint
curl http://localhost:8083/q/health

# Expected output (healthy):
{
  "status": "UP",
  "checks": [
    {
      "name": "SmallRye Reactive Messaging - liveness check",
      "status": "UP"
    }
  ]
}
```

### Step 3: Start Kafka Consumer (Monitor Events)

```powershell
# Terminal 2: Start Kafka console consumer to monitor events
docker exec -it chiro-kafka kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic crm.customer.events \
  --from-beginning \
  --property print.key=true \
  --property print.timestamp=true
```

This consumer will display all events published to `crm.customer.events` topic.

### Step 4: Create Customer via REST API

Use the provided REST file or curl:

```powershell
# Using curl - Create RETAIL customer
curl -X POST http://localhost:8083/api/crm/customers \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "John",
    "lastName": "Doe",
    "email": "john.doe@example.com",
    "phone": "+1-555-123-4567",
    "customerType": "RETAIL",
    "tenantId": "tenant-001"
  }'

# Expected HTTP Response:
# 201 Created
{
  "id": "...",
  "customerNumber": "CUST-...",
  "firstName": "John",
  "lastName": "Doe",
  "email": "john.doe@example.com",
  "phone": "+1-555-123-4567",
  "customerType": "RETAIL",
  "tenantId": "tenant-001"
}
```

Or use VS Code REST Client with `test-customer-creation.http` file.

### Step 5: Verify Event Published

**Check Kafka Consumer Output (Terminal 2):**

You should see a CustomerCreatedEvent JSON message similar to:

```json
{
  "eventId": "evt-...",
  "aggregateId": "...",
  "aggregateType": "Customer",
  "eventType": "CustomerCreated",
  "occurredAt": "2024-01-15T10:30:00Z",
  "tenantId": "tenant-001",
  "metadata": {
    "causationId": null,
    "correlationId": "...",
    "userId": "system",
    "source": "customer-relationship",
    "version": "1.0"
  },
  "customerId": "...",
  "customerNumber": "CUST-...",
  "customerType": "RETAIL",
  "status": "ACTIVE",
  "personalInfo": {
    "firstName": "John",
    "lastName": "Doe",
    "dateOfBirth": null,
    "gender": null,
    "taxId": null
  },
  "contactInfo": {
    "email": "john.doe@example.com",
    "phone": "+1-555-123-4567",
    "mobilePhone": null,
    "fax": null,
    "website": null,
    "preferredContactMethod": "EMAIL"
  }
}
```

**Check Service Logs:**

In customer-relationship service logs, you should see:

```
INFO  [com.chi.erp.cor.sha.eve.EventPublisher] Published event: CustomerCreated 
      for aggregate: Customer/[customer-id] to topic: crm.customer.events
```

### Step 6: Verify Multiple Events

Create several customers using different types:

```powershell
# RETAIL customer
curl -X POST http://localhost:8083/api/crm/customers -H "Content-Type: application/json" -d '{"firstName":"John","lastName":"Doe","email":"john@example.com","phone":"555-1111","customerType":"RETAIL","tenantId":"tenant-001"}'

# BUSINESS customer
curl -X POST http://localhost:8083/api/crm/customers -H "Content-Type: application/json" -d '{"firstName":"Jane","lastName":"Smith","email":"jane@business.com","phone":"555-2222","customerType":"BUSINESS","tenantId":"tenant-001"}'

# VIP customer
curl -X POST http://localhost:8083/api/crm/customers -H "Content-Type: application/json" -d '{"firstName":"Michael","lastName":"Johnson","email":"michael@vip.com","phone":"555-3333","customerType":"VIP","tenantId":"tenant-001"}'
```

Each should produce a CustomerCreatedEvent visible in the Kafka consumer.

## Expected Results

### ✅ Success Criteria

1. **Service Starts Successfully**
   - Customer-relationship service starts without errors
   - Kafka connection established
   - Health check returns UP status

2. **REST API Works**
   - POST /api/crm/customers accepts requests
   - Returns 201 Created with customer data
   - No errors in service logs

3. **Event Published to Kafka**
   - CustomerCreatedEvent appears in Kafka consumer
   - Event contains all required fields
   - Metadata includes correlationId, userId, source
   - Timestamp is in ISO-8601 format

4. **Logging Confirms Publishing**
   - Service logs show "Published event: CustomerCreated"
   - Logs include aggregate ID and topic name
   - No EventPublishingException thrown

### ❌ Common Issues & Troubleshooting

#### Issue 1: Service Won't Start
```
Error: Could not find or load main class
```
**Solution:** Rebuild the project
```powershell
cd services\customer-relationship
..\..\gradlew.bat clean build -x test
```

#### Issue 2: Kafka Connection Failed
```
org.apache.kafka.common.errors.TimeoutException: Failed to update metadata
```
**Solution:** Check Kafka is running
```powershell
docker ps | Select-String kafka
docker-compose up -d kafka
```

#### Issue 3: Topic Not Found
```
org.apache.kafka.common.errors.UnknownTopicOrPartitionException
```
**Solution:** Create the topic manually
```powershell
docker exec -it chiro-kafka kafka-topics.sh --create --bootstrap-server localhost:9092 --topic crm.customer.events --partitions 3 --replication-factor 1
```

#### Issue 4: Channel Not Found
```
jakarta.enterprise.inject.UnsatisfiedResolutionException: Unsatisfied dependency for type Emitter<String> and qualifiers [@Channel(value = "crm-customer-events")]
```
**Solution:** Verify application.properties has the channel configuration
```properties
mp.messaging.outgoing.crm-customer-events.connector=smallrye-kafka
mp.messaging.outgoing.crm-customer-events.topic=crm.customer.events
mp.messaging.outgoing.crm-customer-events.value.serializer=org.apache.kafka.common.serialization.StringSerializer
```

#### Issue 5: JSON Serialization Error
```
com.fasterxml.jackson.databind.exc.InvalidDefinitionException: Java 8 date/time type not supported by default
```
**Solution:** Verify ObjectMapper configuration includes JavaTimeModule (already configured in EventPublisher)

## Advanced Verification

### Check Kafka Topic Partitions
```powershell
docker exec -it chiro-kafka kafka-topics.sh \
  --describe \
  --bootstrap-server localhost:9092 \
  --topic crm.customer.events
```

### Count Events in Topic
```powershell
docker exec -it chiro-kafka kafka-run-class.sh kafka.tools.GetOffsetShell \
  --broker-list localhost:9092 \
  --topic crm.customer.events \
  --time -1
```

### View Consumer Group Status
```powershell
docker exec -it chiro-kafka kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --list

docker exec -it chiro-kafka kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --describe \
  --group customer-relationship-consumer-group
```

## Next Steps

After successful verification:

1. **Implement Event Consumers**
   - Create event listeners in other services
   - Subscribe to `crm.customer.events` topic
   - Process CustomerCreatedEvent for cross-service workflows

2. **Add Repository Layer**
   - Implement CustomerRepository for database persistence
   - Store customers in PostgreSQL
   - Add transactional boundaries around create + publish

3. **Implement Additional Events**
   - CustomerCreditLimitChangedEvent
   - CustomerStatusChangedEvent
   - CustomerContactUpdatedEvent
   - CustomerAssignedEvent

4. **Add Integration Tests**
   - Test event publishing in @QuarkusTest
   - Verify event structure matches schema
   - Test event metadata population

5. **Expand to Other Services**
   - Implement publishers in commerce-management (OrderCreatedEvent)
   - Implement publishers in financial-management (InvoiceGeneratedEvent)
   - Implement publishers in supply-chain (InventoryStockAdjustedEvent)

## Documentation References

- [Shared Event Library Guide](./SHARED-EVENT-LIBRARY-GUIDE.md)
- [Kafka Messaging Guide](./KAFKA-MESSAGING-GUIDE.md)
- [Event Library Architecture](./EVENT-LIBRARY-ARCHITECTURE.md)
- [Kafka Quick Reference](./KAFKA-QUICK-REF.md)
- [Testing Guide](./TESTING-GUIDE.md)

## Status

- **Implementation:** ✅ Complete
- **Testing:** ⚠️ Needs manual verification
- **Documentation:** ✅ Complete
- **Next Phase:** Event Consumers + Repository Layer
