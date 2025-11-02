package com.chiro.erp.supplychainmanufacturing.shared.health

import jakarta.enterprise.context.ApplicationScoped
import org.eclipse.microprofile.health.HealthCheck
import org.eclipse.microprofile.health.HealthCheckResponse
import org.eclipse.microprofile.health.Liveness
import org.eclipse.microprofile.health.Readiness

@Liveness
@ApplicationScoped
class LivenessCheck : HealthCheck {
    override fun call(): HealthCheckResponse {
        return HealthCheckResponse.named("Supply Chain Manufacturing Liveness Check")
                .withData("service", "supply-chain-manufacturing")
                .withData("status", "UP")
                .up()
                .build()
    }
}

@Readiness
@ApplicationScoped
class ReadinessCheck : HealthCheck {
    override fun call(): HealthCheckResponse {
        return HealthCheckResponse.named("Supply Chain Manufacturing Readiness Check")
                .withData("service", "supply-chain-manufacturing")
                .withData("status", "READY")
                .up()
                .build()
    }
}
