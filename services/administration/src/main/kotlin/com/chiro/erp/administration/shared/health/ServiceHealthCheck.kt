package com.chiro.erp.administration.shared.health

import jakarta.enterprise.context.ApplicationScoped
import org.eclipse.microprofile.health.HealthCheck
import org.eclipse.microprofile.health.HealthCheckResponse
import org.eclipse.microprofile.health.Liveness
import org.eclipse.microprofile.health.Readiness

@Liveness
@ApplicationScoped
class LivenessCheck : HealthCheck {
    override fun call(): HealthCheckResponse {
        return HealthCheckResponse.named("Administration Liveness Check")
                .withData("service", "administration")
                .withData("status", "UP")
                .up()
                .build()
    }
}

@Readiness
@ApplicationScoped
class ReadinessCheck : HealthCheck {
    override fun call(): HealthCheckResponse {
        return HealthCheckResponse.named("Administration Readiness Check")
                .withData("service", "administration")
                .withData("status", "READY")
                .up()
                .build()
    }
}
