# IDE Configuration Guide - Suppress Property Warnings

This guide explains how to eliminate annoying property validation warnings in VS Code for Quarkus projects.

## The Problem

VS Code's MicroProfile and Quarkus extensions validate `application.properties` files by checking if properties are referenced in Java/Kotlin code. This causes false warnings like:

```
❌ Unrecognized property 'quarkus.datasource.password', it is not referenced in any Java files
❌ Unrecognized property 'quarkus.mailer.host', it is not referenced in any Java files
```

**These are FALSE POSITIVES** - Quarkus uses these properties internally!

## The Solution

### 1. VS Code Settings (Already Applied)

The `.vscode/settings.json` file has been configured with:

```json
{
    // Disable MicroProfile property validation warnings
    "microprofile.tools.validation.enabled": false,
    "microprofile.tools.validation.unknown": "ignore",
    "microprofile.tools.validation.value.severity": "none",

    // Quarkus-specific settings
    "quarkus.tools.validation.enabled": false,
    "quarkus.tools.validation.value.severity": "none",
    "quarkus.tools.validation.unknown.severity": "none",

    // Java validation settings
    "java.errors.incompleteClasspath.severity": "ignore"
}
```

### 2. Reload VS Code

After the settings are applied, you **MUST reload** VS Code:

**Option A: Command Palette**

1. Press `Ctrl+Shift+P`
2. Type: `Developer: Reload Window`
3. Press Enter

**Option B: Clean Java Language Server**

1. Press `Ctrl+Shift+P`
2. Type: `Java: Clean Java Language Server Workspace`
3. Select `Reload and delete`
4. Wait for indexing to complete

**Option C: Restart VS Code**

-   Close VS Code completely
-   Reopen it

### 3. Verify Extensions

Make sure you have the correct extensions installed:

**Required:**

-   ✅ **Extension Pack for Java** (vscjava.vscode-java-pack)
-   ✅ **Gradle for Java** (vscjava.vscode-gradle)
-   ✅ **Kotlin** (fwcd.kotlin)

**Optional (but can cause warnings):**

-   ⚠️ **Tools for MicroProfile** (redhat.vscode-microprofile) - Now disabled via settings
-   ⚠️ **Quarkus** (redhat.vscode-quarkus) - Now disabled via settings

### 4. Alternative: Disable Extensions

If warnings persist, you can disable the problematic extensions:

1. Press `Ctrl+Shift+X` to open Extensions
2. Search for "MicroProfile"
3. Click the gear icon → `Disable (Workspace)`
4. Search for "Quarkus"
5. Click the gear icon → `Disable (Workspace)`

**Note:** This removes language support features but eliminates all warnings.

### 5. Per-File Solution

If you want to keep validation but suppress warnings in specific files, add this comment at the top of `application.properties`:

```properties
# @validation:ignore
```

## Why These Warnings Occur

The MicroProfile Language Server scans Java/Kotlin files to build a list of "known" properties. If a property isn't directly referenced in code, it's flagged as "unrecognized."

**Problem:** Quarkus runtime uses these properties internally via reflection - they never appear in your code!

**Examples of internally-used properties:**

-   `quarkus.datasource.*` - Used by Hibernate/Agroal
-   `quarkus.mailer.*` - Used by Quarkus Mailer
-   `quarkus.oidc.*` - Used by OIDC extension
-   `quarkus.keycloak.admin-client.*` - Used by Keycloak admin client
-   `quarkus.log.*` - Used by logging framework
-   `quarkus.micrometer.*` - Used by metrics

## Testing the Fix

After reloading VS Code:

1. Open `services/core-platform/src/main/resources/application.properties`
2. Check the Problems panel (`Ctrl+Shift+M`)
3. ✅ Property warnings should be **GONE**
4. ✅ Only real errors (syntax, typos) should appear

## Troubleshooting

### Warnings Still Appear?

1. **Check if settings were applied:**

    - Open `.vscode/settings.json`
    - Verify all validation settings are present
    - Save the file

2. **Force reload:**

    ```powershell
    # Close VS Code completely
    # Delete workspace cache
    Remove-Item -Path "$env:APPDATA\Code\User\workspaceStorage\*" -Recurse -Force
    # Reopen VS Code
    ```

3. **Check extension settings:**
    - Open Settings (`Ctrl+,`)
    - Search for "microprofile validation"
    - Ensure "Validation Enabled" is **unchecked**
    - Search for "quarkus validation"
    - Ensure "Validation Enabled" is **unchecked**

### Build Still Works?

Yes! These settings only affect **IDE warnings**, not actual compilation:

```powershell
# Test the build
.\gradlew :services:core-platform:build

# Should succeed ✅
```

## Summary

| Setting                                             | Purpose                         | Status                  |
| --------------------------------------------------- | ------------------------------- | ----------------------- |
| `microprofile.tools.validation.enabled = false`     | Disable MicroProfile validation | ✅ Applied              |
| `quarkus.tools.validation.enabled = false`          | Disable Quarkus validation      | ✅ Applied              |
| `java.errors.incompleteClasspath.severity = ignore` | Ignore classpath warnings       | ✅ Applied              |
| Reload VS Code                                      | Apply settings                  | ⏳ **You must do this** |

## Benefits

✅ **Clean Problems panel** - Only real errors shown
✅ **Faster IDE** - Less validation overhead
✅ **Better focus** - No noise from false positives
✅ **Build still works** - No impact on compilation

---

**Remember:** After applying these settings, you **MUST reload VS Code** for changes to take effect!
