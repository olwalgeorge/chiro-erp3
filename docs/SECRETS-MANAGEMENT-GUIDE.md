# Docker Compose Secrets Management Guide

## Overview

This guide explains how to securely manage secrets in ChiroERP's Docker Compose deployment.

## Quick Start

### 1. Create Your .env File

```bash
# Copy the example file
cp .env.example .env

# Edit with your actual secrets
# Use a text editor or:
notepad .env  # Windows
```

### 2. Generate Strong Passwords

```powershell
# PowerShell script to generate strong passwords
function New-StrongPassword {
    param([int]$Length = 32)
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*'
    -join ((1..$Length) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
}

# Generate passwords for all services
Write-Host "POSTGRES_PASSWORD=$(New-StrongPassword)"
Write-Host "CORE_DB_PASSWORD=$(New-StrongPassword)"
Write-Host "REDIS_PASSWORD=$(New-StrongPassword)"
# ... etc
```

### 3. Update docker-compose.yml

The `docker-compose.yml` now references variables like `${POSTGRES_PASSWORD}` which will be read from `.env`.

### 4. Start Services

```bash
docker-compose up -d
```

## Environment Variables Reference

### Database Secrets

| Variable                   | Purpose                   | Default (Dev Only)  |
| -------------------------- | ------------------------- | ------------------- |
| `POSTGRES_PASSWORD`        | PostgreSQL admin password | `postgres`          |
| `CORE_DB_PASSWORD`         | Core platform DB password | `core_pass`         |
| `ANALYTICS_DB_PASSWORD`    | Analytics DB password     | `analytics_pass`    |
| `COMMERCE_DB_PASSWORD`     | Commerce DB password      | `commerce_pass`     |
| `CRM_DB_PASSWORD`          | CRM DB password           | `crm_pass`          |
| `FINANCE_DB_PASSWORD`      | Finance DB password       | `finance_pass`      |
| `LOGISTICS_DB_PASSWORD`    | Logistics DB password     | `logistics_pass`    |
| `OPERATIONS_DB_PASSWORD`   | Operations DB password    | `operations_pass`   |
| `SUPPLY_CHAIN_DB_PASSWORD` | Supply Chain DB password  | `supply_chain_pass` |

### Redis & Kafka

| Variable         | Purpose        | Default (Dev Only) |
| ---------------- | -------------- | ------------------ |
| `REDIS_PASSWORD` | Redis password | `redis_secret`     |
| `KAFKA_PASSWORD` | Kafka password | Not set by default |

### OIDC / Keycloak

| Variable                  | Purpose                         | Default (Dev Only) |
| ------------------------- | ------------------------------- | ------------------ |
| `KEYCLOAK_ADMIN_PASSWORD` | Keycloak admin password         | `admin`            |
| `*_CLIENT_SECRET`         | OIDC client secrets per service | Service-specific   |

## Security Best Practices

### 1. Password Requirements

✅ **Minimum 16 characters** for production
✅ **32+ characters recommended** for high security
✅ **Mix character types**: uppercase, lowercase, numbers, symbols
✅ **Avoid patterns**: No keyboard walks, repeated characters
✅ **Use password manager**: LastPass, 1Password, Bitwarden

### 2. Secret Rotation

-   **Development**: Rotate every 180 days
-   **Staging**: Rotate every 90 days
-   **Production**: Rotate every 30-60 days
-   **Immediate rotation** if:
    -   Secret exposed in logs
    -   Employee departure
    -   Security incident
    -   Compliance requirement

### 3. Access Control

-   ✅ Limit who can access `.env` files
-   ✅ Use file permissions: `chmod 600 .env` (Unix)
-   ✅ Store production secrets in dedicated secrets manager
-   ✅ Enable MFA for secrets access
-   ✅ Audit all secret access

### 4. Environment Separation

```
Development  → Use .env with weak passwords (OK for local dev)
Staging      → Use .env with strong passwords (DO NOT commit)
Production   → Use secrets manager (Vault, AWS, Azure)
```

## Production Deployment

### Option 1: Docker Secrets (Docker Swarm)

```yaml
# docker-compose.prod.yml
version: "3.8"

services:
    core-platform:
        secrets:
            - db_password
            - oidc_secret
        environment:
            DB_PASSWORD_FILE: /run/secrets/db_password
            OIDC_CLIENT_SECRET_FILE: /run/secrets/oidc_secret

secrets:
    db_password:
        external: true
    oidc_secret:
        external: true
```

```bash
# Create secrets
echo "strong_password" | docker secret create db_password -
echo "oidc_secret" | docker secret create oidc_secret -

# Deploy
docker stack deploy -c docker-compose.prod.yml chiro-erp
```

### Option 2: HashiCorp Vault

```yaml
# docker-compose.vault.yml
services:
    core-platform:
        environment:
            VAULT_ADDR: https://vault.example.com
            VAULT_TOKEN: ${VAULT_TOKEN}
            DB_PASSWORD: vault:secret/data/chiro-erp/db#password
```

### Option 3: AWS Secrets Manager

```yaml
# Use AWS ECS task definition with secrets
{ "secrets": [{ "name": "DB_PASSWORD", "valueFrom": "arn:aws:secretsmanager:region:account:secret:db-password" }] }
```

### Option 4: Azure Key Vault

```yaml
# Use Azure Container Instances with Key Vault references
properties:
    containers:
        - name: core-platform
          environmentVariables:
              - name: DB_PASSWORD
                secureValue: <keyvault-secret-reference>
```

## Troubleshooting

### Issue: Services Can't Connect to Database

```bash
# Check if .env is loaded
docker-compose config | grep PASSWORD

# Verify environment variables
docker-compose exec core-platform env | grep DB_PASSWORD
```

### Issue: Secrets Not Loading

```bash
# Ensure .env is in the same directory as docker-compose.yml
ls -la .env

# Check file permissions
# Should be readable by docker-compose user
```

### Issue: Wrong Secrets in Container

```bash
# Recreate containers to pick up new secrets
docker-compose down
docker-compose up -d

# Or force recreate
docker-compose up -d --force-recreate
```

## Monitoring & Auditing

### Log Secret Access

```yaml
# Add audit logging for secret access
services:
    audit-logger:
        image: fluent/fluent-bit
        volumes:
            - /var/log/docker:/var/log/docker:ro
        # Filter for secret-related events
```

### Alert on Secret Exposure

-   Monitor logs for accidental secret logging
-   Alert on failed authentication attempts
-   Track secret access patterns
-   Set up automated secret scanning in CI/CD

## Compliance

### GDPR / CCPA

-   ✅ Encrypt secrets at rest
-   ✅ Document data retention policies
-   ✅ Implement right to deletion
-   ✅ Maintain audit trail

### PCI DSS (if handling payments)

-   ✅ Change default passwords
-   ✅ Encrypt transmission of cardholder data
-   ✅ Restrict access on need-to-know basis
-   ✅ Track and monitor all access

### SOC 2

-   ✅ Document security policies
-   ✅ Implement access controls
-   ✅ Regular security audits
-   ✅ Incident response plan

## Emergency Procedures

### If Secrets Are Compromised:

1. **Immediate Actions** (Within 1 hour):

    - Rotate ALL affected secrets
    - Revoke compromised credentials
    - Force re-authentication for all services
    - Enable additional logging

2. **Investigation** (Within 24 hours):

    - Determine scope of exposure
    - Check access logs
    - Identify unauthorized access
    - Document timeline

3. **Recovery** (Within 48 hours):

    - Deploy new secrets to all environments
    - Verify all services operational
    - Update documentation
    - Conduct post-mortem

4. **Prevention** (Ongoing):
    - Implement lessons learned
    - Update security policies
    - Enhanced monitoring
    - Team training

## Automation Scripts

### Auto-Rotate Secrets

```powershell
# rotate-secrets.ps1
param([string]$Environment)

function Rotate-Secret {
    param($SecretName)
    $newSecret = New-StrongPassword
    # Store in secrets manager
    # Update services
    # Verify connectivity
}

# Rotate all secrets
@('DB_PASSWORD', 'REDIS_PASSWORD', 'KAFKA_PASSWORD') | ForEach-Object {
    Rotate-Secret $_
}
```

### Verify Secrets Configuration

```powershell
# verify-secrets.ps1
$envFile = Get-Content .env
$requiredSecrets = @(
    'POSTGRES_PASSWORD',
    'CORE_DB_PASSWORD',
    'REDIS_PASSWORD'
)

foreach ($secret in $requiredSecrets) {
    if ($envFile -notmatch $secret) {
        Write-Error "Missing required secret: $secret"
    } elseif ($envFile -match "$secret=CHANGE_ME") {
        Write-Warning "Secret not changed from default: $secret"
    }
}
```

## Additional Resources

-   [Docker Secrets Documentation](https://docs.docker.com/engine/swarm/secrets/)
-   [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
-   [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
-   [NIST SP 800-53 Access Control](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-53r5.pdf)

---

**Remember**: Security is not a one-time setup—it's an ongoing process!
