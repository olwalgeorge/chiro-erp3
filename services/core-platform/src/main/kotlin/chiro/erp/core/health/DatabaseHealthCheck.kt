package chiro.erp.core.health

import io.vertx.mutiny.sqlclient.Pool
import jakarta.enterprise.context.ApplicationScoped
import jakarta.inject.Inject
import org.eclipse.microprofile.health.HealthCheck
import org.eclipse.microprofile.health.HealthCheckResponse
import org.eclipse.microprofile.health.Readiness

@Readiness
@ApplicationScoped
class DatabaseHealthCheck : HealthCheck {

    @Inject lateinit var pool: Pool

    override fun call(): HealthCheckResponse {
        return try {
            // Simple query to check database connectivity
            pool.query("SELECT 1").execute().await().indefinitely()

            HealthCheckResponse.builder()
                    .name("Database connection health check")
                    .status(true)
                    .withData("database", "core_db")
                    .withData("status", "UP")
                    .build()
        } catch (e: Exception) {
            HealthCheckResponse.builder()
                    .name("Database connection health check")
                    .status(false)
                    .withData("database", "core_db")
                    .withData("status", "DOWN")
                    .withData("error", e.message ?: "Unknown error")
                    .build()
        }
    }
}
