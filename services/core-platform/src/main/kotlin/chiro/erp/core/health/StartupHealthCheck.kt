package chiro.erp.core.health

import jakarta.enterprise.context.ApplicationScoped
import org.eclipse.microprofile.health.HealthCheck
import org.eclipse.microprofile.health.HealthCheckResponse
import org.eclipse.microprofile.health.Startup

@Startup
@ApplicationScoped
class StartupHealthCheck : HealthCheck {

    override fun call(): HealthCheckResponse {
        return HealthCheckResponse.builder()
                .name("Core Platform startup check")
                .status(true)
                .withData("service", "core-platform")
                .withData("version", "1.0.0-SNAPSHOT")
                .build()
    }
}
