-- PostgreSQL Initialization Script
-- Initialize single database with schemas for all microservices
-- This provides logical separation while using one physical database
-- NOTE: This script uses PostgreSQL-specific syntax and is NOT compatible with MSSQL

-- Keycloak still needs its own database
CREATE DATABASE keycloak;

-- Create users for each service
CREATE USER core_user WITH PASSWORD 'core_pass';
CREATE USER analytics_user WITH PASSWORD 'analytics_pass';
CREATE USER commerce_user WITH PASSWORD 'commerce_pass';
CREATE USER crm_user WITH PASSWORD 'crm_pass';
CREATE USER finance_user WITH PASSWORD 'finance_pass';
CREATE USER logistics_user WITH PASSWORD 'logistics_pass';
CREATE USER operations_user WITH PASSWORD 'operations_pass';
CREATE USER supply_user WITH PASSWORD 'supply_pass';

-- Grant connection to main database for all users
GRANT CONNECT ON DATABASE chiro_erp TO core_user;
GRANT CONNECT ON DATABASE chiro_erp TO analytics_user;
GRANT CONNECT ON DATABASE chiro_erp TO commerce_user;
GRANT CONNECT ON DATABASE chiro_erp TO crm_user;
GRANT CONNECT ON DATABASE chiro_erp TO finance_user;
GRANT CONNECT ON DATABASE chiro_erp TO logistics_user;
GRANT CONNECT ON DATABASE chiro_erp TO operations_user;
GRANT CONNECT ON DATABASE chiro_erp TO supply_user;

-- Create schemas for each service (must run after connecting to chiro_erp)
\c chiro_erp

CREATE SCHEMA IF NOT EXISTS core_schema AUTHORIZATION core_user;
CREATE SCHEMA IF NOT EXISTS analytics_schema AUTHORIZATION analytics_user;
CREATE SCHEMA IF NOT EXISTS commerce_schema AUTHORIZATION commerce_user;
CREATE SCHEMA IF NOT EXISTS crm_schema AUTHORIZATION crm_user;
CREATE SCHEMA IF NOT EXISTS finance_schema AUTHORIZATION finance_user;
CREATE SCHEMA IF NOT EXISTS logistics_schema AUTHORIZATION logistics_user;
CREATE SCHEMA IF NOT EXISTS operations_schema AUTHORIZATION operations_user;
CREATE SCHEMA IF NOT EXISTS supply_schema AUTHORIZATION supply_user;

-- Grant full privileges on schemas
GRANT ALL PRIVILEGES ON SCHEMA core_schema TO core_user;
GRANT ALL PRIVILEGES ON SCHEMA analytics_schema TO analytics_user;
GRANT ALL PRIVILEGES ON SCHEMA commerce_schema TO commerce_user;
GRANT ALL PRIVILEGES ON SCHEMA crm_schema TO crm_user;
GRANT ALL PRIVILEGES ON SCHEMA finance_schema TO finance_user;
GRANT ALL PRIVILEGES ON SCHEMA logistics_schema TO logistics_user;
GRANT ALL PRIVILEGES ON SCHEMA operations_schema TO operations_user;
GRANT ALL PRIVILEGES ON SCHEMA supply_schema TO supply_user;

-- Grant usage and create on schemas
GRANT USAGE ON SCHEMA core_schema TO core_user;
GRANT USAGE ON SCHEMA analytics_schema TO analytics_user;
GRANT USAGE ON SCHEMA commerce_schema TO commerce_user;
GRANT USAGE ON SCHEMA crm_schema TO crm_user;
GRANT USAGE ON SCHEMA finance_schema TO finance_user;
GRANT USAGE ON SCHEMA logistics_schema TO logistics_user;
GRANT USAGE ON SCHEMA operations_schema TO operations_user;
GRANT USAGE ON SCHEMA supply_schema TO supply_user;

-- Set default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA core_schema GRANT ALL ON TABLES TO core_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA analytics_schema GRANT ALL ON TABLES TO analytics_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA commerce_schema GRANT ALL ON TABLES TO commerce_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA crm_schema GRANT ALL ON TABLES TO crm_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA finance_schema GRANT ALL ON TABLES TO finance_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA logistics_schema GRANT ALL ON TABLES TO logistics_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA operations_schema GRANT ALL ON TABLES TO operations_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA supply_schema GRANT ALL ON TABLES TO supply_user;

-- Set default privileges for sequences
ALTER DEFAULT PRIVILEGES IN SCHEMA core_schema GRANT ALL ON SEQUENCES TO core_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA analytics_schema GRANT ALL ON SEQUENCES TO analytics_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA commerce_schema GRANT ALL ON SEQUENCES TO commerce_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA crm_schema GRANT ALL ON SEQUENCES TO crm_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA finance_schema GRANT ALL ON SEQUENCES TO finance_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA logistics_schema GRANT ALL ON SEQUENCES TO logistics_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA operations_schema GRANT ALL ON SEQUENCES TO operations_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA supply_schema GRANT ALL ON SEQUENCES TO supply_user;
