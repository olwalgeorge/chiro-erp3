# Kafka REST Test Files Guide

## Overview

I've created **three comprehensive REST test files** for testing Kafka messaging in your ERP microservices:

## Test Files

### 1. `kafka-simple.rest` - Quick Start

**Purpose**: Simple, focused tests for beginners
**Best for**: Quick connectivity checks and basic message testing
**Contents**:

-   Basic connectivity tests (ping)
-   Simple message sending
-   Health checks
-   Clear instructions

**Use when**: You just want to verify Kafka is working

---

### 2. `kafka-administration.rest` - Single Service Focus

**Purpose**: Comprehensive tests for the Administration service
**Best for**: Detailed testing of one service at a time
**Contents**:

-   Complete health check suite
-   Kafka connectivity verification
-   Business-relevant test messages (HR events)
-   Various message formats (short, long, special chars)
-   Rapid-fire throughput tests
-   Detailed troubleshooting guide

**Use when**: Testing or debugging a single service in dev mode

---

### 3. `kafka-complete.rest` - Full Suite

**Purpose**: Complete test coverage for all 7 microservices
**Best for**: Integration testing and end-to-end workflows
**Contents**:

-   Connectivity tests for all 7 services
-   Business event scenarios per domain
-   End-to-end workflow simulation
-   Error handling tests
-   Performance/batch tests
-   Multi-service coordination tests

**Use when**: Testing service interactions and cross-service messaging

---

## How to Use

### Prerequisites

1. **Start Docker Infrastructure**:

    ```powershell
    docker-compose up -d
    ```

2. **Verify Kafka is Running**:

    ```powershell
    docker ps | grep kafka
    ```

3. **Start a Service in Dev Mode**:

    ```powershell
    # Option 1: Use the test script (recommended)
    .\scripts\test-kafka-endpoints.ps1

    # Option 2: Manual start
    ./gradlew :services:administration:quarkusDev
    ```

### Running Tests

#### In VS Code:

1. **Install Extension**: Install "REST Client" extension by Huachao Mao
2. **Open Test File**: Open any `.rest` file from `tests/` folder
3. **Send Request**: Click "Send Request" link above any `###` separator
4. **View Response**: Response appears in a split pane on the right

#### In Other Editors:

Use `curl` commands based on the HTTP requests in the files:

```bash
# Ping test
curl http://localhost:8082/api/test/kafka/ping

# Send message
curl "http://localhost:8082/api/test/kafka/send?message=Hello"
```

---

## Test File Comparison

| Feature              | kafka-simple.rest | kafka-administration.rest | kafka-complete.rest |
| -------------------- | ----------------- | ------------------------- | ------------------- |
| **Services Covered** | 2 (Admin, Core)   | 1 (Admin only)            | 7 (All services)    |
| **Test Count**       | ~8 tests          | ~25 tests                 | ~60+ tests          |
| **Complexity**       | Basic             | Intermediate              | Advanced            |
| **Documentation**    | Brief             | Detailed                  | Comprehensive       |
| **Use Case**         | Quick check       | Deep testing              | Integration testing |
| **Scenarios**        | None              | Business events           | E2E workflows       |
| **Error Tests**      | No                | Limited                   | Extensive           |

---

## Test Workflow Recommendations

### For Initial Setup:

1. Start with **`kafka-simple.rest`**
2. Test connectivity with ping endpoints
3. Send one simple message
4. Verify in service logs

### For Development:

1. Use **`kafka-administration.rest`** (or equivalent for your service)
2. Test various message types
3. Run rapid-fire tests for performance
4. Check service logs for consumer messages

### For Integration Testing:

1. Use **`kafka-complete.rest`**
2. Run the end-to-end workflow scenario (Section 4)
3. Verify messages flow across services
4. Test error handling scenarios

---

## Expected Responses

### Successful Ping Response:

```json
{
    "status": "ok",
    "message": "Kafka messaging is configured"
}
```

### Successful Send Response:

```json
{
    "status": "sent",
    "message": "Your custom message here",
    "eventId": "550e8400-e29b-41d4-a716-446655440000",
    "timestamp": "2024-11-02T22:30:00.000Z"
}
```

### Successful Health Check:

```json
{
    "status": "UP",
    "checks": [
        {
            "name": "SmallRye Reactive Messaging - liveness check",
            "status": "UP"
        },
        {
            "name": "SmallRye Reactive Messaging - readiness check",
            "status": "UP"
        }
    ]
}
```

---

## Monitoring Kafka Messages

### View Messages in Real-Time:

```bash
# View administration-events topic
docker exec -it chiro-erp-kafka-1 kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic administration-events \
  --from-beginning

# View shared-events topic (cross-service)
docker exec -it chiro-erp-kafka-1 kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic shared-events \
  --from-beginning
```

### List All Topics:

```bash
docker exec -it chiro-erp-kafka-1 kafka-topics \
  --bootstrap-server localhost:9092 \
  --list
```

### Check Consumer Groups:

```bash
docker exec -it chiro-erp-kafka-1 kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --list
```

---

## Troubleshooting Guide

### Error: 404 Not Found

**Cause**: Service not running or endpoint doesn't exist
**Solution**:

-   Start service: `.\scripts\test-kafka-endpoints.ps1`
-   Verify service is running: `Get-Process -Name java`

### Error: Connection Refused

**Cause**: Service not accessible on the specified port
**Solution**:

-   Check if service started successfully
-   Verify port in application.properties matches test file
-   Check firewall settings

### Error: Kafka Connection Issues in Logs

**Cause**: Wrong Kafka port configuration
**Solution**:

-   Dev mode should use `localhost:9093`
-   Docker mode should use `kafka:9092`
-   Check environment variable: `$env:KAFKA_BOOTSTRAP_SERVERS`

### Messages Not Consumed

**Cause**: Consumer not running or not subscribed
**Solution**:

-   Check service logs for consumer startup messages
-   Verify topics exist in Kafka
-   Check consumer group membership

---

## Tips & Best Practices

### 1. **Watch Service Logs**

Always keep the service terminal visible to see:

-   Producer logs: "Publishing event to Kafka: ..."
-   Consumer logs: "Received event: ..."
-   Any Kafka connection errors

### 2. **Test Incrementally**

-   Start with ping tests
-   Then try simple sends
-   Graduate to complex scenarios
-   Finally test error cases

### 3. **Use Variables**

The test files use variables like `{{baseUrl}}` and `{{$timestamp}}`:

-   Modify base URLs at the top of each file
-   `{{$timestamp}}` auto-generates current timestamp
-   Add your own variables as needed

### 4. **Batch Testing**

To run multiple tests:

-   Use the "Send Request" link above each separator
-   Or use VS Code's "Send All Requests" command
-   Or script them with `curl` in a loop

### 5. **Performance Testing**

The rapid-fire sections are for throughput testing:

-   Click "Send Request" repeatedly
-   Watch Kafka handle the load
-   Monitor service logs for backpressure

---

## File Locations

```
tests/
├── kafka-simple.rest          # Quick start tests
├── kafka-administration.rest  # Admin service focused
├── kafka-complete.rest        # Full suite
└── kafka-tests.http          # Original comprehensive tests
```

All files are ready to use immediately! 🚀

---

## Next Steps

1. **Choose Your Test File** based on your current needs
2. **Start Your Service** using the test script
3. **Open the REST File** in VS Code
4. **Click "Send Request"** to start testing
5. **Monitor Logs** in your service terminal
6. **Verify Messages** in Kafka using Docker commands

Happy Testing! 🎉
