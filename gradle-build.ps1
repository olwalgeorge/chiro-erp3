# PowerShell script to run Gradle with proper memory settings
# This ensures the correct JVM arguments are used

$env:GRADLE_OPTS = "-Xms2g -Xmx6g -XX:MaxMetaspaceSize=1g -XX:+HeapDumpOnOutOfMemoryError -Dfile.encoding=UTF-8"
$env:JAVA_OPTS = "-Xms2g -Xmx6g -XX:MaxMetaspaceSize=1g"

Write-Host "Setting Gradle environment variables:"
Write-Host "GRADLE_OPTS: $env:GRADLE_OPTS"
Write-Host "JAVA_OPTS: $env:JAVA_OPTS"
Write-Host ""

# Stop any existing daemons
Write-Host "Stopping existing Gradle daemons..."
& ./gradlew --stop

# Run the build
Write-Host "Starting build with increased memory..."
& ./gradlew $args
