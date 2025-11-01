package com.chiro.erp.commerce.resource

import com.chiro.erp.commerce.entity.Product
import com.chiro.erp.commerce.repository.ProductRepository
import io.smallrye.mutiny.Uni
import jakarta.inject.Inject
import jakarta.ws.rs.*
import jakarta.ws.rs.core.MediaType
import jakarta.ws.rs.core.Response
import java.time.LocalDateTime

@Path("/api/commerce")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
class CommerceResource {
    @Inject
    lateinit var productRepository: ProductRepository

    @GET
    @Path("/products")
    fun getAllProducts(): Uni<List<Product>> {
        return productRepository.findActiveProducts()
    }

    @GET
    @Path("/products/category/{category}")
    fun getProductsByCategory(
        @PathParam("category") category: String,
    ): Uni<List<Product>> {
        return productRepository.findByCategory(category)
    }

    @GET
    @Path("/products/search")
    fun searchProducts(
        @QueryParam("name") name: String,
    ): Uni<List<Product>> {
        return if (name.isBlank()) {
            productRepository.findActiveProducts()
        } else {
            productRepository.searchByName(name)
        }
    }

    @POST
    @Path("/products")
    fun createProduct(request: CreateProductRequest): Uni<Response> {
        val product =
            Product().apply {
                name = request.name
                description = request.description
                price = request.price
                stockQuantity = request.stockQuantity
                category = request.category
                sku = request.sku
                isActive = true
                createdAt = LocalDateTime.now()
            }

        return productRepository.persistAndFlush(product)
            .onItem().transform {
                Response.status(Response.Status.CREATED).entity(product).build()
            }
    }

    @PUT
    @Path("/products/{id}/stock")
    fun updateProductStock(
        @PathParam("id") id: Long,
        request: UpdateStockRequest,
    ): Uni<Response> {
        return productRepository.updateStock(id, request.quantity)
            .onItem().transform { product ->
                if (product != null) {
                    Response.ok(product).build()
                } else {
                    Response.status(Response.Status.NOT_FOUND).build()
                }
            }
    }

    @GET
    @Path("/health/database")
    fun checkDatabaseConnection(): Uni<Response> {
        return productRepository.count()
            .onItem().transform { count ->
                val healthCheck =
                    mapOf(
                        "status" to "UP",
                        "database" to "postgresql",
                        "total_products" to count,
                        "timestamp" to LocalDateTime.now(),
                    )
                Response.ok(healthCheck).build()
            }
            .onFailure().recoverWithItem { throwable ->
                val errorCheck =
                    mapOf(
                        "status" to "DOWN",
                        "database" to "postgresql",
                        "error" to throwable.message,
                        "timestamp" to LocalDateTime.now(),
                    )
                Response.status(Response.Status.SERVICE_UNAVAILABLE).entity(errorCheck).build()
            }
    }
}

data class CreateProductRequest(
    val name: String,
    val description: String?,
    val price: java.math.BigDecimal,
    val stockQuantity: Int,
    val category: String,
    val sku: String,
)

data class UpdateStockRequest(
    val quantity: Int,
)
