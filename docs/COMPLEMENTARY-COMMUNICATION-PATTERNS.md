# Complementary Communication Patterns for DDD & EDA

## Overview

This guide explores communication patterns that complement REST, GraphQL, and Kafka in your ChiroERP microservices architecture, enhancing efficiency for specific use cases.

---

## 🎯 Communication Pattern Matrix

| Pattern                       | Best For                          | Complements | Use Case in ChiroERP                 |
| ----------------------------- | --------------------------------- | ----------- | ------------------------------------ |
| **gRPC**                      | Synchronous RPC, High Performance | REST        | Service-to-service internal calls    |
| **WebSockets**                | Real-time Bidirectional           | REST, Kafka | Live dashboards, notifications       |
| **Server-Sent Events (SSE)**  | Server Push                       | REST        | Progress updates, live feeds         |
| **Message Queues (RabbitMQ)** | Task Distribution                 | Kafka       | Command processing, job queues       |
| **Redis Pub/Sub**             | Fast Event Broadcasting           | Kafka       | Cache invalidation, session sync     |
| **Shared Memory/Database**    | Read-Heavy Patterns               | All         | CQRS read models, materialized views |
| **Service Mesh (Envoy)**      | Infrastructure Communication      | All         | Service discovery, load balancing    |

---

## 1. gRPC - High-Performance RPC

### When to Use (Complementing REST)

-   **Internal service-to-service** communication requiring high performance
-   **Strongly-typed contracts** between microservices
-   **Streaming data** between services
-   **Low-latency** requirements

### ChiroERP Use Cases

#### 1.1 Financial Management ↔ Customer Service Communication

```kotlin
// services/financial-management/src/main/proto/customer_service.proto
syntax = "proto3";

package com.chiroerp.customer;

service CustomerGrpcService {
  rpc GetCustomerDetails(CustomerRequest) returns (CustomerResponse);
  rpc GetCustomersBatch(CustomerBatchRequest) returns (stream CustomerResponse);
  rpc ValidateCreditLimit(CreditCheckRequest) returns (CreditCheckResponse);
}

message CustomerRequest {
  string customer_id = 1;
  bool include_credit_info = 2;
  bool include_order_history = 3;
}

message CustomerResponse {
  string customer_id = 1;
  string company_name = 2;
  string contact_name = 3;
  CreditInfo credit_info = 4;
  string status = 5;
  Address billing_address = 6;
}

message CreditCheckRequest {
  string customer_id = 1;
  double amount = 2;
}

message CreditCheckResponse {
  bool approved = 1;
  double available_credit = 2;
  string reason = 3;
}
```

#### 1.2 Implementation Example

```kotlin
// services/customer-relationship/src/main/kotlin/com/chiroerp/customer/grpc/CustomerGrpcServiceImpl.kt
package com.chiroerp.customer.grpc

import com.chiroerp.customer.proto.*
import io.grpc.stub.StreamObserver
import org.springframework.stereotype.Service

@Service
class CustomerGrpcServiceImpl(
    private val customerRepository: CustomerRepository,
    private val creditService: CreditService
) : CustomerGrpcServiceGrpc.CustomerGrpcServiceImplBase() {

    override fun getCustomerDetails(
        request: CustomerRequest,
        responseObserver: StreamObserver<CustomerResponse>
    ) {
        try {
            val customer = customerRepository.findById(request.customerId)
                .orElseThrow { CustomerNotFoundException(request.customerId) }

            val response = CustomerResponse.newBuilder()
                .setCustomerId(customer.id)
                .setCompanyName(customer.companyName)
                .setContactName(customer.contactName)
                .setStatus(customer.status.name)

            if (request.includeCreditInfo) {
                val creditInfo = creditService.getCreditInfo(customer.id)
                response.setCreditInfo(creditInfo.toProto())
            }

            responseObserver.onNext(response.build())
            responseObserver.onCompleted()
        } catch (e: Exception) {
            responseObserver.onError(e)
        }
    }

    override fun getCustomersBatch(
        request: CustomerBatchRequest,
        responseObserver: StreamObserver<CustomerResponse>
    ) {
        try {
            request.customerIdsList.forEach { customerId ->
                val customer = customerRepository.findById(customerId).orElse(null)
                customer?.let {
                    responseObserver.onNext(it.toProtoResponse())
                }
            }
            responseObserver.onCompleted()
        } catch (e: Exception) {
            responseObserver.onError(e)
        }
    }

    override fun validateCreditLimit(
        request: CreditCheckRequest,
        responseObserver: StreamObserver<CreditCheckResponse>
    ) {
        try {
            val result = creditService.validateCredit(request.customerId, request.amount)

            val response = CreditCheckResponse.newBuilder()
                .setApproved(result.approved)
                .setAvailableCredit(result.availableCredit)
                .setReason(result.reason)
                .build()

            responseObserver.onNext(response)
            responseObserver.onCompleted()
        } catch (e: Exception) {
            responseObserver.onError(e)
        }
    }
}

// Client in Financial Management Service
@Service
class CustomerGrpcClient(
    @Value("\${grpc.customer-service.host}") private val host: String,
    @Value("\${grpc.customer-service.port}") private val port: Int
) {
    private val channel = ManagedChannelBuilder
        .forAddress(host, port)
        .usePlaintext()
        .build()

    private val stub = CustomerGrpcServiceGrpc.newBlockingStub(channel)

    fun getCustomerDetails(customerId: String, includeCreditInfo: Boolean): CustomerResponse {
        val request = CustomerRequest.newBuilder()
            .setCustomerId(customerId)
            .setIncludeCreditInfo(includeCreditInfo)
            .build()

        return stub.getCustomerDetails(request)
    }

    fun validateCreditLimit(customerId: String, amount: Double): CreditCheckResponse {
        val request = CreditCheckRequest.newBuilder()
            .setCustomerId(customerId)
            .setAmount(amount)
            .build()

        return stub.validateCreditLimit(request)
    }

    fun getCustomersBatch(customerIds: List<String>): List<CustomerResponse> {
        val request = CustomerBatchRequest.newBuilder()
            .addAllCustomerIds(customerIds)
            .build()

        return stub.getCustomersBatch(request).asSequence().toList()
    }
}
```

### Benefits Over REST

-   **10-50x faster** for internal calls
-   **Smaller payload** (binary vs JSON)
-   **Built-in streaming** support
-   **Strongly-typed** contracts

---

## 2. WebSockets - Real-Time Bidirectional Communication

### When to Use (Complementing REST/Kafka)

-   **Real-time dashboards** and monitoring
-   **Live notifications** to users
-   **Collaborative features** (multiple users editing)
-   **Live chat/messaging**

### ChiroERP Use Cases

#### 2.1 Real-Time Inventory & Order Dashboard

```kotlin
// services/gateway-service/src/main/kotlin/com/chiroerp/gateway/websocket/InventoryWebSocketHandler.kt
package com.chiroerp.gateway.websocket

import org.springframework.stereotype.Component
import org.springframework.web.socket.TextMessage
import org.springframework.web.socket.WebSocketSession
import org.springframework.web.socket.handler.TextWebSocketHandler
import com.fasterxml.jackson.databind.ObjectMapper
import java.util.concurrent.ConcurrentHashMap

@Component
class InventoryWebSocketHandler(
    private val objectMapper: ObjectMapper,
    private val kafkaTemplate: KafkaTemplate<String, String>
) : TextWebSocketHandler() {

    private val sessions = ConcurrentHashMap<String, WebSocketSession>()
    private val userSubscriptions = ConcurrentHashMap<String, MutableSet<String>>()

    override fun afterConnectionEstablished(session: WebSocketSession) {
        val userId = extractUserId(session)
        sessions[userId] = session
        userSubscriptions[userId] = mutableSetOf()

        // Send initial data
        sendMessage(session, InventoryUpdate(
            type = "CONNECTED",
            message = "Connected to inventory updates"
        ))
    }

    override fun handleTextMessage(session: WebSocketSession, message: TextMessage) {
        val payload = objectMapper.readValue(message.payload, WebSocketMessage::class.java)
        val userId = extractUserId(session)

        when (payload.type) {
            "SUBSCRIBE_WAREHOUSE" -> {
                userSubscriptions[userId]?.add(payload.warehouseId)
                sendWarehouseInventory(session, payload.warehouseId)
            }
            "UNSUBSCRIBE_WAREHOUSE" -> {
                userSubscriptions[userId]?.remove(payload.warehouseId)
            }
            "SUBSCRIBE_PRODUCT" -> {
                userSubscriptions[userId]?.add("product:${payload.productId}")
                sendProductUpdates(session, payload.productId)
            }
        }
    }

    // Called when Kafka event received
    @KafkaListener(topics = ["inventory-events", "order-events"])
    fun handleInventoryEvent(event: InventoryEvent) {
        sessions.forEach { (userId, session) ->
            val subscriptions = userSubscriptions[userId] ?: return@forEach

            // Check if user subscribed to this warehouse or product
            val isSubscribed = subscriptions.contains(event.warehouseId) ||
                               subscriptions.contains("product:${event.productId}")

            if (isSubscribed) {
                sendMessage(session, event)
            }
        }
    }

    private fun sendMessage(session: WebSocketSession, data: Any) {
        if (session.isOpen) {
            val json = objectMapper.writeValueAsString(data)
            session.sendMessage(TextMessage(json))
        }
    }

    override fun afterConnectionClosed(session: WebSocketSession, status: CloseStatus) {
        val userId = extractUserId(session)
        sessions.remove(userId)
        userSubscriptions.remove(userId)
    }
}

// Configuration
@Configuration
@EnableWebSocket
class WebSocketConfig : WebSocketConfigurer {

    @Autowired
    private lateinit var inventoryWebSocketHandler: InventoryWebSocketHandler

    override fun registerWebSocketHandlers(registry: WebSocketHandlerRegistry) {
        registry.addHandler(inventoryWebSocketHandler, "/ws/inventory")
            .setAllowedOrigins("*")
            .withSockJS()
    }
}
```

#### 2.2 Frontend Integration (React Example)

```typescript
// frontend/src/services/inventoryWebSocket.ts
class InventoryWebSocketService {
    private socket: WebSocket | null = null;
    private listeners: Map<string, Set<(data: any) => void>> = new Map();

    connect(token: string) {
        this.socket = new WebSocket(`ws://localhost:8080/ws/inventory?token=${token}`);

        this.socket.onmessage = (event) => {
            const data = JSON.parse(event.data);
            this.notifyListeners(data.type, data);
        };

        this.socket.onopen = () => {
            console.log("WebSocket connected");
        };

        this.socket.onerror = (error) => {
            console.error("WebSocket error:", error);
        };
    }

    subscribeToWarehouse(warehouseId: string) {
        this.send({
            type: "SUBSCRIBE_WAREHOUSE",
            warehouseId: warehouseId,
        });
    }

    subscribeToProduct(productId: string) {
        this.send({
            type: "SUBSCRIBE_PRODUCT",
            productId: productId,
        });
    }

    on(eventType: string, callback: (data: any) => void) {
        if (!this.listeners.has(eventType)) {
            this.listeners.set(eventType, new Set());
        }
        this.listeners.get(eventType)!.add(callback);
    }

    private send(data: any) {
        if (this.socket?.readyState === WebSocket.OPEN) {
            this.socket.send(JSON.stringify(data));
        }
    }

    private notifyListeners(eventType: string, data: any) {
        this.listeners.get(eventType)?.forEach((callback) => callback(data));
    }
}

export const inventoryWS = new InventoryWebSocketService();
```

---

## 3. Server-Sent Events (SSE) - Server Push

### When to Use (Complementing REST)

-   **One-way** server-to-client updates
-   **Progress tracking** for long operations
-   **Live feeds** and notifications
-   **Simpler than WebSocket** when bidirectional not needed

### ChiroERP Use Cases

#### 3.1 Report Generation & Batch Processing Progress

```kotlin
// services/reporting-service/src/main/kotlin/com/chiroerp/reporting/controller/ReportStreamController.kt
package com.chiroerp.reporting.controller

import org.springframework.http.MediaType
import org.springframework.web.bind.annotation.*
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter
import java.util.concurrent.ConcurrentHashMap

@RestController
@RequestMapping("/api/reports")
class ReportStreamController(
    private val reportService: ReportService
) {
    private val emitters = ConcurrentHashMap<String, SseEmitter>()

    @GetMapping("/stream/{reportId}", produces = [MediaType.TEXT_EVENT_STREAM_VALUE])
    fun streamReportProgress(@PathVariable reportId: String): SseEmitter {
        val emitter = SseEmitter(30 * 60 * 1000L) // 30 minutes timeout
        emitters[reportId] = emitter

        emitter.onCompletion { emitters.remove(reportId) }
        emitter.onTimeout { emitters.remove(reportId) }
        emitter.onError { emitters.remove(reportId) }

        // Start report generation
        reportService.generateReportAsync(reportId, object : ProgressCallback {
            override fun onProgress(stage: String, percentage: Int, message: String) {
                try {
                    emitter.send(
                        SseEmitter.event()
                            .name("progress")
                            .data(mapOf(
                                "stage" to stage,
                                "percentage" to percentage,
                                "message" to message
                            ))
                    )
                } catch (e: Exception) {
                    emitter.completeWithError(e)
                }
            }

            override fun onComplete(downloadUrl: String) {
                try {
                    emitter.send(
                        SseEmitter.event()
                            .name("complete")
                            .data(mapOf("downloadUrl" to downloadUrl))
                    )
                    emitter.complete()
                } catch (e: Exception) {
                    emitter.completeWithError(e)
                }
            }

            override fun onError(error: String) {
                emitter.completeWithError(RuntimeException(error))
            }
        })

        return emitter
    }
}

@Service
class ReportService {
    fun generateReportAsync(reportId: String, callback: ProgressCallback) {
        GlobalScope.launch {
            try {
                callback.onProgress("initialization", 10, "Initializing report generation")
                delay(1000)

                callback.onProgress("data_collection", 30, "Collecting sales and inventory data")
                val data = collectData(reportId)
                delay(2000)

                callback.onProgress("processing", 60, "Processing and aggregating data")
                val processedData = processData(data)
                delay(2000)

                callback.onProgress("formatting", 80, "Formatting report and generating charts")
                val report = formatReport(processedData)
                delay(1000)

                callback.onProgress("saving", 95, "Saving report to storage")
                val url = saveReport(reportId, report)
                delay(500)

                callback.onComplete(url)
            } catch (e: Exception) {
                callback.onError(e.message ?: "Unknown error")
            }
        }
    }
}
```

#### 3.2 Frontend Integration

```typescript
// frontend/src/services/reportProgress.ts
class ReportProgressService {
    subscribe(
        reportId: string,
        callbacks: {
            onProgress?: (stage: string, percentage: number, message: string) => void;
            onComplete?: (downloadUrl: string) => void;
            onError?: (error: string) => void;
        }
    ) {
        const eventSource = new EventSource(`http://localhost:8083/api/reports/stream/${reportId}`);

        eventSource.addEventListener("progress", (event) => {
            const data = JSON.parse(event.data);
            callbacks.onProgress?.(data.stage, data.percentage, data.message);
        });

        eventSource.addEventListener("complete", (event) => {
            const data = JSON.parse(event.data);
            callbacks.onComplete?.(data.downloadUrl);
            eventSource.close();
        });

        eventSource.onerror = (error) => {
            callbacks.onError?.("Connection error");
            eventSource.close();
        };

        return () => eventSource.close();
    }
}
```

---

## 4. RabbitMQ - Task Queues & Work Distribution

### When to Use (Complementing Kafka)

-   **Command processing** with retry logic
-   **Task distribution** across workers
-   **Priority queues** for different task types
-   **Request-reply patterns** with correlation IDs

### ChiroERP Use Cases

#### 4.1 Order Processing & Invoice Task Queue

```kotlin
// services/financial-management/src/main/kotlin/com/chiroerp/financial/queue/InvoiceTaskQueue.kt
package com.chiroerp.financial.queue

import org.springframework.amqp.core.*
import org.springframework.amqp.rabbit.annotation.RabbitListener
import org.springframework.amqp.rabbit.core.RabbitTemplate
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.stereotype.Service

@Configuration
class RabbitMQConfig {

    // Queue for high-priority billing tasks
    @Bean
    fun billingHighPriorityQueue(): Queue {
        return QueueBuilder.durable("billing.tasks.high")
            .withArgument("x-max-priority", 10)
            .build()
    }

    // Queue for normal billing tasks
    @Bean
    fun billingNormalQueue(): Queue {
        return QueueBuilder.durable("billing.tasks.normal")
            .build()
    }

    // Dead letter queue for failed tasks
    @Bean
    fun billingDeadLetterQueue(): Queue {
        return QueueBuilder.durable("billing.tasks.dlq")
            .build()
    }

    @Bean
    fun billingExchange(): TopicExchange {
        return TopicExchange("billing.exchange")
    }

    @Bean
    fun highPriorityBinding(): Binding {
        return BindingBuilder
            .bind(billingHighPriorityQueue())
            .to(billingExchange())
            .with("billing.task.high")
    }

    @Bean
    fun normalBinding(): Binding {
        return BindingBuilder
            .bind(billingNormalQueue())
            .to(billingExchange())
            .with("billing.task.normal")
    }
}

data class InvoiceTask(
    val taskId: String,
    val customerId: String,
    val orderId: String? = null,
    val type: InvoiceTaskType,
    val priority: Int = 5,
    val data: Map<String, Any>,
    val retryCount: Int = 0
)

enum class InvoiceTaskType {
    GENERATE_INVOICE,
    PROCESS_PAYMENT,
    SEND_REMINDER,
    GENERATE_CREDIT_NOTE,
    CALCULATE_TAX,
    SEND_TO_ACCOUNTING_SYSTEM
}

@Service
class InvoiceTaskProducer(
    private val rabbitTemplate: RabbitTemplate
) {
    fun submitTask(task: InvoiceTask) {
        val routingKey = if (task.priority >= 8) {
            "invoice.task.high"
        } else {
            "invoice.task.normal"
        }

        rabbitTemplate.convertAndSend(
            "invoice.exchange",
            routingKey,
            task
        ) { message ->
            message.messageProperties.priority = task.priority
            message.messageProperties.expiration = "3600000" // 1 hour TTL
            message
        }
    }

    fun submitHighPriorityTask(task: InvoiceTask) {
        submitTask(task.copy(priority = 10))
    }
}

@Service
class InvoiceTaskConsumer(
    private val invoiceService: InvoiceService,
    private val paymentService: PaymentService,
    private val reminderService: ReminderService,
    private val creditNoteService: CreditNoteService,
    private val taxService: TaxService,
    private val accountingIntegrationService: AccountingIntegrationService,
    private val rabbitTemplate: RabbitTemplate
) {

    @RabbitListener(
        queues = ["invoice.tasks.high"],
        concurrency = "5-10" // Dynamic scaling
    )
    fun processHighPriorityTask(task: InvoiceTask) {
        processTask(task)
    }

    @RabbitListener(
        queues = ["invoice.tasks.normal"],
        concurrency = "3-7"
    )
    fun processNormalTask(task: InvoiceTask) {
        processTask(task)
    }

    private fun processTask(task: InvoiceTask) {
        try {
            when (task.type) {
                InvoiceTaskType.GENERATE_INVOICE -> {
                    invoiceService.generateInvoice(task.customerId, task.orderId, task.data)
                }
                InvoiceTaskType.PROCESS_PAYMENT -> {
                    paymentService.processPayment(task.customerId, task.data)
                }
                InvoiceTaskType.SEND_REMINDER -> {
                    reminderService.sendPaymentReminder(task.customerId, task.data)
                }
                InvoiceTaskType.GENERATE_CREDIT_NOTE -> {
                    creditNoteService.generateCreditNote(task.customerId, task.data)
                }
                InvoiceTaskType.CALCULATE_TAX -> {
                    taxService.calculateAndApplyTax(task.data)
                }
                InvoiceTaskType.SEND_TO_ACCOUNTING_SYSTEM -> {
                    accountingIntegrationService.syncInvoice(task.data)
                }
            }
        } catch (e: Exception) {
            handleTaskFailure(task, e)
        }
    }

    private fun handleTaskFailure(task: InvoiceTask, error: Exception) {
        if (task.retryCount < 3) {
            // Retry with exponential backoff
            val delayMs = (1000 * Math.pow(2.0, task.retryCount.toDouble())).toLong()
            Thread.sleep(delayMs)

            val retryTask = task.copy(retryCount = task.retryCount + 1)
            rabbitTemplate.convertAndSend("invoice.exchange", "invoice.task.normal", retryTask)
        } else {
            // Send to dead letter queue
            rabbitTemplate.convertAndSend("invoice.tasks.dlq", task)
        }
    }
}
```

---

## 5. Redis Pub/Sub - Fast Event Broadcasting

### When to Use (Complementing Kafka)

-   **Cache invalidation** across services
-   **Session synchronization** across instances
-   **Quick notifications** (ephemeral, no persistence needed)
-   **Service coordination** signals

### ChiroERP Use Cases

#### 5.1 Cache Invalidation Pattern

```kotlin
// services/shared-lib/src/main/kotlin/com/chiroerp/shared/cache/RedisCacheInvalidation.kt
package com.chiroerp.shared.cache

import org.springframework.data.redis.connection.Message
import org.springframework.data.redis.connection.MessageListener
import org.springframework.data.redis.core.RedisTemplate
import org.springframework.data.redis.listener.ChannelTopic
import org.springframework.data.redis.listener.RedisMessageListenerContainer
import org.springframework.stereotype.Service
import org.springframework.cache.CacheManager
import javax.annotation.PostConstruct

@Service
class CacheInvalidationPublisher(
    private val redisTemplate: RedisTemplate<String, String>
) {
    private val channel = "cache:invalidation"

    fun invalidateCache(cacheName: String, key: String? = null) {
        val message = if (key != null) {
            "$cacheName:$key"
        } else {
            "$cacheName:*" // Invalidate entire cache
        }

        redisTemplate.convertAndSend(channel, message)
    }

    fun invalidateCustomerCache(customerId: String) {
        invalidateCache("customers", customerId)
    }

    fun invalidateProductCache(productId: String) {
        invalidateCache("products", productId)
    }

    fun invalidateAllOrders() {
        invalidateCache("orders")
    }
}

@Service
class CacheInvalidationListener(
    private val cacheManager: CacheManager,
    private val redisMessageListenerContainer: RedisMessageListenerContainer
) : MessageListener {

    @PostConstruct
    fun init() {
        redisMessageListenerContainer.addMessageListener(
            this,
            ChannelTopic("cache:invalidation")
        )
    }

    override fun onMessage(message: Message, pattern: ByteArray?) {
        val invalidationMessage = String(message.body)
        val parts = invalidationMessage.split(":")

        when {
            parts.size == 2 && parts[1] == "*" -> {
                // Invalidate entire cache
                cacheManager.getCache(parts[0])?.clear()
            }
            parts.size == 2 -> {
                // Invalidate specific key
                cacheManager.getCache(parts[0])?.evict(parts[1])
            }
        }
    }
}

// Usage in Customer Service
@Service
class CustomerService(
    private val customerRepository: CustomerRepository,
    private val cacheInvalidationPublisher: CacheInvalidationPublisher
) {

    @Cacheable("customers", key = "#customerId")
    fun getCustomer(customerId: String): Customer {
        return customerRepository.findById(customerId)
            .orElseThrow { CustomerNotFoundException(customerId) }
    }

    fun updateCustomer(customerId: String, updates: CustomerUpdateDto): Customer {
        val customer = customerRepository.findById(customerId)
            .orElseThrow { CustomerNotFoundException(customerId) }

        // Update customer
        customer.apply {
            companyName = updates.companyName ?: companyName
            contactName = updates.contactName ?: contactName
            email = updates.email ?: email
            phone = updates.phone ?: phone
        }

        val saved = customerRepository.save(customer)

        // Broadcast cache invalidation to ALL instances across all service replicas
        cacheInvalidationPublisher.invalidateCustomerCache(customerId)

        return saved
    }
}
```

#### 5.2 Session Synchronization

```kotlin
// services/gateway-service/src/main/kotlin/com/chiroerp/gateway/session/SessionSync.kt
package com.chiroerp.gateway.session

import org.springframework.data.redis.core.RedisTemplate
import org.springframework.data.redis.listener.ChannelTopic
import org.springframework.stereotype.Service
import java.time.Instant

data class SessionEvent(
    val sessionId: String,
    val userId: String,
    val action: SessionAction,
    val timestamp: Instant = Instant.now()
)

enum class SessionAction {
    LOGIN, LOGOUT, REFRESH, REVOKE
}

@Service
class SessionSyncPublisher(
    private val redisTemplate: RedisTemplate<String, SessionEvent>
) {
    private val channel = "session:events"

    fun publishLogin(sessionId: String, userId: String) {
        publish(SessionEvent(sessionId, userId, SessionAction.LOGIN))
    }

    fun publishLogout(sessionId: String, userId: String) {
        publish(SessionEvent(sessionId, userId, SessionAction.LOGOUT))
    }

    fun publishRevoke(userId: String) {
        publish(SessionEvent("*", userId, SessionAction.REVOKE))
    }

    private fun publish(event: SessionEvent) {
        redisTemplate.convertAndSend(channel, event)
    }
}

@Service
class SessionSyncListener(
    private val sessionRegistry: SessionRegistry,
    private val redisMessageListenerContainer: RedisMessageListenerContainer
) : MessageListener {

    @PostConstruct
    fun init() {
        redisMessageListenerContainer.addMessageListener(
            this,
            ChannelTopic("session:events")
        )
    }

    override fun onMessage(message: Message, pattern: ByteArray?) {
        val event = objectMapper.readValue(message.body, SessionEvent::class.java)

        when (event.action) {
            SessionAction.LOGIN -> {
                sessionRegistry.registerSession(event.sessionId, event.userId)
            }
            SessionAction.LOGOUT -> {
                sessionRegistry.removeSession(event.sessionId)
            }
            SessionAction.REVOKE -> {
                // Revoke all sessions for user
                sessionRegistry.revokeUserSessions(event.userId)
            }
            SessionAction.REFRESH -> {
                sessionRegistry.refreshSession(event.sessionId)
            }
        }
    }
}
```

---

## 6. CQRS with Materialized Views (Database-Level)

### When to Use (Complementing All)

-   **Read-heavy patterns** with complex queries
-   **Pre-computed aggregations**
-   **Cross-aggregate reporting**
-   **Performance-critical reads**

### ChiroERP Use Cases

#### 6.1 Customer Sales Dashboard Materialized View

```kotlin
// services/customer-relationship/src/main/kotlin/com/chiroerp/customer/cqrs/CustomerSalesDashboardView.kt
package com.chiroerp.customer.cqrs

import javax.persistence.*
import org.hibernate.annotations.Immutable
import java.math.BigDecimal
import java.time.Instant

@Entity
@Immutable
@Table(name = "vw_customer_sales_dashboard")
data class CustomerSalesDashboardView(
    @Id
    val customerId: String,
    val companyName: String,
    val contactName: String,
    val email: String,
    val phone: String,
    val status: String,
    val customerType: String,

    // Aggregated order data
    val totalOrders: Int,
    val activeOrders: Int,
    val completedOrders: Int,
    val cancelledOrders: Int,
    val lastOrderDate: Instant?,
    val firstOrderDate: Instant?,

    // Financial data
    val totalSales: BigDecimal,
    val totalPaid: BigDecimal,
    val outstandingBalance: BigDecimal,
    val creditLimit: BigDecimal,
    val availableCredit: BigDecimal,
    val lastPaymentDate: Instant?,
    val averageOrderValue: BigDecimal,

    // Product preferences
    val topProductCategory: String?,
    val totalUniqueProducts: Int,

    // Engagement metrics
    val daysSinceLastOrder: Int?,
    val orderFrequency: String, // HIGH, MEDIUM, LOW

    @Column(name = "last_updated")
    val lastUpdated: Instant
)

// SQL Migration to create the view
// services/customer-relationship/src/main/resources/db/migration/V1.5__Create_Customer_Sales_Dashboard_View.sql
/*
CREATE MATERIALIZED VIEW vw_customer_sales_dashboard AS
SELECT
    c.id as customer_id,
    c.company_name,
    c.contact_name,
    c.email,
    c.phone,
    c.status,
    c.customer_type,

    -- Order aggregations
    COUNT(DISTINCT o.id) as total_orders,
    COUNT(DISTINCT CASE WHEN o.status = 'ACTIVE' THEN o.id END) as active_orders,
    COUNT(DISTINCT CASE WHEN o.status = 'COMPLETED' THEN o.id END) as completed_orders,
    COUNT(DISTINCT CASE WHEN o.status = 'CANCELLED' THEN o.id END) as cancelled_orders,
    MAX(o.order_date) as last_order_date,
    MIN(o.order_date) as first_order_date,

    -- Financial aggregations
    COALESCE(SUM(o.total_amount), 0) as total_sales,
    COALESCE(SUM(pay.amount), 0) as total_paid,
    COALESCE(SUM(o.total_amount), 0) - COALESCE(SUM(pay.amount), 0) as outstanding_balance,
    c.credit_limit,
    c.credit_limit - (COALESCE(SUM(o.total_amount), 0) - COALESCE(SUM(pay.amount), 0)) as available_credit,
    MAX(pay.payment_date) as last_payment_date,
    CASE
        WHEN COUNT(DISTINCT o.id) > 0
        THEN COALESCE(SUM(o.total_amount), 0) / COUNT(DISTINCT o.id)
        ELSE 0
    END as average_order_value,

    -- Product preferences
    (SELECT pc.name
     FROM order_lines ol
     JOIN products p ON ol.product_id = p.id
     JOIN product_categories pc ON p.category_id = pc.id
     WHERE ol.order_id IN (SELECT id FROM orders WHERE customer_id = c.id)
     GROUP BY pc.name
     ORDER BY COUNT(*) DESC
     LIMIT 1
    ) as top_product_category,

    COUNT(DISTINCT ol.product_id) as total_unique_products,

    -- Engagement metrics
    EXTRACT(DAY FROM (NOW() - MAX(o.order_date))) as days_since_last_order,
    CASE
        WHEN COUNT(DISTINCT o.id) >= 20 THEN 'HIGH'
        WHEN COUNT(DISTINCT o.id) >= 5 THEN 'MEDIUM'
        ELSE 'LOW'
    END as order_frequency,

    NOW() as last_updated
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
LEFT JOIN payments pay ON o.id = pay.order_id
LEFT JOIN order_lines ol ON o.id = ol.order_id
GROUP BY c.id, c.company_name, c.contact_name, c.email, c.phone, c.status, c.customer_type, c.credit_limit;

CREATE UNIQUE INDEX idx_customer_dashboard_pk ON vw_customer_sales_dashboard(customer_id);
CREATE INDEX idx_customer_dashboard_updated ON vw_customer_sales_dashboard(last_updated);
CREATE INDEX idx_customer_dashboard_balance ON vw_customer_sales_dashboard(outstanding_balance);
CREATE INDEX idx_customer_dashboard_last_order ON vw_customer_sales_dashboard(last_order_date);
*/

@Repository
interface CustomerSalesDashboardViewRepository : JpaRepository<CustomerSalesDashboardView, String> {
    fun findByCompanyNameContainingIgnoreCase(name: String): List<CustomerSalesDashboardView>
    fun findByOutstandingBalanceGreaterThan(amount: BigDecimal): List<CustomerSalesDashboardView>
    fun findByOrderFrequency(frequency: String): List<CustomerSalesDashboardView>
    fun findByDaysSinceLastOrderGreaterThan(days: Int): List<CustomerSalesDashboardView>
}

// Service to refresh the view
@Service
class CustomerSalesDashboardViewRefreshService(
    private val entityManager: EntityManager
) {

    // Refresh view when events occur
    @EventListener
    fun onCustomerUpdated(event: CustomerUpdatedEvent) {
        refreshForCustomer(event.customerId)
    }

    @EventListener
    fun onOrderCreated(event: OrderCreatedEvent) {
        refreshForCustomer(event.customerId)
    }

    @EventListener
    fun onPaymentReceived(event: PaymentReceivedEvent) {
        refreshForCustomer(event.customerId)
    }

    @Scheduled(cron = "0 0 * * * *") // Every hour
    fun refreshAll() {
        entityManager.createNativeQuery("REFRESH MATERIALIZED VIEW vw_customer_sales_dashboard")
            .executeUpdate()
    }

    fun refreshForCustomer(customerId: String) {
        // For PostgreSQL - refresh only specific customer
        entityManager.createNativeQuery(
            """
            REFRESH MATERIALIZED VIEW CONCURRENTLY vw_customer_sales_dashboard
            WHERE customer_id = :customerId
            """
        ).setParameter("customerId", customerId)
         .executeUpdate()
    }
}
```

---

## 7. Service Mesh (Envoy/Istio) - Infrastructure Communication

### When to Use (Complementing All)

-   **Service discovery** and load balancing
-   **Circuit breaking** and retry logic
-   **Traffic management** (canary, blue/green)
-   **Observability** (distributed tracing)

### ChiroERP Implementation

#### 7.1 Envoy Sidecar Configuration

```yaml
# services/patient-service/envoy.yaml
static_resources:
    listeners:
        - name: listener_0
          address:
              socket_address:
                  address: 0.0.0.0
                  port_value: 10000
          filter_chains:
              - filters:
                    - name: envoy.filters.network.http_connection_manager
                      typed_config:
                          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
                          stat_prefix: ingress_http
                          route_config:
                              name: local_route
                              virtual_hosts:
                                  - name: patient_service
                                    domains: ["*"]
                                    routes:
                                        - match:
                                              prefix: "/"
                                          route:
                                              cluster: patient_service
                                              retry_policy:
                                                  retry_on: "5xx"
                                                  num_retries: 3
                                                  per_try_timeout: 5s
                                              timeout: 30s
                          http_filters:
                              - name: envoy.filters.http.router

    clusters:
        - name: patient_service
          connect_timeout: 5s
          type: STRICT_DNS
          lb_policy: ROUND_ROBIN
          load_assignment:
              cluster_name: patient_service
              endpoints:
                  - lb_endpoints:
                        - endpoint:
                              address:
                                  socket_address:
                                      address: patient-service
                                      port_value: 8081
          health_checks:
              - timeout: 1s
                interval: 10s
                unhealthy_threshold: 2
                healthy_threshold: 2
                http_health_check:
                    path: "/actuator/health"
          circuit_breakers:
              thresholds:
                  - priority: DEFAULT
                    max_connections: 1000
                    max_pending_requests: 1000
                    max_requests: 1000
                    max_retries: 3
          outlier_detection:
              consecutive_5xx: 5
              interval: 30s
              base_ejection_time: 30s
              max_ejection_percent: 50
```

---

## 8. Implementation Roadmap

### Phase 1: Quick Wins (Week 1-2)

1. ✅ **Redis Pub/Sub** for cache invalidation
2. ✅ **SSE** for report progress tracking
3. ✅ **Materialized Views** for dashboard queries

### Phase 2: Performance Optimization (Week 3-4)

1. ✅ **gRPC** for high-frequency service-to-service calls
2. ✅ **RabbitMQ** for task distribution
3. ✅ **WebSockets** for real-time dashboards

### Phase 3: Infrastructure (Week 5-6)

1. ✅ **Service Mesh** (Envoy) for traffic management
2. ✅ **Circuit breakers** and retry policies
3. ✅ **Distributed tracing** setup

---

## 9. Integration Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        API Gateway                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │   REST   │  │ GraphQL  │  │WebSocket │  │   SSE    │       │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘       │
└─────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌───────────────┐     ┌───────────────┐     ┌───────────────┐
│   Customer    │────▶│  Financial    │────▶│  Reporting    │
│   Service     │ gRPC│  Management   │ gRPC│   Service     │
└───────────────┘     └───────────────┘     └───────────────┘
        │                     │                     │
        │    ┌────────────────┴──────────────┐     │
        │    │                                │     │
        ▼    ▼                                ▼     ▼
┌─────────────────────────────────────────────────────────┐
│                      Kafka (Events)                     │
│  - Domain Events (eventual consistency)                 │
│  - Audit Logs                                           │
│  - Cross-aggregate changes                              │
└─────────────────────────────────────────────────────────┘
        │                                           │
        ▼                                           ▼
┌─────────────────┐                         ┌──────────────┐
│  RabbitMQ       │                         │ Redis Pub/Sub│
│  - Task Queues  │                         │ - Cache Inv. │
│  - Commands     │                         │ - Session    │
│  - Priority     │                         │ - Signals    │
└─────────────────┘                         └──────────────┘
        │                                           │
        └───────────────────┬───────────────────────┘
                            │
                            ▼
                ┌───────────────────────┐
                │  Service Mesh (Envoy) │
                │  - Load Balancing     │
                │  - Circuit Breaking   │
                │  - Retry Logic        │
                │  - Tracing            │
                └───────────────────────┘
```

---

## 10. When to Use What

### Decision Matrix

| Scenario                     | Primary            | Secondary        | Tertiary        |
| ---------------------------- | ------------------ | ---------------- | --------------- |
| **Client-to-Service**        | REST/GraphQL       | WebSocket (live) | SSE (push)      |
| **Service-to-Service Sync**  | gRPC               | REST             | -               |
| **Service-to-Service Async** | Kafka              | RabbitMQ         | -               |
| **Command Processing**       | RabbitMQ           | Kafka            | -               |
| **Event Broadcasting**       | Kafka              | Redis Pub/Sub    | -               |
| **Cache Invalidation**       | Redis Pub/Sub      | -                | -               |
| **Real-time Updates**        | WebSocket          | SSE              | Kafka + Polling |
| **Long Operations**          | SSE                | WebSocket        | Polling         |
| **Read Optimization**        | Materialized Views | Caching          | -               |
| **Infrastructure**           | Service Mesh       | -                | -               |

---

## 11. Benefits Summary

### Performance Gains

-   **gRPC**: 10-50x faster than REST for internal calls
-   **Redis Pub/Sub**: Sub-millisecond cache invalidation
-   **Materialized Views**: 100x faster complex queries
-   **WebSockets**: Real-time updates without polling overhead

### Reliability Improvements

-   **RabbitMQ**: Guaranteed delivery with retries
-   **Service Mesh**: Automatic circuit breaking and retries
-   **Task Queues**: Priority handling for critical operations

### Developer Experience

-   **gRPC**: Strong typing and code generation
-   **SSE**: Simple server push without WebSocket complexity
-   **Materialized Views**: SQL-based, familiar to developers

---

## 12. Monitoring & Observability

### Metrics to Track

```kotlin
// services/shared-lib/src/main/kotlin/com/chiroerp/shared/metrics/CommunicationMetrics.kt
package com.chiroerp.shared.metrics

import io.micrometer.core.instrument.MeterRegistry
import io.micrometer.core.instrument.Timer
import org.springframework.stereotype.Component

@Component
class CommunicationMetrics(private val registry: MeterRegistry) {

    // gRPC metrics
    fun recordGrpcCall(service: String, method: String, duration: Long, success: Boolean) {
        Timer.builder("grpc.call.duration")
            .tag("service", service)
            .tag("method", method)
            .tag("success", success.toString())
            .register(registry)
            .record(duration, TimeUnit.MILLISECONDS)
    }

    // WebSocket metrics
    fun recordActiveWebSocketConnections(count: Int) {
        registry.gauge("websocket.connections.active", count)
    }

    // RabbitMQ metrics
    fun recordQueueSize(queueName: String, size: Int) {
        registry.gauge("rabbitmq.queue.size", Tags.of("queue", queueName), size)
    }

    // Redis Pub/Sub metrics
    fun recordCacheInvalidation(cacheName: String) {
        registry.counter("redis.cache.invalidation", "cache", cacheName).increment()
    }

    // Materialized view refresh metrics
    fun recordViewRefresh(viewName: String, duration: Long) {
        Timer.builder("materialized.view.refresh")
            .tag("view", viewName)
            .register(registry)
            .record(duration, TimeUnit.MILLISECONDS)
    }
}
```

---

## Next Steps

1. **Review** this guide and identify which patterns solve your current pain points
2. **Prioritize** based on the roadmap (quick wins first)
3. **Implement** one pattern at a time
4. **Measure** the impact using the metrics framework
5. **Iterate** and expand to other services

Would you like me to help implement any of these patterns in your ChiroERP system?
