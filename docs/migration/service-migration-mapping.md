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
