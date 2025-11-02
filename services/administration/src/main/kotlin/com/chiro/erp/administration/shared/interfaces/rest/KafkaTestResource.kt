package com.chiro.erp.administration.shared.interfaces.rest

import com.chiro.erp.administration.shared.messaging.AdministrationEventProducer
import jakarta.inject.Inject
import jakarta.ws.rs.GET
import jakarta.ws.rs.Path
import jakarta.ws.rs.Produces
import jakarta.ws.rs.QueryParam
import jakarta.ws.rs.core.MediaType
import jakarta.ws.rs.core.Response

@Path("/api/test/kafka")
@Produces(MediaType.APPLICATION_JSON)
class KafkaTestResource {

    @Inject lateinit var eventProducer: AdministrationEventProducer

    @GET
    @Path("/send")
    fun sendTestMessage(@QueryParam("message") message: String?): Response {
        val testMessage = message ?: "Test message from Administration"

        eventProducer.publishEvent(eventType = "TEST_EVENT", payload = testMessage)

        return Response.ok(
                        mapOf(
                                "status" to "success",
                                "message" to "Event published successfully",
                                "payload" to testMessage
                        )
                )
                .build()
    }

    @GET
    @Path("/ping")
    fun ping(): Response {
        return Response.ok(
                        mapOf(
                                "service" to "administration",
                                "status" to "active",
                                "kafka" to "ready"
                        )
                )
                .build()
    }
}
