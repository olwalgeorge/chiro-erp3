# Keycloak Admin Client Dependency Fix

## Problem

IDE showed error: `Unresolved dependency: io.quarkus quarkus-keycloak-admin-client-reactive`

## Root Cause

The `application.properties` file contained Keycloak admin client properties:

```properties
quarkus.keycloak.admin-client.server-url=...
quarkus.keycloak.admin-client.realm=master
quarkus.keycloak.admin-client.client-id=admin-cli
quarkus.keycloak.admin-client.username=...
quarkus.keycloak.admin-client.password=...
```

These properties require a Keycloak admin extension, but:

-   ❌ `quarkus-keycloak-admin-client-reactive` **does NOT exist** in Quarkus 3.x
-   ✅ The correct extension is `quarkus-keycloak-admin-rest-client`

## Solution

Added the correct Quarkus 3.x extension to `services/core-platform/build.gradle`:

```gradle
// Keycloak Admin Client (for managing users/realms programmatically)
implementation 'io.quarkus:quarkus-keycloak-admin-rest-client'
```

## Verification

```powershell
.\gradlew :services:core-platform:clean :services:core-platform:compileKotlin --refresh-dependencies
```

✅ **Build successful in 9m 16s**

## Available Keycloak Extensions in Quarkus 3.x

-   ✅ `quarkus-keycloak-admin-rest-client` - Modern REST-based admin client (recommended)
-   ✅ `quarkus-keycloak-admin-resteasy-client` - Legacy RESTEasy-based admin client
-   ✅ `quarkus-keycloak-authorization` - Policy enforcer
-   ✅ `quarkus-oidc` - OpenID Connect authentication (already in use)

## Next Steps

1. **Reload IDE**: Press `Ctrl+Shift+P` → "Java: Clean Java Language Server Workspace" → "Reload and delete"
2. **Verify**: IDE error should disappear after reload
3. **Configure**: Update Keycloak admin properties in `application.properties` as needed

## Notes

-   The extension uses Quarkus 3.29.0 automatically via the BOM
-   Keycloak admin client is only needed if you programmatically manage users/realms
-   For authentication only, `quarkus-oidc` is sufficient
