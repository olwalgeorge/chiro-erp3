# ChiroERP Resource Monitoring Script
# Monitors Docker container resource usage and alerts on high consumption

param(
    [Parameter(Mandatory = $false)]
    [int]$IntervalSeconds = 5,

    [Parameter(Mandatory = $false)]
    [int]$CpuThresholdPercent = 80,

    [Parameter(Mandatory = $false)]
    [int]$MemoryThresholdPercent = 85,

    [Parameter(Mandatory = $false)]
    [int]$DurationMinutes = 0  # 0 = run indefinitely
)

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "  ChiroERP Resource Monitoring" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Thresholds:" -ForegroundColor Yellow
Write-Host "  CPU Warning: $CpuThresholdPercent%" -ForegroundColor Yellow
Write-Host "  Memory Warning: $MemoryThresholdPercent%" -ForegroundColor Yellow
Write-Host "  Check Interval: $IntervalSeconds seconds" -ForegroundColor Yellow
if ($DurationMinutes -gt 0) {
    Write-Host "  Duration: $DurationMinutes minutes" -ForegroundColor Yellow
}
else {
    Write-Host "  Duration: Continuous (Press Ctrl+C to stop)" -ForegroundColor Yellow
}
Write-Host ""

$startTime = Get-Date
$alerts = @()

function Parse-MemoryUsage {
    param([string]$MemString)

    # Format: "123.4MiB / 1GiB" or "1.2GiB / 2GiB"
    if ($MemString -match '([\d.]+)([MG]iB)\s*/\s*([\d.]+)([MG]iB)') {
        $used = [double]$matches[1]
        $usedUnit = $matches[2]
        $total = [double]$matches[3]
        $totalUnit = $matches[4]

        # Convert to MB
        if ($usedUnit -eq "GiB") { $used = $used * 1024 }
        if ($totalUnit -eq "GiB") { $total = $total * 1024 }

        $percent = [math]::Round(($used / $total) * 100, 2)
        return $percent
    }
    return 0
}

function Get-ContainerStats {
    $stats = docker stats --no-stream --format "{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}|{{.MemPerc}}|{{.NetIO}}|{{.BlockIO}}"

    $containers = @()
    foreach ($line in $stats) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        $parts = $line -split '\|'
        if ($parts.Count -lt 6) { continue }

        $cpuPercent = ($parts[1] -replace '%', '').Trim()
        $memPercent = ($parts[3] -replace '%', '').Trim()

        $containers += [PSCustomObject]@{
            Name       = $parts[0].Trim()
            CPU        = [double]$cpuPercent
            MemUsage   = $parts[2].Trim()
            MemPercent = [double]$memPercent
            NetIO      = $parts[4].Trim()
            BlockIO    = $parts[5].Trim()
        }
    }

    return $containers
}

function Show-Stats {
    param($Containers)

    Clear-Host
    Write-Host "===========================================" -ForegroundColor Cyan
    Write-Host "  ChiroERP Resource Monitoring" -ForegroundColor Cyan
    Write-Host "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
    Write-Host "===========================================" -ForegroundColor Cyan
    Write-Host ""

    # Sort by CPU usage
    $sorted = $Containers | Sort-Object -Property CPU -Descending

    Write-Host ("{0,-40} {1,8} {2,20} {3,8}" -f "CONTAINER", "CPU %", "MEMORY USAGE", "MEM %") -ForegroundColor White
    Write-Host ("{0,-40} {1,8} {2,20} {3,8}" -f "---------", "-----", "------------", "-----") -ForegroundColor White

    foreach ($container in $sorted) {
        $color = "White"
        $alert = ""

        if ($container.CPU -ge $CpuThresholdPercent) {
            $color = "Red"
            $alert = "⚠ HIGH CPU"
        }
        elseif ($container.MemPercent -ge $MemoryThresholdPercent) {
            $color = "Red"
            $alert = "⚠ HIGH MEMORY"
        }
        elseif ($container.CPU -ge ($CpuThresholdPercent * 0.8) -or $container.MemPercent -ge ($MemoryThresholdPercent * 0.8)) {
            $color = "Yellow"
        }

        $name = $container.Name
        if ($name.Length -gt 40) {
            $name = $name.Substring(0, 37) + "..."
        }

        Write-Host ("{0,-40} {1,7}% {2,20} {3,7}% {4}" -f $name, $container.CPU, $container.MemUsage, $container.MemPercent, $alert) -ForegroundColor $color

        if ($alert) {
            $alertMsg = "[$(Get-Date -Format 'HH:mm:ss')] $alert - $($container.Name) - CPU: $($container.CPU)% - Memory: $($container.MemPercent)%"
            if (-not ($alerts -contains $alertMsg)) {
                $alerts += $alertMsg
            }
        }
    }

    Write-Host ""
    Write-Host "Network I/O & Block I/O:" -ForegroundColor Cyan
    Write-Host ("{0,-40} {1,20} {2,20}" -f "CONTAINER", "NETWORK I/O", "BLOCK I/O") -ForegroundColor White
    Write-Host ("{0,-40} {1,20} {2,20}" -f "---------", "-----------", "---------") -ForegroundColor White

    foreach ($container in $sorted) {
        $name = $container.Name
        if ($name.Length -gt 40) {
            $name = $name.Substring(0, 37) + "..."
        }
        Write-Host ("{0,-40} {1,20} {2,20}" -f $name, $container.NetIO, $container.BlockIO) -ForegroundColor White
    }

    # Summary
    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Cyan
    $avgCpu = [math]::Round(($Containers | Measure-Object -Property CPU -Average).Average, 2)
    $avgMem = [math]::Round(($Containers | Measure-Object -Property MemPercent -Average).Average, 2)
    $maxCpu = [math]::Round(($Containers | Measure-Object -Property CPU -Maximum).Maximum, 2)
    $maxMem = [math]::Round(($Containers | Measure-Object -Property MemPercent -Maximum).Maximum, 2)

    Write-Host "  Containers Running: $($Containers.Count)" -ForegroundColor White
    Write-Host "  Average CPU: $avgCpu% | Max CPU: $maxCpu%" -ForegroundColor White
    Write-Host "  Average Memory: $avgMem% | Max Memory: $maxMem%" -ForegroundColor White

    if ($alerts.Count -gt 0) {
        Write-Host ""
        Write-Host "Recent Alerts:" -ForegroundColor Red
        $recentAlerts = $alerts | Select-Object -Last 10
        foreach ($alert in $recentAlerts) {
            Write-Host "  $alert" -ForegroundColor Red
        }
    }

    Write-Host ""
    $elapsed = (Get-Date) - $startTime
    Write-Host "Monitoring for: $($elapsed.ToString('hh\:mm\:ss'))" -ForegroundColor Gray
    Write-Host "Press Ctrl+C to stop..." -ForegroundColor Gray
}

# Main monitoring loop
$iteration = 0
$endTime = if ($DurationMinutes -gt 0) { (Get-Date).AddMinutes($DurationMinutes) } else { $null }

try {
    while ($true) {
        if ($endTime -and (Get-Date) -gt $endTime) {
            Write-Host ""
            Write-Host "Monitoring duration completed." -ForegroundColor Green
            break
        }

        $containers = Get-ContainerStats

        if ($containers.Count -eq 0) {
            Write-Host "No containers running. Waiting..." -ForegroundColor Yellow
            Start-Sleep -Seconds $IntervalSeconds
            continue
        }

        Show-Stats -Containers $containers

        $iteration++
        Start-Sleep -Seconds $IntervalSeconds
    }
}
catch {
    Write-Host ""
    Write-Host "Monitoring stopped." -ForegroundColor Yellow
}

# Final summary
Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "  Monitoring Summary" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "Total monitoring time: $((Get-Date) - $startTime)" -ForegroundColor White
Write-Host "Total iterations: $iteration" -ForegroundColor White
Write-Host "Total alerts: $($alerts.Count)" -ForegroundColor White

if ($alerts.Count -gt 0) {
    Write-Host ""
    Write-Host "All Alerts:" -ForegroundColor Red
    foreach ($alert in $alerts) {
        Write-Host "  $alert" -ForegroundColor Red
    }

    # Export alerts to file
    $alertFile = "resource-alerts-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    $alerts | Out-File -FilePath $alertFile -Encoding UTF8
    Write-Host ""
    Write-Host "Alerts exported to: $alertFile" -ForegroundColor Green
}

Write-Host ""
Write-Host "Monitoring complete!" -ForegroundColor Green
