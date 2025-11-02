package com.chiro.erp.financialmanagement.shared.health

import jakarta.enterprise.context.ApplicationScoped
import org.eclipse.microprofile.health.HealthCheck
import org.eclipse.microprofile.health.HealthCheckResponse
import org.eclipse.microprofile.health.Liveness
import org.eclipse.microprofile.health.Readiness

@Liveness
@ApplicationScoped
class LivenessCheck : HealthCheck {
    override fun call(): HealthCheckResponse {
        return HealthCheckResponse.named("Financial Management Liveness Check")
                .withData("service", "financial-management")
                .withData("status", "UP")
                .up()
                .build()
    }
}

@Readiness
@ApplicationScoped
class ReadinessCheck : HealthCheck {
    override fun call(): HealthCheckResponse {
        return HealthCheckResponse.named("Financial Management Readiness Check")
                .withData("service", "financial-management")
                .withData("status", "READY")
                .up()
                .build()
    }
}
