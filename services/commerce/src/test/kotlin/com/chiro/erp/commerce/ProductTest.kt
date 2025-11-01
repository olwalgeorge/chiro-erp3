package com.chiro.erp.commerce

import com.chiro.erp.commerce.entity.Product
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.*
import java.math.BigDecimal
import java.time.LocalDateTime

class ProductTest {
    
    @Test
    fun testProductCreation() {
        val product = Product().apply {
            name = "Test Product"
            description = "A test product"
            price = BigDecimal("19.99")
            stockQuantity = 100
            category = "Electronics"
            sku = "TEST-001"
            isActive = true
            createdAt = LocalDateTime.now()
        }
        
        assertNotNull(product)
        assertEquals("Test Product", product.name)
        assertEquals(BigDecimal("19.99"), product.price)
        assertEquals(100, product.stockQuantity)
        assertEquals("Electronics", product.category)
        assertEquals("TEST-001", product.sku)
        assertTrue(product.isActive)
        
        println("✅ Product creation test passed!")
    }
    
    @Test
    fun testProductValidation() {
        val product = Product()
        product.name = "Laptop"
        product.price = BigDecimal("999.99")
        product.stockQuantity = 50
        product.category = "Electronics"
        product.sku = "LAPTOP-001"
        product.isActive = true
        product.createdAt = LocalDateTime.now()
        
        // Validate required fields are set
        assertNotNull(product.name)
        assertTrue(product.price > BigDecimal.ZERO)
        assertTrue(product.stockQuantity >= 0)
        assertNotNull(product.category)
        assertNotNull(product.sku)
        assertTrue(product.isActive)
        assertNull(product.updatedAt) // Should be null initially
        
        println("✅ Product validation test passed!")
    }
}
