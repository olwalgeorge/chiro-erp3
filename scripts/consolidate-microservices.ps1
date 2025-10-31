#!/usr/bin/env pwsh

# Microservice Consolidation Script
# Consolidates 30+ microservices into 8 multimodal domain-focused services

param(
    [switch]$WhatIf = $false,
    [switch]$Force = $false
)

$ErrorActionPreference = "Stop"

Write-Host "🔄 Microservice Consolidation: 30+ → 8 Multimodal Services" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

if ($WhatIf) {
    Write-Host "⚠️  DRY RUN MODE - No actual changes will be made" -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Yellow
}

# Function to create directory structure
function New-DirectoryStructure {
    param([string]$Path, [string]$Description)
    
    if ($WhatIf) {
        Write-Host "Would create: $Path ($Description)" -ForegroundColor Yellow
    } else {
        if (!(Test-Path $Path)) {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
            Write-Host "📁 Created: $Path" -ForegroundColor Green
        } else {
            Write-Host "📁 Exists: $Path" -ForegroundColor Gray
        }
    }
}

# Function to create consolidated service structure
function New-ConsolidatedService {
    param(
        [string]$ServiceName,
        [string]$BasePackage,
        [string[]]$ConsolidatedServices,
        [string]$Description
    )
    
    Write-Host "`n🏗️  Creating: $ServiceName" -ForegroundColor Magenta
    Write-Host "    Consolidating: $($ConsolidatedServices -join ', ')" -ForegroundColor Gray
    
    $servicePath = "consolidated-services/$ServiceName"
    $packagePath = "src/main/kotlin/$($BasePackage.Replace('.', '/'))"
    
    # Root service structure
    New-DirectoryStructure $servicePath $Description
    New-DirectoryStructure "$servicePath/src/main/docker" "Docker configurations"
    New-DirectoryStructure "$servicePath/src/main/resources" "Application resources"
    New-DirectoryStructure "$servicePath/src/main/resources/db/migration" "Database migrations"
    New-DirectoryStructure "$servicePath/src/test/kotlin" "Unit tests"
    New-DirectoryStructure "$servicePath/src/integration-test/kotlin" "Integration tests"
    
    # Main package structure
    New-DirectoryStructure "$servicePath/$packagePath" "Main service package"
    
    # Application layer (Hexagonal Architecture)
    New-DirectoryStructure "$servicePath/$packagePath/application/port/inbound" "Inbound ports (API interfaces)"
    New-DirectoryStructure "$servicePath/$packagePath/application/port/outbound" "Outbound ports (Repository interfaces)"
    New-DirectoryStructure "$servicePath/$packagePath/application/service" "Application services"
    New-DirectoryStructure "$servicePath/$packagePath/application/usecase" "Use cases"
    New-DirectoryStructure "$servicePath/$packagePath/application/dto" "Data transfer objects"
    
    # Domain layer
    New-DirectoryStructure "$servicePath/$packagePath/domain/model" "Domain entities and aggregates"
    New-DirectoryStructure "$servicePath/$packagePath/domain/event" "Domain events"
    New-DirectoryStructure "$servicePath/$packagePath/domain/service" "Domain services"
    New-DirectoryStructure "$servicePath/$packagePath/domain/repository" "Repository interfaces"
    New-DirectoryStructure "$servicePath/$packagePath/domain/valueobject" "Value objects"
    
    # Infrastructure layer
    New-DirectoryStructure "$servicePath/$packagePath/infrastructure/adapter/web" "REST controllers"
    New-DirectoryStructure "$servicePath/$packagePath/infrastructure/adapter/messaging/kafka" "Kafka consumers/producers"
    New-DirectoryStructure "$servicePath/$packagePath/infrastructure/adapter/persistence/jpa" "JPA entities and repositories"
    New-DirectoryStructure "$servicePath/$packagePath/infrastructure/adapter/external" "External service adapters"
    New-DirectoryStructure "$servicePath/$packagePath/infrastructure/config" "Configuration classes"
    
    # Create domain modules for each consolidated service
    foreach ($consolidatedService in $ConsolidatedServices) {
        $moduleName = $consolidatedService -replace "service-", ""
        $modulePath = "$servicePath/$packagePath/domain/modules/$moduleName"
        
        New-DirectoryStructure "$modulePath/model" "Domain models for $moduleName"
        New-DirectoryStructure "$modulePath/service" "Domain services for $moduleName"
        New-DirectoryStructure "$modulePath/event" "Domain events for $moduleName"
        New-DirectoryStructure "$modulePath/repository" "Repository interfaces for $moduleName"
    }
}

# Define consolidated service configurations
$consolidatedServices = @{
    "core-platform" = @{
        Package = "com.chiro.erp.platform.core"
        Services = @("service-identity-access", "service-organization-master")
        Description = "Core Platform: Identity & Organization Management"
    }
    "customer-relationship" = @{
        Package = "com.chiro.erp.crm"
        Services = @("service-crm", "service-client-management", "service-provider-management", "service-subscriptions", "service-retail-promotions")
        Description = "Customer Relationship Management: CRM, Sales, Marketing & Subscriptions"
    }
    "operations-service" = @{
        Package = "com.chiro.erp.operations"
        Services = @("service-field-service-management", "service-resource-scheduling", "service-records-management", "service-repair-rma")
        Description = "Operations & Service Management: Field Service, Scheduling & Records"
    }
    "ecommerce-experience" = @{
        Package = "com.chiro.erp.ecommerce"
        Services = @("service-ecomm-storefront", "service-customer-portal", "service-communication-portal")
        Description = "E-commerce & Customer Experience: Digital Channels"
    }
    "financial-management" = @{
        Package = "com.chiro.erp.finance"
        Services = @("service-billing-invoicing", "service-ap-automation")
        Description = "Financial Management: Billing, Invoicing & AP Automation"
    }
    "supply-chain-manufacturing" = @{
        Package = "com.chiro.erp.manufacturing"
        Services = @("service-mrp-production", "service-quality-management", "service-inventory-management")
        Description = "Supply Chain & Manufacturing: Production, Quality & Inventory"
    }
    "logistics-transportation" = @{
        Package = "com.chiro.erp.logistics"
        Services = @("service-fleet-management", "service-tms", "service-wms-advanced")
        Description = "Logistics & Transportation: Fleet, Warehouse & Transport Management"
    }
    "analytics-intelligence" = @{
        Package = "com.chiro.erp.analytics"
        Services = @("service-analytics-data-products", "service-ai-ml", "service-reporting-analytics")
        Description = "Analytics & Intelligence: Data, AI/ML & Reporting"
    }
}

# Create consolidated services directory
Write-Host "`n📦 Creating consolidated services structure..." -ForegroundColor Blue
New-DirectoryStructure "consolidated-services" "Root directory for consolidated multimodal services"

# Create each consolidated service
foreach ($service in $consolidatedServices.GetEnumerator()) {
    New-ConsolidatedService -ServiceName $service.Key -BasePackage $service.Value.Package -ConsolidatedServices $service.Value.Services -Description $service.Value.Description
}

# Create shared libraries for consolidated services
Write-Host "`n📚 Creating shared libraries for consolidated services..." -ForegroundColor Blue

$sharedLibs = @{
    "platform-common" = @{
        Package = "com.chiro.erp.platform.common"
        Description = "Common platform utilities and models"
    }
    "domain-events" = @{
        Package = "com.chiro.erp.events"
        Description = "Shared domain events and messaging contracts"
    }
    "integration-contracts" = @{
        Package = "com.chiro.erp.integration"
        Description = "API contracts and integration models"
    }
    "security-common" = @{
        Package = "com.chiro.erp.security"
        Description = "Shared security components and utilities"
    }
}

New-DirectoryStructure "consolidated-libs" "Shared libraries for consolidated services"

foreach ($lib in $sharedLibs.GetEnumerator()) {
    $libPath = "consolidated-libs/$($lib.Key)"
    $packagePath = "src/main/kotlin/$($lib.Value.Package.Replace('.', '/'))"
    
    New-DirectoryStructure $libPath $lib.Value.Description
    New-DirectoryStructure "$libPath/$packagePath" "Main library package"
    New-DirectoryStructure "$libPath/src/main/resources" "Library resources"
    New-DirectoryStructure "$libPath/src/test/kotlin" "Library tests"
}

# Create new build configuration
Write-Host "`n🔧 Creating consolidated build configuration..." -ForegroundColor Blue

$consolidatedSettingsGradle = @"
pluginManagement {
    repositories {
        mavenCentral()
        gradlePluginPortal()
        mavenLocal()
    }
}

rootProject.name = "chiro-erp-consolidated"

// Shared libraries
include(":consolidated-libs:platform-common")
include(":consolidated-libs:domain-events")
include(":consolidated-libs:integration-contracts")
include(":consolidated-libs:security-common")

// Consolidated multimodal services (8 services instead of 30+)
include(":consolidated-services:core-platform")
include(":consolidated-services:customer-relationship")
include(":consolidated-services:operations-service")
include(":consolidated-services:ecommerce-experience")
include(":consolidated-services:financial-management")
include(":consolidated-services:supply-chain-manufacturing")
include(":consolidated-services:logistics-transportation")
include(":consolidated-services:analytics-intelligence")
"@

if ($WhatIf) {
    Write-Host "Would create: consolidated-settings.gradle.kts" -ForegroundColor Yellow
} else {
    Set-Content -Path "consolidated-settings.gradle.kts" -Value $consolidatedSettingsGradle -Encoding UTF8
    Write-Host "📝 Created: consolidated-settings.gradle.kts" -ForegroundColor Green
}

# Create migration mapping file
$migrationMapping = @"
# Migration Mapping: Original Services → Consolidated Services

## 1. Core Platform Service
- service-identity-access → consolidated-services/core-platform/domain/modules/identity
- service-organization-master → consolidated-services/core-platform/domain/modules/organization

## 2. Customer Relationship Management Service  
- service-crm → consolidated-services/customer-relationship/domain/modules/crm
- service-client-management → consolidated-services/customer-relationship/domain/modules/client-management
- service-provider-management → consolidated-services/customer-relationship/domain/modules/provider-management
- service-subscriptions → consolidated-services/customer-relationship/domain/modules/subscriptions
- service-retail-promotions → consolidated-services/customer-relationship/domain/modules/retail-promotions

## 3. Operations & Service Management Service
- service-field-service-management → consolidated-services/operations-service/domain/modules/field-service-management
- service-resource-scheduling → consolidated-services/operations-service/domain/modules/resource-scheduling
- service-records-management → consolidated-services/operations-service/domain/modules/records-management
- service-repair-rma → consolidated-services/operations-service/domain/modules/repair-rma

## 4. E-commerce & Customer Experience Service
- service-ecomm-storefront → consolidated-services/ecommerce-experience/domain/modules/ecomm-storefront
- service-customer-portal → consolidated-services/ecommerce-experience/domain/modules/customer-portal
- service-communication-portal → consolidated-services/ecommerce-experience/domain/modules/communication-portal

## 5. Financial Management Service
- service-billing-invoicing → consolidated-services/financial-management/domain/modules/billing-invoicing
- service-ap-automation → consolidated-services/financial-management/domain/modules/ap-automation

## 6. Supply Chain & Manufacturing Service
- service-mrp-production → consolidated-services/supply-chain-manufacturing/domain/modules/mrp-production
- service-quality-management → consolidated-services/supply-chain-manufacturing/domain/modules/quality-management
- service-inventory-management → consolidated-services/supply-chain-manufacturing/domain/modules/inventory-management

## 7. Logistics & Transportation Service
- service-fleet-management → consolidated-services/logistics-transportation/domain/modules/fleet-management
- service-tms → consolidated-services/logistics-transportation/domain/modules/tms
- service-wms-advanced → consolidated-services/logistics-transportation/domain/modules/wms-advanced

## 8. Analytics & Intelligence Service
- service-analytics-data-products → consolidated-services/analytics-intelligence/domain/modules/analytics-data-products
- service-ai-ml → consolidated-services/analytics-intelligence/domain/modules/ai-ml
- service-reporting-analytics → consolidated-services/analytics-intelligence/domain/modules/reporting-analytics

## Migration Benefits
- ✅ **Reduced from 30+ to 8 deployable services**
- ✅ **Maintained domain boundaries within each service**
- ✅ **Improved business capability cohesion**
- ✅ **Simplified operational overhead**
- ✅ **Better transaction and data consistency**
"@

if ($WhatIf) {
    Write-Host "Would create: service-migration-mapping.md" -ForegroundColor Yellow
} else {
    Set-Content -Path "service-migration-mapping.md" -Value $migrationMapping -Encoding UTF8
    Write-Host "📝 Created: service-migration-mapping.md" -ForegroundColor Green
}

# Summary
Write-Host "`n✅ Consolidation Structure Created!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host "📊 **Consolidation Results:**" -ForegroundColor White
Write-Host "   • Original Services: 30+" -ForegroundColor Gray
Write-Host "   • Consolidated Services: 8" -ForegroundColor Gray  
Write-Host "   • Deployment Reduction: ~75%" -ForegroundColor Gray
Write-Host "" -ForegroundColor White
Write-Host "🏗️  **Created Consolidated Services:**" -ForegroundColor White
Write-Host "   1. Core Platform (Identity + Organization)" -ForegroundColor Gray
Write-Host "   2. Customer Relationship Management (CRM + Sales + Marketing)" -ForegroundColor Gray
Write-Host "   3. Operations & Service Management (Field Service + Scheduling)" -ForegroundColor Gray
Write-Host "   4. E-commerce & Customer Experience (Digital Channels)" -ForegroundColor Gray
Write-Host "   5. Financial Management (Billing + AP Automation)" -ForegroundColor Gray
Write-Host "   6. Supply Chain & Manufacturing (Production + Quality + Inventory)" -ForegroundColor Gray
Write-Host "   7. Logistics & Transportation (Fleet + Warehouse + Transport)" -ForegroundColor Gray
Write-Host "   8. Analytics & Intelligence (Data + AI/ML + Reporting)" -ForegroundColor Gray
Write-Host "" -ForegroundColor White
Write-Host "📚 **Shared Libraries:** 4 common libraries created" -ForegroundColor White
Write-Host "📝 **Migration Guide:** service-migration-mapping.md" -ForegroundColor White
Write-Host "⚙️  **Build Config:** consolidated-settings.gradle.kts" -ForegroundColor White

if ($WhatIf) {
    Write-Host "`n⚠️  This was a DRY RUN - no actual changes were made" -ForegroundColor Yellow
    Write-Host "Run without -WhatIf parameter to create the structure" -ForegroundColor Yellow
} else {
    Write-Host "`n🚀 **Next Steps:**" -ForegroundColor Cyan
    Write-Host "   1. Review the consolidation plan: microservice-consolidation-plan.md" -ForegroundColor White
    Write-Host "   2. Check migration mapping: service-migration-mapping.md" -ForegroundColor White
    Write-Host "   3. Start migrating code from original services to consolidated modules" -ForegroundColor White
    Write-Host "   4. Update CI/CD pipelines for 8 services instead of 30+" -ForegroundColor White
    Write-Host "   5. Test consolidated services incrementally" -ForegroundColor White
}
