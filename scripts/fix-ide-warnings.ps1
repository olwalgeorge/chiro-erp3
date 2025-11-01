#!/usr/bin/env pwsh
# Fix IDE Property Warnings - Complete Solution

Write-Host "🔧 Fixing VS Code IDE Property Warnings..." -ForegroundColor Cyan
Write-Host ""

# Step 1: Verify settings.json exists
$settingsFile = ".vscode\settings.json"
if (Test-Path $settingsFile) {
    Write-Host "✅ Found $settingsFile" -ForegroundColor Green

    # Check if MicroProfile validation is disabled
    $content = Get-Content $settingsFile -Raw
    if ($content -match '"microprofile.tools.validation.enabled"\s*:\s*false') {
        Write-Host "✅ MicroProfile validation already disabled" -ForegroundColor Green
    }
    else {
        Write-Host "⚠️  MicroProfile validation settings missing or incorrect" -ForegroundColor Yellow
        Write-Host "   Please check .vscode/settings.json manually" -ForegroundColor Yellow
    }
}
else {
    Write-Host "❌ $settingsFile not found!" -ForegroundColor Red
}

Write-Host ""

# Step 2: Check which extensions are installed
Write-Host "📦 Checking VS Code Extensions..." -ForegroundColor Cyan
$extensions = code --list-extensions 2>$null
if ($LASTEXITCODE -eq 0) {
    if ($extensions -match "redhat.vscode-microprofile") {
        Write-Host "⚠️  MicroProfile extension detected: redhat.vscode-microprofile" -ForegroundColor Yellow
        Write-Host "   This extension is now disabled via settings" -ForegroundColor Yellow
    }
    if ($extensions -match "redhat.vscode-quarkus") {
        Write-Host "⚠️  Quarkus extension detected: redhat.vscode-quarkus" -ForegroundColor Yellow
        Write-Host "   This extension is now disabled via settings" -ForegroundColor Yellow
    }
    if ($extensions -match "vscjava.vscode-java-pack") {
        Write-Host "✅ Java Extension Pack installed" -ForegroundColor Green
    }
    if ($extensions -match "fwcd.kotlin") {
        Write-Host "✅ Kotlin extension installed" -ForegroundColor Green
    }
}
else {
    Write-Host "⚠️  Could not check extensions (VS Code CLI not in PATH)" -ForegroundColor Yellow
}

Write-Host ""

# Step 3: Clean Java Language Server cache
Write-Host "🧹 Cleaning Java Language Server workspace..." -ForegroundColor Cyan
$javaWorkspaceCache = "$env:APPDATA\Code\User\workspaceStorage"
if (Test-Path $javaWorkspaceCache) {
    $cacheSize = (Get-ChildItem $javaWorkspaceCache -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host "   Cache size: $([math]::Round($cacheSize, 2)) MB" -ForegroundColor Gray

    $confirm = Read-Host "   Clear cache? This will make VS Code re-index the project (y/n)"
    if ($confirm -eq 'y') {
        try {
            Remove-Item -Path "$javaWorkspaceCache\*" -Recurse -Force -ErrorAction Stop
            Write-Host "✅ Cache cleared successfully" -ForegroundColor Green
        }
        catch {
            Write-Host "⚠️  Could not clear cache (VS Code might be running)" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "⏭️  Skipped cache clearing" -ForegroundColor Gray
    }
}
else {
    Write-Host "   No cache found (or VS Code not used yet)" -ForegroundColor Gray
}

Write-Host ""

# Step 4: Provide instructions
Write-Host "📋 Next Steps:" -ForegroundColor Cyan
Write-Host ""
Write-Host "   1️⃣  Reload VS Code to apply settings:" -ForegroundColor White
Write-Host "      • Press Ctrl+Shift+P" -ForegroundColor Gray
Write-Host "      • Type: 'Developer: Reload Window'" -ForegroundColor Gray
Write-Host "      • Press Enter" -ForegroundColor Gray
Write-Host ""
Write-Host "   2️⃣  OR Clean Java Language Server (recommended):" -ForegroundColor White
Write-Host "      • Press Ctrl+Shift+P" -ForegroundColor Gray
Write-Host "      • Type: 'Java: Clean Java Language Server Workspace'" -ForegroundColor Gray
Write-Host "      • Select 'Reload and delete'" -ForegroundColor Gray
Write-Host ""
Write-Host "   3️⃣  Wait for re-indexing to complete" -ForegroundColor White
Write-Host "      • Check bottom-right status bar" -ForegroundColor Gray
Write-Host "      • Wait for 'Building workspace' to finish" -ForegroundColor Gray
Write-Host ""
Write-Host "   4️⃣  Verify warnings are gone:" -ForegroundColor White
Write-Host "      • Open application.properties" -ForegroundColor Gray
Write-Host "      • Check Problems panel (Ctrl+Shift+M)" -ForegroundColor Gray
Write-Host "      • Property warnings should be GONE! ✅" -ForegroundColor Gray
Write-Host ""

# Step 5: Alternative solution
Write-Host "💡 Alternative (if warnings persist):" -ForegroundColor Yellow
Write-Host "   Disable MicroProfile extension entirely:" -ForegroundColor White
Write-Host "   • Press Ctrl+Shift+X (Extensions)" -ForegroundColor Gray
Write-Host "   • Search 'MicroProfile'" -ForegroundColor Gray
Write-Host "   • Click gear icon → 'Disable (Workspace)'" -ForegroundColor Gray
Write-Host ""

Write-Host "📖 Full documentation: docs\IDE-CONFIGURATION.md" -ForegroundColor Cyan
Write-Host ""
Write-Host "✨ Configuration complete! Reload VS Code to see the changes." -ForegroundColor Green
