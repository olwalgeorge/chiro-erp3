# Kotlin Formatting with ktlint

## What has been set up

✅ **ktlint Gradle plugin** has been added to your project
✅ **ktlint JAR file** downloaded to project root for VS Code integration
✅ **Configuration files** created:

-   `.editorconfig` - General formatting rules
-   `.ktlint` - ktlint-specific configuration
-   `.vscode/settings.json` - VS Code Kotlin formatter configuration
    ✅ **Gradle tasks** are available for all microservices
    ✅ **PowerShell scripts** for easy ktlint usage
    ✅ **Automatic formatting** has been applied where possible

## Available Gradle Tasks

### Format all Kotlin code

```powershell
.\gradlew ktlintFormatAll
```

### Check formatting of all Kotlin code

```powershell
.\gradlew ktlintCheckAll
```

### Format specific service

```powershell
.\gradlew :services:analytics-intelligence:ktlintFormat
.\gradlew :services:commerce:ktlintFormat
# ... etc for other services
```

### Check specific service

```powershell
.\gradlew :services:analytics-intelligence:ktlintCheck
.\gradlew :services:commerce:ktlintCheck
# ... etc for other services
```

## Current Status

✅ **Fixed automatically**: Most formatting issues (indentation, spacing, etc.)
⚠️ **Remaining issues that need manual fixes**:

1. **Wildcard imports** - Need to be converted to specific imports
2. **Long lines** - Need to be broken into multiple lines (max 120 chars)
3. **Empty placeholder files** - Need minimal content (already partially fixed)

## How to fix remaining issues

### 1. Fix wildcard imports

Replace lines like:

```kotlin
import jakarta.ws.rs.*
```

With specific imports:

```kotlin
import jakarta.ws.rs.GET
import jakarta.ws.rs.Path
import jakarta.ws.rs.Produces
```

### 2. Fix long lines

Break lines longer than 120 characters into multiple lines.

### 3. IDE Integration

Your Kotlin formatter extension should now work properly with ktlint!

## Using ktlint directly (with JAR)

### Format specific files

```powershell
java -jar ktlint.jar -F "services/**/*.kt"
```

### Check specific files

```powershell
java -jar ktlint.jar "services/**/*.kt"
```

### Using the wrapper script

```powershell
.\ktlint.ps1 --version
.\ktlint.ps1 -F "services/**/*.kt"
```

## Daily workflow

1. Make code changes
2. **VS Code will auto-format** when you save Kotlin files
3. Or run `.\gradlew ktlintFormatAll` to format all files
4. Fix any remaining manual issues
5. Run `.\gradlew ktlintCheckAll` to verify

## If ktlint.jar is missing

Run the download script:

```powershell
.\download-ktlint.ps1
```

## Configuration

-   **Max line length**: 120 characters
-   **Indent**: 4 spaces
-   **Rules**: Standard ktlint rules (some problematic rules disabled for placeholder files)
