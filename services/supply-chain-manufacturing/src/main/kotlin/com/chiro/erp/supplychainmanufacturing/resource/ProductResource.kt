package com.chiro.erp.supplychainmanufacturing.resource

import com.chiro.erp.supplychainmanufacturing.entity.Product
import com.chiro.erp.supplychainmanufacturing.entity.ProductCategory
import com.chiro.erp.supplychainmanufacturing.entity.ProductStatus
import com.chiro.erp.supplychainmanufacturing.repository.ProductRepository
import io.quarkus.hibernate.reactive.panache.common.WithTransaction
import io.smallrye.mutiny.Uni
import jakarta.inject.Inject
import jakarta.ws.rs.*
import jakarta.ws.rs.core.MediaType
import jakarta.ws.rs.core.Response
import java.time.LocalDateTime

@Path("/api/products")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
class ProductResource {
    @Inject
    lateinit var productRepository: ProductRepository

    @GET
    fun getAllProducts(): Uni<List<Product>> = productRepository.listAll()

    @GET
    @Path("/{id}")
    fun getProduct(
        @PathParam("id") id: Long,
    ): Uni<Response> {
        return productRepository.findById(id)
            .onItem().transform { product ->
                if (product != null) {
                    Response.ok(product).build()
                } else {
                    Response.status(Response.Status.NOT_FOUND).build()
                }
            }
    }

    @GET
    @Path("/sku/{sku}")
    fun getProductBySku(
        @PathParam("sku") sku: String,
    ): Uni<Response> {
        return productRepository.findBySku(sku)
            .onItem().transform { product ->
                if (product != null) {
                    Response.ok(product).build()
                } else {
                    Response.status(Response.Status.NOT_FOUND).build()
                }
            }
    }

    @GET
    @Path("/category/{category}")
    fun getProductsByCategory(
        @PathParam("category") category: ProductCategory,
    ): Uni<List<Product>> = productRepository.findByCategory(category)

    @GET
    @Path("/status/{status}")
    fun getProductsByStatus(
        @PathParam("status") status: ProductStatus,
    ): Uni<List<Product>> = productRepository.findByStatus(status)

    @GET
    @Path("/supplier/{supplierId}")
    fun getProductsBySupplier(
        @PathParam("supplierId") supplierId: String,
    ): Uni<List<Product>> = productRepository.findBySupplierId(supplierId)

    @GET
    @Path("/low-stock")
    fun getLowStockProducts(): Uni<List<Product>> = productRepository.findLowStockProducts()

    @GET
    @Path("/out-of-stock")
    fun getOutOfStockProducts(): Uni<List<Product>> = productRepository.findOutOfStockProducts()

    @GET
    @Path("/active")
    fun getActiveProducts(): Uni<List<Product>> = productRepository.findActiveProducts()

    @POST
    @WithTransaction
    fun createProduct(product: Product): Uni<Response> {
        product.createdAt = LocalDateTime.now()
        product.updatedAt = LocalDateTime.now()
        return productRepository.persist(product)
            .onItem().transform { Response.status(Response.Status.CREATED).entity(it).build() }
    }

    @PUT
    @Path("/{id}")
    @WithTransaction
    fun updateProduct(
        @PathParam("id") id: Long,
        product: Product,
    ): Uni<Response> {
        return productRepository.findById(id)
            .onItem().transformToUni { existingProduct ->
                if (existingProduct != null) {
                    existingProduct.name = product.name
                    existingProduct.description = product.description
                    existingProduct.category = product.category
                    existingProduct.unitPrice = product.unitPrice
                    existingProduct.stockQuantity = product.stockQuantity
                    existingProduct.minimumStock = product.minimumStock
                    existingProduct.status = product.status
                    existingProduct.supplierId = product.supplierId
                    existingProduct.manufacturingCost = product.manufacturingCost
                    existingProduct.leadTimeDays = product.leadTimeDays
                    existingProduct.updatedAt = LocalDateTime.now()
                    productRepository.persist(existingProduct)
                        .onItem().transform { Response.ok(it).build() }
                } else {
                    Uni.createFrom().item(Response.status(Response.Status.NOT_FOUND).build())
                }
            }
    }

    @DELETE
    @Path("/{id}")
    @WithTransaction
    fun deleteProduct(
        @PathParam("id") id: Long,
    ): Uni<Response> {
        return productRepository.deleteById(id)
            .onItem().transform { deleted ->
                if (deleted) {
                    Response.noContent().build()
                } else {
                    Response.status(Response.Status.NOT_FOUND).build()
                }
            }
    }

    @GET
    @Path("/search")
    fun searchProducts(
        @QueryParam("name") name: String?,
    ): Uni<List<Product>> {
        return if (!name.isNullOrBlank()) {
            productRepository.searchByName(name)
        } else {
            productRepository.listAll()
        }
    }
}
