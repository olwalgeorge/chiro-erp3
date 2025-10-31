#!/usr/bin/env pwsh

# Script to create complete hexagonal architecture structure for all consolidated services
# This script creates placeholder directories and files for all domains

Write-Host "🏗️  Creating Complete Consolidated Services Structure..." -ForegroundColor Green

# Define the consolidated services and their domains
$services = @{
    "core-platform" = @("security", "organization", "audit", "configuration", "notification", "integration")
    "customer-relationship" = @("crm", "client", "provider", "subscription", "promotion")  
    "operations-service" = @("field-service", "scheduling", "records", "repair-rma")
    "commerce" = @("ecommerce", "portal", "communication", "pos")
    "financial-management" = @("general-ledger", "accounts-payable", "accounts-receivable", "asset-accounting", "tax-engine", "expense-management")
    "supply-chain-manufacturing" = @("production", "quality", "inventory", "product-costing", "procurement")
    "logistics-transportation" = @("fleet", "tms", "wms")
    "analytics-intelligence" = @("data-products", "ai-ml", "reporting")
}

# Domain to original service mapping for documentation
$domainMapping = @{
    # Core Platform (Enterprise Security & Resilience)
    "security" = "service-security-framework"
    "organization" = "service-organization-master"
    "audit" = "service-audit-logging"
    "configuration" = "service-configuration-management"
    "notification" = "service-notification-engine"
    "integration" = "service-integration-platform"
    
    # Customer Relationship
    "crm" = "service-crm"
    "client" = "service-client-management" 
    "provider" = "service-provider-management"
    "subscription" = "service-subscriptions"
    "promotion" = "service-retail-promotions"
    
    # Operations Service
    "field-service" = "service-field-service-management"
    "scheduling" = "service-resource-scheduling"
    "records" = "service-records-management"
    "repair-rma" = "service-repair-rma"
    
    # Commerce
    "ecommerce" = "service-ecomm-storefront"
    "portal" = "service-customer-portal"
    "communication" = "service-communication-portal"
    "pos" = "service-point-of-sale"
    
    # Financial Management (SAP FI Module Structure)
    "general-ledger" = "service-accounting-core"
    "accounts-payable" = "service-ap-automation"  
    "accounts-receivable" = "service-billing-invoicing"
    "asset-accounting" = "service-asset-management"
    "tax-engine" = "service-tax-compliance"
    "expense-management" = "service-expense-reports"
    
    # Supply Chain Manufacturing
    "production" = "service-mrp-production"
    "quality" = "service-quality-management"
    "inventory" = "service-inventory-management"
    "product-costing" = "service-cost-accounting"
    "procurement" = "service-procurement-management"
    
    # Logistics Transportation
    "fleet" = "service-fleet-management"
    "tms" = "service-tms"
    "wms" = "service-wms-advanced"
    
    # Analytics Intelligence
    "data-products" = "service-analytics-data-products"
    "ai-ml" = "service-ai-ml"
    "reporting" = "service-reporting-analytics"
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
    
    Write-Host "  ✅ Created $DomainName domain in $ServiceName service" -ForegroundColor Green
}

# Create structure for each service and domain
foreach ($service in $services.Keys) {
    Write-Host "🚀 Creating $service service structure..." -ForegroundColor Cyan
    
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
Write-Host "  • 8 consolidated services created"
Write-Host "  • 36 domain structures created" 
Write-Host "  • Complete hexagonal architecture for each domain"
Write-Host "  • Enterprise-grade Core Platform with Comprehensive Security"
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
