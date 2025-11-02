#!/usr/bin/env pwsh

# Script to create complete hexagonal architecture structure for all consolidated services
# This script creates placeholder directories and files for all domains

Write-Host "🏗️  Creating Complete Consolidated Services Structure..." -ForegroundColor Green

# Define the consolidated services and their domains
$services = @{
    "core-platform"              = @("security", "organization", "audit", "configuration", "notification", "integration")
    "administration"             = @("hr", "logistics-transportation", "analytics-intelligence", "project-management")
    "customer-relationship"      = @("crm", "client", "provider", "subscription", "promotion")
    "operations-service"         = @("field-service", "scheduling", "records", "repair-rma")
    "commerce"                   = @("ecommerce", "portal", "communication", "pos")
    "financial-management"       = @("general-ledger", "accounts-payable", "accounts-receivable", "asset-accounting", "tax-engine", "expense-management")
    "supply-chain-manufacturing" = @("production", "quality", "inventory", "product-costing", "procurement")
}

# Domain to original service mapping for documentation
$domainMapping = @{
    # Core Platform (Enterprise Security & Resilience)
    "security"                 = "service-security-framework"
    "organization"             = "service-organization-master"
    "audit"                    = "service-audit-logging"
    "configuration"            = "service-configuration-management"
    "notification"             = "service-notification-engine"
    "integration"              = "service-integration-platform"

    # Administration
    "hr"                       = "service-hr-management"
    "logistics-transportation" = "service-logistics-transportation"
    "analytics-intelligence"   = "service-analytics-intelligence"
    "project-management"       = "service-project-management"

    # Customer Relationship
    "crm"                      = "service-crm"
    "client"                   = "service-client-management"
    "provider"                 = "service-provider-management"
    "subscription"             = "service-subscriptions"
    "promotion"                = "service-retail-promotions"

    # Operations Service
    "field-service"            = "service-field-service-management"
    "scheduling"               = "service-resource-scheduling"
    "records"                  = "service-records-management"
    "repair-rma"               = "service-repair-rma"

    # Commerce
    "ecommerce"                = "service-ecomm-storefront"
    "portal"                   = "service-customer-portal"
    "communication"            = "service-communication-portal"
    "pos"                      = "service-point-of-sale"

    # Financial Management (SAP FI Module Structure)
    "general-ledger"           = "service-accounting-core"
    "accounts-payable"         = "service-ap-automation"
    "accounts-receivable"      = "service-billing-invoicing"
    "asset-accounting"         = "service-asset-management"
    "tax-engine"               = "service-tax-compliance"
    "expense-management"       = "service-expense-reports"

    # Supply Chain Manufacturing
    "production"               = "service-mrp-production"
    "quality"                  = "service-quality-management"
    "inventory"                = "service-inventory-management"
    "product-costing"          = "service-cost-accounting"
    "procurement"              = "service-procurement-management"
}

function Create-HexagonalStructure {
    param(
        [string]$ServiceName,
        [string]$DomainName,
        [string]$OriginalService
    )

    $servicePackage = $ServiceName -replace "-", ""
    $domainPackage = $DomainName -replace "-", ""

    # Base paths
    $basePath = "services/$ServiceName/src/main/kotlin/com/chiro/erp/$servicePackage/$DomainName"
    $testPath = "services/$ServiceName/src/test/kotlin/com/chiro/erp/$servicePackage/$DomainName"

    # Create directory structure
    $directories = @(
        # Main source directories
        "$basePath/domain/models",
        "$basePath/domain/services",
        "$basePath/domain/ports/inbound",
        "$basePath/domain/ports/outbound",
        "$basePath/application",
        "$basePath/infrastructure/persistence",
        "$basePath/infrastructure/messaging",
        "$basePath/infrastructure/external",
        "$basePath/interfaces/rest",
        "$basePath/interfaces/graphql",
        "$basePath/interfaces/events",

        # Test directories
        "$testPath/domain",
        "$testPath/application",
        "$testPath/infrastructure",
        "$testPath/interfaces"
    )

    foreach ($dir in $directories) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    # Placeholder files creation disabled - directories only
    # To enable placeholder files, uncomment the sections below

    <#
    # Create placeholder files
    $packagePrefix = "com.chiro.erp.$servicePackage.$domainPackage"

    # Domain models placeholder
    $modelsContent = @"
package $packagePrefix.domain.models

// $DomainName Domain Models Placeholder
// This will contain the migrated models from $OriginalService

// TODO: Migrate entity classes from archived service:
// - Copy domain entities from archived-original-structure/$OriginalService/src/main/kotlin/
// - Update package references
// - Ensure proper JPA annotations for consolidated database schema
"@

    $modelsContent | Out-File -FilePath "$basePath/domain/models/PlaceholderModels.kt" -Encoding UTF8

    # Use case placeholder
    $useCaseContent = @"
package $packagePrefix.domain.ports.inbound

// $DomainName Use Cases (Inbound Ports) Placeholder
// This will contain the use case interfaces from $OriginalService

// TODO: Define use cases that this domain provides:
// - Analyze business operations from original service
// - Create use case interfaces (commands, queries)
// - Define DTOs for use case parameters and results
"@

    $useCaseContent | Out-File -FilePath "$basePath/domain/ports/inbound/PlaceholderUseCases.kt" -Encoding UTF8

    # Repository placeholder
    $repoContent = @"
package $packagePrefix.domain.ports.outbound

// $DomainName Repositories (Outbound Ports) Placeholder
// This will contain the repository interfaces from $OriginalService

// TODO: Define repository interfaces for domain entities:
// - Create repository interfaces for each aggregate root
// - Define query methods based on use cases
// - Use suspend functions for reactive operations
"@

    $repoContent | Out-File -FilePath "$basePath/domain/ports/outbound/PlaceholderRepositories.kt" -Encoding UTF8

    # Application service placeholder
    $appServiceContent = @"
package $packagePrefix.application

// $DomainName Application Services Placeholder
// This will contain the use case implementations from $OriginalService

// TODO: Implement use cases by creating application services:
// - Implement inbound ports (use cases)
// - Orchestrate domain services and repositories
// - Handle cross-cutting concerns (transactions, events)
"@

    $appServiceContent | Out-File -FilePath "$basePath/application/PlaceholderApplicationServices.kt" -Encoding UTF8

    # REST controller placeholder
    $controllerContent = @"
package $packagePrefix.interfaces.rest

// $DomainName REST Controllers Placeholder
// This will contain the REST APIs from $OriginalService

// TODO: Create REST controllers:
// - Migrate REST endpoints from original service
// - Create DTOs for request/response objects
// - Wire to application services (use cases)
// - Add proper error handling and validation
"@

    $controllerContent | Out-File -FilePath "$basePath/interfaces/rest/PlaceholderControllers.kt" -Encoding UTF8
    #>

    Write-Host "  ✅ Created $DomainName domain structure in $ServiceName service" -ForegroundColor Green
}

function Create-ServiceFiles {
    param(
        [string]$ServiceName,
        [int]$Port
    )

    $servicePackage = $ServiceName -replace "-", ""
    $serviceClass = (Get-Culture).TextInfo.ToTitleCase(($ServiceName -replace "-", " ")) -replace " ", ""

    # Create Application main class
    $appPath = "services/$ServiceName/src/main/kotlin/com/chiro/erp/$servicePackage"
    New-Item -ItemType Directory -Path $appPath -Force | Out-Null

    $appContent = @"
package com.chiro.erp.$servicePackage

import io.quarkus.runtime.Quarkus
import io.quarkus.runtime.QuarkusApplication
import io.quarkus.runtime.annotations.QuarkusMain

@QuarkusMain
class ${serviceClass}Application : QuarkusApplication {
    override fun run(vararg args: String?): Int {
        Quarkus.waitForExit()
        return 0
    }
}

fun main(args: Array<String>) {
    Quarkus.run(${serviceClass}Application::class.java, *args)
}
"@

    $appContent | Out-File -FilePath "$appPath/${serviceClass}Application.kt" -Encoding UTF8

    # Create build.gradle
    $buildGradleContent = @"
plugins {
    id 'org.jetbrains.kotlin.jvm' version "2.2.20"
    id "org.jetbrains.kotlin.plugin.allopen" version "2.2.20"
    id 'org.jetbrains.kotlin.plugin.serialization' version "2.2.20"
    id 'io.quarkus'
}

repositories {
    mavenCentral()
    mavenLocal()
}

dependencies {
    // Core Quarkus dependencies only
    implementation 'io.quarkus:quarkus-rest'
    implementation 'io.quarkus:quarkus-rest-jackson'
    implementation 'org.jetbrains.kotlin:kotlin-stdlib-jdk8'

    // Essential extensions
    implementation 'io.quarkus:quarkus-smallrye-health'

    // Database dependencies (only active in prod)
    implementation 'io.quarkus:quarkus-hibernate-reactive-panache-kotlin'
    implementation 'io.quarkus:quarkus-reactive-pg-client'

    testImplementation 'io.quarkus:quarkus-junit5'
}

group = 'chiro.erp.$servicePackage'
version = '1.0.0-SNAPSHOT'

java {
    sourceCompatibility = JavaVersion.VERSION_21
    targetCompatibility = JavaVersion.VERSION_21
}

test {
    systemProperty "java.util.logging.manager", "org.jboss.logmanager.LogManager"
    jvmArgs "--add-opens", "java.base/java.lang=ALL-UNNAMED"
}

allOpen {
    annotation("jakarta.ws.rs.Path")
    annotation("jakarta.enterprise.context.ApplicationScoped")
    annotation("jakarta.persistence.Entity")
    annotation("io.quarkus.test.junit.QuarkusTest")
}

compileKotlin {
    kotlinOptions.jvmTarget = JavaVersion.VERSION_21
    kotlinOptions.javaParameters = true
}

compileTestKotlin {
    kotlinOptions.jvmTarget = JavaVersion.VERSION_21
    kotlinOptions.javaParameters = true
}
"@

    $buildGradleContent | Out-File -FilePath "services/$ServiceName/build.gradle" -Encoding UTF8

    # Create application.properties
    $schema = $servicePackage -replace "service", "" -replace "platform", "core"
    $resourcesPath = "services/$ServiceName/src/main/resources"
    New-Item -ItemType Directory -Path $resourcesPath -Force | Out-Null

    $appPropertiesContent = @"
# $serviceClass Service Configuration
quarkus.application.name=$ServiceName-service
quarkus.http.port=$Port

# Database Configuration - Single database with schema separation
quarkus.datasource.db-kind=postgresql
quarkus.datasource.username=`${DB_USERNAME:${schema}_user}
quarkus.datasource.password=`${DB_PASSWORD:${schema}_pass}
quarkus.datasource.reactive.url=`${DB_URL:postgresql://localhost:5432/chiro_erp?currentSchema=${schema}_schema}

# Hibernate Reactive Configuration
quarkus.hibernate-orm.database.generation=update
quarkus.hibernate-orm.log.sql=true
quarkus.hibernate-orm.database.default-schema=${schema}_schema
quarkus.hibernate-orm.packages=com.chiro.erp.$servicePackage

# Development Configuration - disable database completely
%dev.quarkus.hibernate-orm.active=false
%dev.quarkus.datasource.active=false

# Health Check Configuration
quarkus.smallrye-health.ui.always-include=true

# Test Configuration - disable database for tests
%test.quarkus.hibernate-orm.active=false
%test.quarkus.datasource.active=false

# Redis Configuration
quarkus.redis.hosts=`${REDIS_URL:redis://localhost:6379}

# Kafka Configuration
kafka.bootstrap.servers=`${KAFKA_BOOTSTRAP_SERVERS:localhost:9092}

# Security Configuration
quarkus.oidc.auth-server-url=`${OIDC_SERVER_URL:http://localhost:8080/realms/chiro-erp}
quarkus.oidc.client-id=$ServiceName-service
quarkus.oidc.credentials.secret=`${OIDC_CLIENT_SECRET:${ServiceName}-secret}

# API Documentation
quarkus.swagger-ui.always-include=true
quarkus.swagger-ui.path=/$servicePackage/swagger-ui
"@

    $appPropertiesContent | Out-File -FilePath "$resourcesPath/application.properties" -Encoding UTF8

    Write-Host "  ✅ Created Application class, build.gradle, and application.properties for $ServiceName" -ForegroundColor Green
}

# Port assignments for services
$servicePorts = @{
    "core-platform"              = 8081
    "administration"             = 8082
    "customer-relationship"      = 8083
    "operations-service"         = 8084
    "commerce"                   = 8085
    "financial-management"       = 8086
    "supply-chain-manufacturing" = 8087
}

# Create structure for each service and domain
foreach ($service in $services.Keys) {
    Write-Host "🚀 Creating $service service structure..." -ForegroundColor Cyan

    # Create service files (Application, build.gradle, application.properties)
    Create-ServiceFiles -ServiceName $service -Port $servicePorts[$service]

    foreach ($domain in $services[$service]) {
        $originalService = $domainMapping[$domain]
        Create-HexagonalStructure -ServiceName $service -DomainName $domain -OriginalService $originalService
    }

    # Create shared directory
    $sharedPath = "services/$service/src/main/kotlin/com/chiro/erp/$($service -replace '-', '')/shared"
    New-Item -ItemType Directory -Path "$sharedPath/config" -Force | Out-Null
    New-Item -ItemType Directory -Path "$sharedPath/exceptions" -Force | Out-Null
    New-Item -ItemType Directory -Path "$sharedPath/utils" -Force | Out-Null

    Write-Host "  ✅ Created shared utilities for $service" -ForegroundColor Green
}

Write-Host ""
Write-Host "🎉 Complete consolidated services structure created!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Summary:" -ForegroundColor Yellow
Write-Host "  • 7 consolidated services created"
Write-Host "  • 36 domain structures created"
Write-Host "  • Complete hexagonal architecture for each domain"
Write-Host "  • Application main classes for all services"
Write-Host "  • build.gradle files with Quarkus & Kotlin configuration"
Write-Host "  • application.properties with database, Kafka, Redis & security setup"
Write-Host "  • Port assignments: 8081-8087"
Write-Host "  • Enterprise-grade Core Platform with Comprehensive Security"
Write-Host "  • Administration service with HR, Logistics & Analytics"
Write-Host "  • SAP FI-aligned Financial Management structure"
Write-Host "  • SAP MM-aligned Supply Chain with Procurement & Manufacturing"
Write-Host "  • SAP CO-aligned Product Costing integration"
Write-Host "  • Complete Commerce platform with POS and E-commerce"
Write-Host "  • All 30+ original microservices mapped to domains"
Write-Host ""
Write-Host "🚀 Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Review COMPLETE-STRUCTURE-TEMPLATE.md for migration guide"
Write-Host "  2. Start with core-platform/identity domain migration"
Write-Host "  3. Copy entity classes from archived-original-structure/"
Write-Host "  4. Implement use cases following hexagonal architecture"
Write-Host "  5. Add infrastructure adapters and REST APIs"
Write-Host ""
