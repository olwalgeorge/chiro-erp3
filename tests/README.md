# API Testing Guide

This directory contains REST API test files for testing the Chiro ERP microservices.

## 📁 Test Files

### 1. `api-tests.http`

Complete API test collection covering:

-   Health checks (all services)
-   Liveness probes
-   Readiness probes
-   Kafka messaging tests
-   Swagger UI endpoints
-   Metrics endpoints

### 2. `kafka-tests.http`

Focused Kafka messaging tests:

-   Connectivity checks
-   Simple message tests
-   Custom event tests
-   Integration scenarios
-   Stress tests

### 3. `health-checks.http`

Comprehensive health monitoring:

-   Overall health status
-   Liveness probes
-   Readiness probes
-   Startup probes

## 🚀 How to Use

### Option 1: VS Code REST Client Extension

1. **Install Extension**

    - Open VS Code Extensions (Ctrl+Shift+X)
    - Search for "REST Client"
    - Install "REST Client" by Huachao Mao

2. **Run Tests**

    - Open any `.http` file
    - Click "Send Request" above any request
    - Or use shortcut: `Ctrl+Alt+R` (Windows) / `Cmd+Alt+R` (Mac)

3. **Features**
    - Click individual requests to run one at a time
    - Use variables defined at the top
    - View responses in side panel
    - Save responses
    - View request/response history

### Option 2: IntelliJ IDEA HTTP Client

1. **Built-in Support**

    - IntelliJ IDEA has built-in support for `.http` files
    - Just open the file and click the green play button

2. **Run Tests**
    - Click the ▶️ icon next to any request
    - Or use shortcut: `Ctrl+Enter`

### Option 3: Postman

Import the requests into Postman:

1. Copy the request details from `.http` files
2. Create new requests in Postman
3. Save as a collection

### Option 4: cURL

Each request can be converted to cURL:

```bash
curl -X GET "http://localhost:8082/q/health" \
  -H "Accept: application/json"
```

## 📋 Test Scenarios

### Quick Health Check

Run all health checks to verify services are running:

```
File: health-checks.http
Section: OVERALL HEALTH CHECKS
```

### Test Kafka Messaging

1. Check Kafka connectivity:

    ```
    File: kafka-tests.http
    Section: KAFKA CONNECTIVITY TESTS
    ```

2. Send test messages:

    ```
    File: kafka-tests.http
    Section: SIMPLE MESSAGE TESTS
    ```

3. Run integration scenario:
    ```
    File: kafka-tests.http
    Section: INTEGRATION SCENARIO TESTS
    ```

### Stress Testing

Send multiple events quickly:

```
File: kafka-tests.http
Section: STRESS TESTS
```

## 🎯 Expected Responses

### Health Check (200 OK)

```json
{
    "status": "UP",
    "checks": [
        {
            "name": "Service Liveness Check",
            "status": "UP",
            "data": {
                "service": "administration",
                "status": "UP"
            }
        }
    ]
}
```

### Kafka Ping (200 OK)

```json
{
    "service": "administration",
    "status": "active",
    "kafka": "ready"
}
```

### Kafka Send (200 OK)

```json
{
    "status": "success",
    "message": "Event published successfully",
    "payload": "Test message from Administration"
}
```

### Service Down (503 Service Unavailable)

```html
<html>
    <body>
        <h1>Resource not found</h1>
    </body>
</html>
```

## 🔧 Variables

All test files use these port mappings:

-   Core Platform: `8081`
-   Administration: `8082`
-   Customer Relationship: `8083`
-   Operations Service: `8084`
-   Commerce: `8085`
-   Financial Management: `8086`
-   Supply Chain Manufacturing: `8087`

## 📊 Monitoring Results

### Check Service Logs

After sending Kafka messages, verify in service logs:

```bash
# View administration service logs
./gradlew :services:administration:quarkusDev

# Look for these log entries:
# - "Published event: TEST_EVENT with ID: xxx"
# - "Administration received event: {...}"
# - "Administration received shared event: {...}"
```

### Check Kafka Directly

```bash
# View all messages in shared-events topic
docker exec -it chiro-erp-kafka-1 kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic shared-events \
  --from-beginning

# View service-specific topic
docker exec -it chiro-erp-kafka-1 kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic administration-events \
  --from-beginning
```

## 🐛 Troubleshooting

### 404 Not Found

**Problem:** Endpoint returns 404
**Solution:**

-   Service hasn't been rebuilt with new endpoints
-   Run: `./gradlew :services:SERVICE_NAME:clean :services:SERVICE_NAME:build`
-   Restart service in dev mode

### Connection Refused

**Problem:** Cannot connect to service
**Solution:**

-   Check if service is running: `docker ps` or `netstat -ano | findstr :PORT`
-   Start service: `./gradlew :services:SERVICE_NAME:quarkusDev`

### Kafka Not Available

**Problem:** Kafka connection warnings in logs
**Solution:**

-   Check Kafka: `docker ps | Select-String kafka`
-   Start Kafka: `docker-compose up -d kafka`
-   Wait 30 seconds for Kafka to be ready

## 📝 Tips

1. **Run Tests in Order**: Start with health checks, then Kafka connectivity, then messaging
2. **Watch Logs**: Keep service logs open to see real-time event flow
3. **Use Scenarios**: Integration scenarios test realistic event flows
4. **Batch Testing**: Run multiple requests sequentially for end-to-end testing
5. **Save Responses**: REST Client extension saves responses for comparison

## 🚀 Quick Start

1. **Start Infrastructure**

    ```powershell
    docker-compose up -d kafka postgresql redis
    ```

2. **Start a Service**

    ```powershell
    .\scripts\start-with-kafka.ps1 -Service administration
    ```

3. **Run Health Check**

    - Open `health-checks.http`
    - Click "Send Request" on "Administration - Overall Health"
    - Verify status: "UP"

4. **Test Kafka**

    - Open `kafka-tests.http`
    - Run "Administration - Check Kafka Status"
    - Run "Administration - Send Simple Test"
    - Check service logs for published/consumed messages

5. **Verify in Kafka**
    ```powershell
    docker exec -it chiro-erp-kafka-1 kafka-console-consumer `
      --bootstrap-server localhost:9092 `
      --topic administration-events `
      --from-beginning
    ```

## 📚 Additional Resources

-   [REST Client Extension Docs](https://marketplace.visualstudio.com/items?itemName=humao.rest-client)
-   [Quarkus Health Checks](https://quarkus.io/guides/smallrye-health)
-   [Kafka Testing Guide](../docs/KAFKA-TESTING-GUIDE.md)
-   [Microservices README](../MICROSERVICES-README.md)

---

**Happy Testing! 🎉**
