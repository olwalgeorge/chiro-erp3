package com.chiro.erp.operationsservice.shared.health

import jakarta.enterprise.context.ApplicationScoped
import org.eclipse.microprofile.health.HealthCheck
import org.eclipse.microprofile.health.HealthCheckResponse
import org.eclipse.microprofile.health.Liveness
import org.eclipse.microprofile.health.Readiness

@Liveness
@ApplicationScoped
class LivenessCheck : HealthCheck {
    override fun call(): HealthCheckResponse {
        return HealthCheckResponse.named("Operations Service Liveness Check")
                .withData("service", "operations-service")
                .withData("status", "UP")
                .up()
                .build()
    }
}

@Readiness
@ApplicationScoped
class ReadinessCheck : HealthCheck {
    override fun call(): HealthCheckResponse {
        return HealthCheckResponse.named("Operations Service Readiness Check")
                .withData("service", "operations-service")
                .withData("status", "READY")
                .up()
                .build()
    }
}
