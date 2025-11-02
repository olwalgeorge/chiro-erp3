-- PostgreSQL Initialization Script
-- Initialize single database with schemas for all microservices
-- This provides logical separation while using one physical database
-- NOTE: This script uses PostgreSQL-specific syntax and is NOT compatible with MSSQL

-- Keycloak still needs its own database
CREATE DATABASE keycloak;

-- Create users for each consolidated service
CREATE USER core_user WITH PASSWORD 'core_pass';
CREATE USER administration_user WITH PASSWORD 'administration_pass';
CREATE USER customerrelationship_user WITH PASSWORD 'customerrelationship_pass';
CREATE USER operationsservice_user WITH PASSWORD 'operationsservice_pass';
CREATE USER commerce_user WITH PASSWORD 'commerce_pass';
CREATE USER financialmanagement_user WITH PASSWORD 'financialmanagement_pass';
CREATE USER supplychainmanufacturing_user WITH PASSWORD 'supplychainmanufacturing_pass';

-- Grant connection to main database for all users
GRANT CONNECT ON DATABASE chiro_erp TO core_user;
GRANT CONNECT ON DATABASE chiro_erp TO administration_user;
GRANT CONNECT ON DATABASE chiro_erp TO customerrelationship_user;
GRANT CONNECT ON DATABASE chiro_erp TO operationsservice_user;
GRANT CONNECT ON DATABASE chiro_erp TO commerce_user;
GRANT CONNECT ON DATABASE chiro_erp TO financialmanagement_user;
GRANT CONNECT ON DATABASE chiro_erp TO supplychainmanufacturing_user;

-- Create schemas for each consolidated service (must run after connecting to chiro_erp)
\c chiro_erp

-- Core Platform: security, organization, audit, configuration, notification, integration
CREATE SCHEMA IF NOT EXISTS core_schema AUTHORIZATION core_user;

-- Administration: hr, logistics-transportation, analytics-intelligence, project-management
CREATE SCHEMA IF NOT EXISTS administration_schema AUTHORIZATION administration_user;

-- Customer Relationship: crm, client, provider, subscription, promotion
CREATE SCHEMA IF NOT EXISTS customerrelationship_schema AUTHORIZATION customerrelationship_user;

-- Operations Service: field-service, scheduling, records, repair-rma
CREATE SCHEMA IF NOT EXISTS operationsservice_schema AUTHORIZATION operationsservice_user;

-- Commerce: ecommerce, portal, communication, pos
CREATE SCHEMA IF NOT EXISTS commerce_schema AUTHORIZATION commerce_user;

-- Financial Management: general-ledger, accounts-payable, accounts-receivable, asset-accounting, tax-engine, expense-management
CREATE SCHEMA IF NOT EXISTS financialmanagement_schema AUTHORIZATION financialmanagement_user;

-- Supply Chain Manufacturing: production, quality, inventory, product-costing, procurement
CREATE SCHEMA IF NOT EXISTS supplychainmanufacturing_schema AUTHORIZATION supplychainmanufacturing_user;

-- Grant full privileges on schemas
GRANT ALL PRIVILEGES ON SCHEMA core_schema TO core_user;
GRANT ALL PRIVILEGES ON SCHEMA administration_schema TO administration_user;
GRANT ALL PRIVILEGES ON SCHEMA customerrelationship_schema TO customerrelationship_user;
GRANT ALL PRIVILEGES ON SCHEMA operationsservice_schema TO operationsservice_user;
GRANT ALL PRIVILEGES ON SCHEMA commerce_schema TO commerce_user;
GRANT ALL PRIVILEGES ON SCHEMA financialmanagement_schema TO financialmanagement_user;
GRANT ALL PRIVILEGES ON SCHEMA supplychainmanufacturing_schema TO supplychainmanufacturing_user;

-- Grant usage and create on schemas
GRANT USAGE ON SCHEMA core_schema TO core_user;
GRANT USAGE ON SCHEMA administration_schema TO administration_user;
GRANT USAGE ON SCHEMA customerrelationship_schema TO customerrelationship_user;
GRANT USAGE ON SCHEMA operationsservice_schema TO operationsservice_user;
GRANT USAGE ON SCHEMA commerce_schema TO commerce_user;
GRANT USAGE ON SCHEMA financialmanagement_schema TO financialmanagement_user;
GRANT USAGE ON SCHEMA supplychainmanufacturing_schema TO supplychainmanufacturing_user;

-- Set default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA core_schema GRANT ALL ON TABLES TO core_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA administration_schema GRANT ALL ON TABLES TO administration_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA customerrelationship_schema GRANT ALL ON TABLES TO customerrelationship_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA operationsservice_schema GRANT ALL ON TABLES TO operationsservice_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA commerce_schema GRANT ALL ON TABLES TO commerce_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA financialmanagement_schema GRANT ALL ON TABLES TO financialmanagement_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA supplychainmanufacturing_schema GRANT ALL ON TABLES TO supplychainmanufacturing_user;

-- Set default privileges for sequences
ALTER DEFAULT PRIVILEGES IN SCHEMA core_schema GRANT ALL ON SEQUENCES TO core_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA administration_schema GRANT ALL ON SEQUENCES TO administration_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA customerrelationship_schema GRANT ALL ON SEQUENCES TO customerrelationship_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA operationsservice_schema GRANT ALL ON SEQUENCES TO operationsservice_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA commerce_schema GRANT ALL ON SEQUENCES TO commerce_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA financialmanagement_schema GRANT ALL ON SEQUENCES TO financialmanagement_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA supplychainmanufacturing_schema GRANT ALL ON SEQUENCES TO supplychainmanufacturing_user;
