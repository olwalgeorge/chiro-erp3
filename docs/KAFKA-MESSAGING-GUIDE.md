# Kafka Messaging Guide - ChiroERP Microservices

**Date:** November 2, 2025
**Status:** ✅ Implemented & Tested

---

## Overview

All 7 microservices in the ChiroERP system now have Kafka messaging capabilities for event-driven communication. Each service can publish and consume events through dedicated Kafka topics.

---

## Architecture

### Messaging Pattern

-   **Event-Driven Architecture**: Services communicate asynchronously via Kafka
-   **Topic per Service**: Each service has its own topic for service-specific events
-   **Shared Events**: Common events are published to a `shared-events` topic
-   **KRaft Mode**: Kafka runs in KRaft mode (no Zookeeper dependency)

### Service Topics

| Service                    | Topic Name                          | Port         |
| -------------------------- | ----------------------------------- | ------------ |
| Core Platform              | `core-platform-events`              | 8081         |
| Administration             | `administration-events`             | 8082         |
| Customer Relationship      | `customer-relationship-events`      | 8083         |
| Operations Service         | `operations-service-events`         | 8084         |
| Commerce                   | `commerce-events`                   | 8085         |
| Financial Management       | `financial-management-events`       | 8086         |
| Supply Chain Manufacturing | `supply-chain-manufacturing-events` | 8087         |
| **Shared Events**          | `shared-events`                     | All services |

---

## Dependencies

All services automatically inherit these dependencies from root `build.gradle`:

```gradle
// Kafka Messaging
implementation 'io.quarkus:quarkus-messaging-kafka'

// Health Checks
implementation 'io.quarkus:quarkus-smallrye-health'
```

---

## Configuration

Each service's `application.properties` includes:

```properties
# Kafka Configuration
kafka.bootstrap.servers=${KAFKA_BOOTSTRAP_SERVERS:localhost:9092}

# Kafka Reactive Messaging Channels
mp.messaging.outgoing.{service}-events-out.connector=smallrye-kafka
mp.messaging.outgoing.{service}-events-out.topic={service}-events
mp.messaging.outgoing.{service}-events-out.value.serializer=org.apache.kafka.common.serialization.StringSerializer

mp.messaging.incoming.{service}-events-in.connector=smallrye-kafka
mp.messaging.incoming.{service}-events-in.topic={service}-events
mp.messaging.incoming.{service}-events-in.value.deserializer=org.apache.kafka.common.serialization.StringDeserializer
mp.messaging.incoming.{service}-events-in.group.id={service}-group

mp.messaging.incoming.shared-events.connector=smallrye-kafka
mp.messaging.incoming.shared-events.topic=shared-events
mp.messaging.incoming.shared-events.value.deserializer=org.apache.kafka.common.serialization.StringDeserializer
mp.messaging.incoming.shared-events.group.id={service}-shared-group
```

---

## Testing Kafka Messaging

### 1. Start Infrastructure

```powershell
# Start Kafka and other infrastructure
docker-compose up -d postgresql redis kafka minio keycloak
```

### 2. Verify Kafka is Running

```powershell
docker ps | Select-String "kafka"
```

### 3. Start a Service

```powershell
# Example: Start Administration service
./gradlew :services:administration:quarkusDev
```

### 4. Test Event Publishing via REST API

Each service has a test endpoint at `/api/test/publish-event`:

```powershell
# Publish test event from Administration service
curl -X POST http://localhost:8082/api/test/publish-event `
  -H "Content-Type: application/json" `
  -d '{"message": "Test event from Administration"}'
```

### 5. Expected Response

```json
{
    "status": "Event published successfully",
    "eventType": "TEST_EVENT",
    "service": "administration"
}
```

### 6. Check Logs

The consuming service will log the received event:

```
INFO  [com.chiro.erp.administration.shared.messaging.AdministrationEventConsumer]
      Administration received event: {"eventId":"...","eventType":"TEST_EVENT",...}
```

---

## Event Format

All events follow this JSON structure:

```json
{
    "eventId": "uuid-v4",
    "eventType": "EVENT_TYPE",
    "serviceName": "service-name",
    "timestamp": "ISO-8601-timestamp",
    "payload": "event-specific-data"
}
```

---

## Health Checks

Each service has liveness and readiness probes:

### Health Check Endpoints

```
Liveness:  http://localhost:{PORT}/q/health/live
Readiness: http://localhost:{PORT}/q/health/ready
Combined:  http://localhost:{PORT}/q/health
UI:        http://localhost:{PORT}/q/health-ui
```

### Test All Services Health

```powershell
# Core Platform
curl http://localhost:8081/q/health

# Administration
curl http://localhost:8082/q/health

# Customer Relationship
curl http://localhost:8083/q/health

# Operations Service
curl http://localhost:8084/q/health

# Commerce
curl http://localhost:8085/q/health

# Financial Management
curl http://localhost:8086/q/health

# Supply Chain Manufacturing
curl http://localhost:8087/q/health
```

---

## Service Components

Each service has the following Kafka components:

### 1. Event Producer

Location: `services/{service}/src/main/kotlin/.../shared/messaging/KafkaMessaging.kt`

```kotlin
@ApplicationScoped
class {Service}EventProducer(
    @Channel("{service}-events-out")
    private val eventEmitter: Emitter<String>
) {
    fun publishEvent(eventType: String, payload: String) {
        // Publishes events to Kafka
    }
}
```

### 2. Event Consumer

```kotlin
@ApplicationScoped
class {Service}EventConsumer {
    @Incoming("{service}-events-in")
    fun consumeEvent(message: String) {
        // Consumes service-specific events
    }

    @Incoming("shared-events")
    fun consumeSharedEvent(message: String) {
        // Consumes shared events from other services
    }
}
```

### 3. Test REST Endpoint

Location: `services/{service}/src/main/kotlin/.../shared/messaging/TestEventEndpoint.kt`

```kotlin
@Path("/api/test")
class TestEventEndpoint(
    private val eventProducer: {Service}EventProducer
) {
    @POST
    @Path("/publish-event")
    fun publishTestEvent(request: TestEventRequest): TestEventResponse
}
```

---

## Kafka Admin UI

Access Kafka UI (if using docker-compose with kafka-ui):

```
http://localhost:8090
```

View topics, messages, consumer groups, and more.

---

## Deployment

### Development Mode

```powershell
# Start single service
./gradlew :services:administration:quarkusDev

# Start all services (use separate terminals)
./gradlew :services:core-platform:quarkusDev
./gradlew :services:administration:quarkusDev
./gradlew :services:customer-relationship:quarkusDev
./gradlew :services:operations-service:quarkusDev
./gradlew :services:commerce:quarkusDev
./gradlew :services:financial-management:quarkusDev
./gradlew :services:supply-chain-manufacturing:quarkusDev
```

### Docker Deployment

```powershell
# Build all services
./gradlew clean build -x test

# Start all services with docker-compose
docker-compose up -d
```

---

## Monitoring

### Check Kafka Topics

```powershell
# List all topics
docker exec -it chiro-erp-kafka kafka-topics --bootstrap-server localhost:9092 --list

# Describe a topic
docker exec -it chiro-erp-kafka kafka-topics --bootstrap-server localhost:9092 --describe --topic administration-events
```

### Consume Messages from CLI

```powershell
# Listen to administration events
docker exec -it chiro-erp-kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic administration-events \
  --from-beginning
```

### Publish Test Message from CLI

```powershell
# Publish to shared events
docker exec -it chiro-erp-kafka kafka-console-producer \
  --bootstrap-server localhost:9092 \
  --topic shared-events
```

---

## Troubleshooting

### Issue: Kafka Connection Failed

**Solution:**

```powershell
# Verify Kafka is running
docker ps | Select-String "kafka"

# Check Kafka logs
docker logs chiro-erp-kafka

# Restart Kafka
docker-compose restart kafka
```

### Issue: Events Not Being Consumed

**Solution:**

1. Check consumer group status
2. Verify topic exists
3. Check application logs for errors
4. Ensure serializers/deserializers match

### Issue: Service Health Check Fails

**Solution:**

```powershell
# Check service logs
./gradlew :services:administration:quarkusDev

# Verify port is not in use
netstat -ano | findstr :8082
```

---

## Next Steps

1. ✅ **Complete**: Basic Kafka messaging setup
2. ✅ **Complete**: Health checks for all services
3. 🚀 **Deploy**: Test all services together
4. 📊 **Monitor**: Set up Prometheus + Grafana
5. 🔐 **Secure**: Add Keycloak authentication
6. 🗄️ **Database**: Enable PostgreSQL connections
7. 📝 **Document**: Add business logic to each service

---

## Summary

✅ **7 Microservices** with Kafka messaging
✅ **Health checks** (liveness & readiness)
✅ **Event-driven** architecture
✅ **KRaft mode** Kafka (no Zookeeper)
✅ **REST test endpoints** for easy testing
✅ **Comprehensive logging**
✅ **Docker-ready** deployment

---

**All services are ready for deployment and testing! 🎉**
