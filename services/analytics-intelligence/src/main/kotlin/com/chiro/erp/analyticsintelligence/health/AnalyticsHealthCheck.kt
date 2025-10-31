package com.chiro.erp.analyticsintelligence.health

import org.eclipse.microprofile.health.HealthCheck
import org.eclipse.microprofile.health.HealthCheckResponse
import org.eclipse.microprofile.health.Liveness
import jakarta.enterprise.context.ApplicationScoped

@Liveness
@ApplicationScoped
class AnalyticsHealthCheck : HealthCheck {
    
    override fun call(): HealthCheckResponse {
        return HealthCheckResponse.named("Analytics Intelligence Service")
            .up()
            .withData("service", "analytics-intelligence")
            .withData("status", "running")
            .build()
    }
}
