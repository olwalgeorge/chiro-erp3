# Task 2: Proper Secrets Management

## Overview

Replace hardcoded passwords and sensitive data in `docker-compose.yml` with secure secrets management.

## Current Issues

### Hardcoded Secrets in docker-compose.yml:

```yaml
❌ POSTGRES_PASSWORD: chiro_admin_pass
❌ DB_PASSWORD: core_pass
❌ REDIS_PASSWORD: redis_secret
❌ KAFKA_PASSWORD: kafka_secret
❌ OIDC_CLIENT_SECRET: core-secret
❌ KEYCLOAK_ADMIN_PASSWORD: admin
```

## Solutions

### Option 1: Docker Secrets (Recommended for Production)

-   Store secrets in Docker Swarm secrets
-   Encrypted at rest and in transit
-   Best security posture

### Option 2: Environment Files (.env)

-   Store secrets in `.env` file (not committed to git)
-   Simple, works with docker-compose
-   Good for development/staging

### Option 3: External Secrets Manager

-   HashiCorp Vault
-   AWS Secrets Manager
-   Azure Key Vault
-   Best for enterprise

## Implementation Plan

### Step 1: Create .env.example Template

-   List all required environment variables
-   Provide example/placeholder values
-   Add instructions for users

### Step 2: Update docker-compose.yml

-   Replace hardcoded values with ${ENV_VAR}
-   Add env_file directive
-   Keep defaults for development

### Step 3: Add .gitignore Entry

-   Ensure .env is not committed
-   Keep .env.example in repo

### Step 4: Document Secret Rotation

-   How to update secrets
-   When to rotate
-   Who has access

## Security Benefits

✅ Secrets not in source control
✅ Different secrets per environment
✅ Easy rotation without code changes
✅ Audit trail for secret access
✅ Reduced risk of exposure

## Next Actions

1. Create `.env.example` template
2. Update `docker-compose.yml` to use environment variables
3. Add `.env` to `.gitignore`
4. Create secrets management documentation
5. Test deployment with new configuration

---

**Status:** 🔜 Ready to start
**Dependencies:** Task 1 (Health Checks) ✅ Complete
**Estimated Time:** 30 minutes
