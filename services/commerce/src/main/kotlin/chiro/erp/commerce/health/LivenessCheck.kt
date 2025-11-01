package chiro.erp.commerce.health

import jakarta.enterprise.context.ApplicationScoped
import org.eclipse.microprofile.health.HealthCheck
import org.eclipse.microprofile.health.HealthCheckResponse
import org.eclipse.microprofile.health.Liveness

@Liveness
@ApplicationScoped
class LivenessCheck : HealthCheck {

    override fun call(): HealthCheckResponse {
        return HealthCheckResponse.builder()
                .name("Commerce service liveness check")
                .status(true)
                .withData("service", "commerce")
                .withData("version", "1.0.0-SNAPSHOT")
                .build()
    }
}
