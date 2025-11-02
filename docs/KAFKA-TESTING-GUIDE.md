# Kafka Messaging Testing Guide

**Last Updated:** November 2, 2025

---

## 🧪 Testing Methods Overview

There are **4 ways** to test Kafka messaging in your microservices:

1. ✅ **REST API Testing** (Easiest - Recommended for quick tests)
2. ✅ **Kafka Console Tools** (Direct Kafka interaction)
3. ✅ **Service-to-Service Testing** (Real-world scenario)
4. ✅ **Automated Integration Tests** (For CI/CD)

---

## Method 1: REST API Testing (Quickest) 🚀

### Prerequisites

```powershell
# 1. Start Kafka
docker-compose up -d kafka

# 2. Start a service in dev mode
./gradlew :services:administration:quarkusDev
```

### Test Publishing Events

```powershell
# Publish a test event from Administration service
curl -X POST http://localhost:8082/api/test/publish-event `
  -H "Content-Type: application/json" `
  -d '{"message": "Hello from Administration"}'

# Expected Response:
# {
#   "status": "Event published successfully",
#   "eventType": "TEST_EVENT",
#   "service": "administration"
# }
```

### Watch the Logs

In the terminal running `quarkusDev`, you'll see:

```
INFO  [com.chiro.erp.administration.shared.messaging.AdministrationEventProducer]
      Published event: TEST_EVENT with ID: 550e8400-e29b-41d4-a716-446655440000

INFO  [com.chiro.erp.administration.shared.messaging.AdministrationEventConsumer]
      Administration received event: {"eventId":"550e8400-...","eventType":"TEST_EVENT",...}
```

---

## Method 2: Kafka Console Tools 🛠️

### View Topics

```powershell
# List all topics
docker exec -it chiro-erp-kafka kafka-topics `
  --bootstrap-server localhost:9092 --list

# Expected output:
# administration-events
# commerce-events
# core-platform-events
# customer-relationship-events
# financial-management-events
# operations-service-events
# shared-events
# supply-chain-manufacturing-events
```

### Consume Messages

```powershell
# Listen to administration events
docker exec -it chiro-erp-kafka kafka-console-consumer `
  --bootstrap-server localhost:9092 `
  --topic administration-events `
  --from-beginning

# You'll see messages in real-time:
# {"eventId":"...","eventType":"TEST_EVENT","serviceName":"administration",...}
```

### Publish Test Message

```powershell
# Start a producer
docker exec -it chiro-erp-kafka kafka-console-producer `
  --bootstrap-server localhost:9092 `
  --topic administration-events

# Type a message and press Enter:
{"eventId":"test-123","eventType":"MANUAL_TEST","serviceName":"manual","timestamp":"2025-11-02T20:00:00Z","payload":"Hello from CLI"}

# Press Ctrl+C to exit
```

### Check Topic Details

```powershell
# Describe topic
docker exec -it chiro-erp-kafka kafka-topics `
  --bootstrap-server localhost:9092 `
  --describe --topic administration-events

# Output shows partitions, replicas, etc.
```

---

## Method 3: Service-to-Service Testing 🔄

This tests real inter-service communication.

### Setup: Start Multiple Services

**Terminal 1: Administration**

```powershell
./gradlew :services:administration:quarkusDev
```

**Terminal 2: Customer Relationship**

```powershell
./gradlew :services:customer-relationship:quarkusDev
```

**Terminal 3: Commerce**

```powershell
./gradlew :services:commerce:quarkusDev
```

### Test Scenario 1: Publish from One, Consume from Others

**Step 1: Publish from Administration**

```powershell
curl -X POST http://localhost:8082/api/test/publish-event `
  -H "Content-Type: application/json" `
  -d '{"message": "Customer order created"}'
```

**Step 2: Watch All Service Logs**

-   Administration logs: Shows published event
-   Customer Relationship logs: Shows received shared event
-   Commerce logs: Shows received shared event

### Test Scenario 2: Chain of Events

**Step 1: Administration publishes**

```powershell
curl -X POST http://localhost:8082/api/test/publish-event `
  -H "Content-Type: application/json" `
  -d '{"message": "Employee hired"}'
```

**Step 2: Customer Relationship publishes**

```powershell
curl -X POST http://localhost:8083/api/test/publish-event `
  -H "Content-Type: application/json" `
  -d '{"message": "New customer registered"}'
```

**Step 3: Commerce publishes**

```powershell
curl -X POST http://localhost:8085/api/test/publish-event `
  -H "Content-Type: application/json" `
  -d '{"message": "Order placed"}'
```

**Result:** All services receive all events on the `shared-events` topic!

---

## Method 4: Automated Testing 🤖

Create integration tests to verify messaging automatically.

### Example Test Script

Create: `scripts/test-kafka-messaging.ps1`

```powershell
#!/usr/bin/env pwsh

Write-Host "🧪 Testing Kafka Messaging..." -ForegroundColor Cyan
Write-Host ""

# Test configuration
$services = @(
    @{Name="administration"; Port=8082},
    @{Name="customer-relationship"; Port=8083},
    @{Name="commerce"; Port=8085}
)

$testsPassed = 0
$testsFailed = 0

foreach ($service in $services) {
    Write-Host "Testing $($service.Name)..." -ForegroundColor Yellow

    try {
        $response = Invoke-RestMethod `
            -Uri "http://localhost:$($service.Port)/api/test/publish-event" `
            -Method Post `
            -ContentType "application/json" `
            -Body '{"message":"Automated test"}'

        if ($response.status -eq "Event published successfully") {
            Write-Host "  ✅ $($service.Name) published event successfully" -ForegroundColor Green
            $testsPassed++
        } else {
            Write-Host "  ❌ $($service.Name) failed: Unexpected response" -ForegroundColor Red
            $testsFailed++
        }
    } catch {
        Write-Host "  ❌ $($service.Name) failed: $($_.Exception.Message)" -ForegroundColor Red
        $testsFailed++
    }

    Start-Sleep -Seconds 1
}

Write-Host ""
Write-Host "Test Results: $testsPassed passed, $testsFailed failed" -ForegroundColor Cyan
```

Run it:

```powershell
.\scripts\test-kafka-messaging.ps1
```

---

## 🎯 Complete Testing Workflow

### Step-by-Step: Full System Test

**1. Start Infrastructure**

```powershell
docker-compose up -d postgresql redis kafka minio keycloak
```

**2. Verify Kafka is Ready**

```powershell
docker logs chiro-erp-kafka | Select-String "started"
```

**3. Start Services** (3 separate terminals)

```powershell
# Terminal 1
./gradlew :services:administration:quarkusDev

# Terminal 2
./gradlew :services:customer-relationship:quarkusDev

# Terminal 3
./gradlew :services:commerce:quarkusDev
```

**4. Wait for Services to Start**
Look for this in each terminal:

```
Quarkus X.X.X on JVM started in X.XXXs
Listening on: http://localhost:XXXX
```

**5. Test Health Checks**

```powershell
curl http://localhost:8082/q/health
curl http://localhost:8083/q/health
curl http://localhost:8085/q/health
```

**6. Publish Test Events**

```powershell
# From Administration
curl -X POST http://localhost:8082/api/test/publish-event `
  -H "Content-Type: application/json" `
  -d '{"message":"Test 1"}'

# From Customer Relationship
curl -X POST http://localhost:8083/api/test/publish-event `
  -H "Content-Type: application/json" `
  -d '{"message":"Test 2"}'

# From Commerce
curl -X POST http://localhost:8085/api/test/publish-event `
  -H "Content-Type: application/json" `
  -d '{"message":"Test 3"}'
```

**7. Verify Consumption**
Check all 3 terminal windows - each should show:

-   Published their own event
-   Received shared events from other services

**8. Monitor with Kafka Console**

```powershell
# Open new terminal
docker exec -it chiro-erp-kafka kafka-console-consumer `
  --bootstrap-server localhost:9092 `
  --topic shared-events `
  --from-beginning
```

---

## 📊 Testing Checklist

Use this checklist to verify everything works:

### Infrastructure

-   [ ] Kafka container is running
-   [ ] PostgreSQL container is running
-   [ ] Redis container is running
-   [ ] All topics are created

### Services

-   [ ] All services start without errors
-   [ ] All health checks return 200 OK
-   [ ] All services can publish events
-   [ ] All services can consume events

### Messaging

-   [ ] Events appear in Kafka topics
-   [ ] Event format is correct (JSON with required fields)
-   [ ] Service-specific topics receive service events
-   [ ] Shared topic receives events from all services
-   [ ] Consumer groups are working
-   [ ] No message loss

---

## 🐛 Troubleshooting

### Issue: Events Not Being Published

**Check 1: Is Kafka running?**

```powershell
docker ps | Select-String "kafka"
```

**Check 2: Check service logs for errors**

```powershell
# In the terminal running quarkusDev, look for:
ERROR [io.smallrye.reactive.messaging.kafka]
```

**Check 3: Verify Kafka connection**

```powershell
# Check application.properties
kafka.bootstrap.servers=localhost:9092
```

### Issue: Events Not Being Consumed

**Check 1: Consumer group configured?**

```properties
mp.messaging.incoming.{service}-events-in.group.id={service}-group
```

**Check 2: Topic exists?**

```powershell
docker exec -it chiro-erp-kafka kafka-topics `
  --bootstrap-server localhost:9092 --list
```

**Check 3: Check consumer lag**

```powershell
docker exec -it chiro-erp-kafka kafka-consumer-groups `
  --bootstrap-server localhost:9092 `
  --describe --group administration-group
```

### Issue: Service Won't Start

**Check 1: Port already in use?**

```powershell
netstat -ano | findstr :8082
```

**Check 2: Build errors?**

```powershell
./gradlew :services:administration:build --info
```

---

## 💡 Quick Test Commands

### One-Liner Tests

```powershell
# Test and view response
curl -X POST http://localhost:8082/api/test/publish-event -H "Content-Type: application/json" -d '{"message":"quick test"}' | ConvertFrom-Json

# Test all services
8082,8083,8085 | ForEach-Object {
    Write-Host "Testing port $_...";
    curl -X POST "http://localhost:$_/api/test/publish-event" -H "Content-Type: application/json" -d '{"message":"test"}'
}

# Watch Kafka messages live
docker exec -it chiro-erp-kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic shared-events --from-beginning
```

---

## 📈 Performance Testing

### Load Test with Multiple Events

```powershell
# Send 100 events
1..100 | ForEach-Object {
    curl -X POST http://localhost:8082/api/test/publish-event `
      -H "Content-Type: application/json" `
      -d "{`"message`":`"Load test $_`"}"
    Start-Sleep -Milliseconds 100
}
```

### Monitor Message Rate

```powershell
# Check messages per topic
docker exec -it chiro-erp-kafka kafka-run-class kafka.tools.GetOffsetShell `
  --broker-list localhost:9092 `
  --topic administration-events
```

---

## ✅ Success Indicators

You know messaging is working when you see:

1. ✅ **Published Log**: `Published event: TEST_EVENT with ID: xxx`
2. ✅ **Consumed Log**: `Service received event: {"eventId":"xxx",...}`
3. ✅ **HTTP 200**: REST API returns success response
4. ✅ **Kafka Console**: Messages appear in console consumer
5. ✅ **Multiple Services**: All services receive shared events

---

## 🎓 Next Steps

Once basic messaging works:

1. **Add Custom Events**: Create domain-specific events
2. **Event Versioning**: Handle event schema evolution
3. **Error Handling**: Add dead-letter queues
4. **Monitoring**: Add metrics and alerts
5. **Tracing**: Add distributed tracing with correlation IDs

---

## 📚 Reference

### Event Format

```json
{
    "eventId": "uuid-v4",
    "eventType": "EVENT_TYPE",
    "serviceName": "service-name",
    "timestamp": "ISO-8601",
    "payload": "event-data"
}
```

### Endpoints

-   Health: `http://localhost:{PORT}/q/health`
-   Publish: `http://localhost:{PORT}/api/test/publish-event`
-   Swagger: `http://localhost:{PORT}/q/swagger-ui`

---

**Happy Testing! 🎉**
