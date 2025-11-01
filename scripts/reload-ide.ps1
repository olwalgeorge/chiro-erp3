#!/usr/bin/env pwsh
# Reload IDE script - Clear VS Code Java/Gradle caches and reload

Write-Host "🔄 Reloading VS Code Java/Gradle Project..." -ForegroundColor Cyan

# Step 1: Clean Gradle caches
Write-Host "`n📦 Cleaning Gradle caches..." -ForegroundColor Yellow
& .\gradlew clean --refresh-dependencies

# Step 2: Delete VS Code workspace storage (if exists)
$workspaceStoragePath = ".vscode\.cache"
if (Test-Path $workspaceStoragePath) {
    Write-Host "🗑️  Removing VS Code cache..." -ForegroundColor Yellow
    Remove-Item -Path $workspaceStoragePath -Recurse -Force
}

# Step 3: Instructions for manual reload
Write-Host "`n✅ Gradle caches cleared!" -ForegroundColor Green
Write-Host "`n📝 Next steps:" -ForegroundColor Cyan
Write-Host "   1. In VS Code, press Ctrl+Shift+P" -ForegroundColor White
Write-Host "   2. Type: 'Java: Clean Java Language Server Workspace'" -ForegroundColor White
Write-Host "   3. Select 'Reload and delete' when prompted" -ForegroundColor White
Write-Host "   4. Wait for the IDE to fully reload (check bottom-right status)" -ForegroundColor White
Write-Host "`n   OR simply close and reopen VS Code" -ForegroundColor White
Write-Host "`n💡 The 'Unresolved dependency' error should disappear after reload!" -ForegroundColor Green
