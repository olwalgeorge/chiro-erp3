-- Initialize databases for all microservices
CREATE DATABASE core_db;
CREATE DATABASE analytics_db;
CREATE DATABASE commerce_db;
CREATE DATABASE crm_db;
CREATE DATABASE finance_db;
CREATE DATABASE logistics_db;
CREATE DATABASE operations_db;
CREATE DATABASE supply_db;
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

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE core_db TO core_user;
GRANT ALL PRIVILEGES ON DATABASE analytics_db TO analytics_user;
GRANT ALL PRIVILEGES ON DATABASE commerce_db TO commerce_user;
GRANT ALL PRIVILEGES ON DATABASE crm_db TO crm_user;
GRANT ALL PRIVILEGES ON DATABASE finance_db TO finance_user;
GRANT ALL PRIVILEGES ON DATABASE logistics_db TO logistics_user;
GRANT ALL PRIVILEGES ON DATABASE operations_db TO operations_user;
GRANT ALL PRIVILEGES ON DATABASE supply_db TO supply_user;
