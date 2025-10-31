package com.chiro.erp.analyticsintelligence.resource

import jakarta.ws.rs.*
import jakarta.ws.rs.core.MediaType
import jakarta.ws.rs.core.Response
import java.time.LocalDateTime

@Path("/status")
@Produces(MediaType.APPLICATION_JSON)
class StatusResource {
    
    @GET
    fun getStatus(): Response {
        val status = mapOf(
            "service" to "analytics-intelligence",
            "status" to "UP",
            "timestamp" to LocalDateTime.now(),
            "version" to "1.0.0-SNAPSHOT",
            "message" to "Analytics Intelligence Service is running"
        )
        return Response.ok(status).build()
    }
    
    @GET
    @Path("/health")
    fun getHealth(): Response {
        val health = mapOf(
            "status" to "UP",
            "checks" to listOf(
                mapOf(
                    "name" to "service",
                    "status" to "UP"
                )
            )
        )
        return Response.ok(health).build()
    }
}
