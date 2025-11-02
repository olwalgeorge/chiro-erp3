package com.chiro.erp.commerce.shared.health

import jakarta.enterprise.context.ApplicationScoped
import org.eclipse.microprofile.health.HealthCheck
import org.eclipse.microprofile.health.HealthCheckResponse
import org.eclipse.microprofile.health.Liveness
import org.eclipse.microprofile.health.Readiness

@Liveness
@ApplicationScoped
class LivenessCheck : HealthCheck {
    override fun call(): HealthCheckResponse {
        return HealthCheckResponse.named("Commerce Liveness Check")
                .withData("service", "commerce")
                .withData("status", "UP")
                .up()
                .build()
    }
}

@Readiness
@ApplicationScoped
class ReadinessCheck : HealthCheck {
    override fun call(): HealthCheckResponse {
        return HealthCheckResponse.named("Commerce Readiness Check")
                .withData("service", "commerce")
                .withData("status", "READY")
                .up()
                .build()
    }
}
