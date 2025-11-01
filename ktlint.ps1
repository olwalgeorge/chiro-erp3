# ktlint wrapper script for Windows PowerShell
# Usage: .\ktlint.ps1 [ktlint-arguments]
# Examples:
#   .\ktlint.ps1 --version
#   .\ktlint.ps1 "services/**/*.kt"
#   .\ktlint.ps1 -F "services/**/*.kt"  # Format files

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
)

$ktlintJar = Join-Path $PSScriptRoot "ktlint.jar"

if (-not (Test-Path $ktlintJar)) {
    Write-Error "ktlint.jar not found in project root. Please download it first."
    exit 1
}

# Run ktlint with all passed arguments
& java -jar $ktlintJar @Arguments
