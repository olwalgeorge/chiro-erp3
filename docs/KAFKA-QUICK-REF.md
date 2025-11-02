# Kafka Testing - Quick Reference Card

## 🚀 Quick Start (3 Steps)

1. **Start Infrastructure**

    ```powershell
    docker-compose up -d
    ```

2. **Start Service**

    ```powershell
    .\scripts\test-kafka-endpoints.ps1
    ```

3. **Test in VS Code**
    - Open `tests/kafka-simple.rest`
    - Click "Send Request" above any `###`

---

## 📁 Test Files

| File                          | Purpose                     | When to Use         |
| ----------------------------- | --------------------------- | ------------------- |
| **kafka-simple.rest**         | Quick tests (2 services)    | First-time testing  |
| **kafka-administration.rest** | Deep dive (Admin service)   | Single service dev  |
| **kafka-complete.rest**       | Full suite (All 7 services) | Integration testing |
| **kafka-tests.http**          | Original comprehensive      | Alternative format  |

---

## 🎯 Common Test Endpoints

```http
# Check Kafka connectivity
GET http://localhost:8082/api/test/kafka/ping

# Send simple message
GET http://localhost:8082/api/test/kafka/send

# Send custom message
GET http://localhost:8082/api/test/kafka/send?message=Hello World

# Health check
GET http://localhost:8082/q/health
```

---

## 🔍 Monitor Kafka Messages

```bash
# View all messages in a topic
docker exec -it chiro-erp-kafka-1 kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic administration-events \
  --from-beginning
```

---

## ⚙️ Port Configuration

| Environment            | Kafka Host | Port |
| ---------------------- | ---------- | ---- |
| **Dev Mode** (local)   | localhost  | 9093 |
| **Docker** (container) | kafka      | 9092 |

**Important**: Dev mode uses **9093**, not 9092!

---

## ✅ Expected Responses

### Ping Success:

```json
{ "status": "ok", "message": "Kafka messaging is configured" }
```

### Send Success:

```json
{
    "status": "sent",
    "message": "Your message",
    "eventId": "uuid-here",
    "timestamp": "2024-11-02T22:30:00Z"
}
```

---

## 🐛 Quick Troubleshooting

| Problem               | Solution                                            |
| --------------------- | --------------------------------------------------- |
| 404 Error             | Start service: `.\scripts\test-kafka-endpoints.ps1` |
| Connection Refused    | Service not running - check terminal                |
| Kafka errors in logs  | Check port: should be `localhost:9093` for dev      |
| Messages not consumed | Look for consumer logs in service terminal          |

---

## 📊 What to Watch in Service Logs

✅ **Good Signs:**

```
Publishing event to Kafka: ...
Received administration event: ...
Kafka producer connected to localhost:9093
```

❌ **Bad Signs:**

```
UnknownHostException: kafka
Connection refused
Error connecting to node kafka:9092
```

---

## 🎬 Complete Test Workflow

1. Start Docker: `docker-compose up -d`
2. Run test script: `.\scripts\test-kafka-endpoints.ps1`
3. Wait for "Listening on: http://localhost:8082"
4. Open `tests/kafka-administration.rest` in VS Code
5. Send ping test - should get `{"status":"ok"}`
6. Send message test - should get event ID
7. Check service terminal - see consumer logs
8. Monitor Kafka topic - see messages persist

---

## 💡 Pro Tips

-   **Keep service terminal visible** to see real-time logs
-   **Start with simple tests** before complex scenarios
-   **Use `{{$timestamp}}`** in messages for uniqueness
-   **Run rapid-fire tests** to check throughput
-   **Monitor Kafka directly** to verify persistence

---

## 📚 Full Documentation

-   Detailed guide: `docs/KAFKA-REST-TESTS-GUIDE.md`
-   Port configuration: `docs/KAFKA-PORT-CONFIGURATION.md`
-   General testing: `docs/TESTING-GUIDE.md`

---

## 🆘 Need Help?

1. Check service is running: `Get-Process -Name java`
2. Check Kafka is running: `docker ps | grep kafka`
3. Check environment: `$env:KAFKA_BOOTSTRAP_SERVERS`
4. Check service logs in terminal
5. Review `docs/KAFKA-PORT-CONFIGURATION.md`

---

**Ready to Test?** Open `tests/kafka-simple.rest` and click "Send Request"! 🚀
