<#
.SYNOPSIS
    Monitors Windows NTP synchronization health and reports status.

.DESCRIPTION
    Checks Windows Time service health, last sync time, stratum level, and peer status.
    Can be used for monitoring, alerting, or scheduled health checks.

.PARAMETER MaxHoursSinceSync
    Maximum hours since last successful sync before warning. Default: 2 hours.

.PARAMETER AlertThresholdHours
    Hours since last sync to trigger critical alert. Default: 24 hours.

.PARAMETER CheckPeers
    Include detailed peer connectivity checks.

.PARAMETER ExportJson
    Export results to JSON file for monitoring systems.

.PARAMETER JsonPath
    Path for JSON export. Default: .\ntp-health.json

.EXAMPLE
    .\Test-NTPHealth.ps1
    Basic health check with default thresholds.

.EXAMPLE
    .\Test-NTPHealth.ps1 -CheckPeers -MaxHoursSinceSync 1
    Detailed check with 1-hour sync threshold.

.EXAMPLE
    .\Test-NTPHealth.ps1 -ExportJson -JsonPath "C:\Monitoring\ntp-health.json"
    Export results for monitoring system integration.

.NOTES
    Author: NTP Health Monitor
    Version: 1.0
    Requires: Windows 10/11 or Windows Server 2016+
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateRange(0.1, 168)]
    [double]$MaxHoursSinceSync = 2,
    
    [Parameter(Mandatory=$false)]
    [ValidateRange(1, 168)]
    [double]$AlertThresholdHours = 24,
    
    [Parameter(Mandatory=$false)]
    [switch]$CheckPeers,
    
    [Parameter(Mandatory=$false)]
    [switch]$ExportJson,
    
    [Parameter(Mandatory=$false)]
    [string]$JsonPath = ".\ntp-health.json"
)

Set-StrictMode -Version Latest

function Write-HealthStatus {
    param(
        [string]$Message,
        [ValidateSet('OK', 'Warning', 'Critical', 'Info')]
        [string]$Status = 'Info'
    )
    
    $color = switch ($Status) {
        'OK'       { 'Green' }
        'Warning'  { 'Yellow' }
        'Critical' { 'Red' }
        'Info'     { 'Cyan' }
    }
    
    $icon = switch ($Status) {
        'OK'       { '✓' }
        'Warning'  { '⚠' }
        'Critical' { '✗' }
        'Info'     { 'ℹ' }
    }
    
    Write-Host "$icon [$Status] $Message" -ForegroundColor $color
}

function Get-ServiceHealth {
    try {
        $service = Get-Service -Name w32time -ErrorAction Stop
        
        return @{
            Status = $service.Status.ToString()
            StartType = $service.StartType.ToString()
            IsHealthy = ($service.Status -eq 'Running' -and $service.StartType -eq 'Automatic')
        }
    }
    catch {
        return @{
            Status = 'Unknown'
            StartType = 'Unknown'
            IsHealthy = $false
            Error = $_.Exception.Message
        }
    }
}

function Get-TimeStatus {
    try {
        $statusOutput = w32tm /query /status 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            return @{
                IsHealthy = $false
                Error = "w32tm returned exit code $LASTEXITCODE"
            }
        }
        
        $status = @{
            IsHealthy = $true
        }
        
        # Parse output
        foreach ($line in $statusOutput) {
            if ($line -match "Leap Indicator: (.+)") {
                $status.LeapIndicator = $matches[1].Trim()
            }
            elseif ($line -match "Stratum: (\d+)") {
                $status.Stratum = [int]$matches[1]
            }
            elseif ($line -match "Precision: (.+)") {
                $status.Precision = $matches[1].Trim()
            }
            elseif ($line -match "Root Delay: (.+)") {
                $status.RootDelay = $matches[1].Trim()
            }
            elseif ($line -match "Root Dispersion: (.+)") {
                $status.RootDispersion = $matches[1].Trim()
            }
            elseif ($line -match "ReferenceId: (.+)") {
                $status.ReferenceId = $matches[1].Trim()
            }
            elseif ($line -match "Last Successful Sync Time: (.+)") {
                $syncTimeStr = $matches[1].Trim()
                try {
                    $status.LastSyncTime = [DateTime]::Parse($syncTimeStr)
                    $status.HoursSinceSync = ((Get-Date) - $status.LastSyncTime).TotalHours
                }
                catch {
                    $status.LastSyncTimeRaw = $syncTimeStr
                }
            }
            elseif ($line -match "Source: (.+)") {
                $status.Source = $matches[1].Trim()
            }
            elseif ($line -match "Poll Interval: (\d+)") {
                $status.PollInterval = [int]$matches[1]
                $status.PollIntervalSeconds = [Math]::Pow(2, $status.PollInterval)
            }
        }
        
        return $status
    }
    catch {
        return @{
            IsHealthy = $false
            Error = $_.Exception.Message
        }
    }
}

function Get-PeerStatus {
    try {
        $peersOutput = w32tm /query /peers 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            return @{
                IsHealthy = $false
                Error = "w32tm /query /peers returned exit code $LASTEXITCODE"
            }
        }
        
        $peers = @()
        $currentPeer = @{}
        
        foreach ($line in $peersOutput) {
            if ($line -match "^Peer: (.+)") {
                if ($currentPeer.Count -gt 0) {
                    $peers += $currentPeer
                }
                $currentPeer = @{
                    Name = $matches[1].Trim()
                }
            }
            elseif ($line -match "State: (.+)") {
                $currentPeer.State = $matches[1].Trim()
            }
            elseif ($line -match "Stratum: (\d+)") {
                $currentPeer.Stratum = [int]$matches[1]
            }
            elseif ($line -match "Type: (.+)") {
                $currentPeer.Type = $matches[1].Trim()
            }
            elseif ($line -match "Last Successful Sync Time: (.+)") {
                $currentPeer.LastSync = $matches[1].Trim()
            }
        }
        
        if ($currentPeer.Count -gt 0) {
            $peers += $currentPeer
        }
        
        return @{
            IsHealthy = $true
            Peers = $peers
            PeerCount = $peers.Count
        }
    }
    catch {
        return @{
            IsHealthy = $false
            Error = $_.Exception.Message
        }
    }
}

function Get-NTPConfiguration {
    try {
        $params = "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters"
        $client = "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpClient"
        
        return @{
            NtpServer = (Get-ItemProperty -Path $params -Name "NtpServer" -ErrorAction SilentlyContinue).NtpServer
            Type = (Get-ItemProperty -Path $params -Name "Type" -ErrorAction SilentlyContinue).Type
            SpecialPollInterval = (Get-ItemProperty -Path $client -Name "SpecialPollInterval" -ErrorAction SilentlyContinue).SpecialPollInterval
            Enabled = (Get-ItemProperty -Path $client -Name "Enabled" -ErrorAction SilentlyContinue).Enabled
        }
    }
    catch {
        return @{
            Error = $_.Exception.Message
        }
    }
}

# Main execution
try {
    Write-Host "`n=== NTP Health Check ===" -ForegroundColor Cyan
    Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor Gray
    
    $results = @{
        Timestamp = Get-Date -Format 'o'
        OverallHealth = 'OK'
        Checks = @{}
    }
    
    # Check 1: Service Status
    Write-Host "1. Windows Time Service" -ForegroundColor White
    $serviceHealth = Get-ServiceHealth
    $results.Checks.Service = $serviceHealth
    
    if ($serviceHealth.IsHealthy) {
        Write-HealthStatus "Service is running and set to Automatic" -Status OK
    }
    else {
        Write-HealthStatus "Service Status: $($serviceHealth.Status), StartType: $($serviceHealth.StartType)" -Status Critical
        $results.OverallHealth = 'Critical'
    }
    
    # Check 2: Time Synchronization Status
    Write-Host "`n2. Time Synchronization Status" -ForegroundColor White
    $timeStatus = Get-TimeStatus
    $results.Checks.TimeSync = $timeStatus
    
    if (-not $timeStatus.IsHealthy) {
        Write-HealthStatus "Failed to query time status: $($timeStatus.Error)" -Status Critical
        $results.OverallHealth = 'Critical'
    }
    else {
        Write-HealthStatus "Source: $($timeStatus.Source)" -Status Info
        Write-HealthStatus "Stratum: $($timeStatus.Stratum)" -Status Info
        
        if ($timeStatus.HoursSinceSync) {
            $hoursSince = [Math]::Round($timeStatus.HoursSinceSync, 2)
            
            if ($hoursSince -le $MaxHoursSinceSync) {
                Write-HealthStatus "Last sync: $hoursSince hours ago" -Status OK
            }
            elseif ($hoursSince -le $AlertThresholdHours) {
                Write-HealthStatus "Last sync: $hoursSince hours ago (exceeds $MaxHoursSinceSync hour threshold)" -Status Warning
                if ($results.OverallHealth -eq 'OK') {
                    $results.OverallHealth = 'Warning'
                }
            }
            else {
                Write-HealthStatus "Last sync: $hoursSince hours ago (CRITICAL: exceeds $AlertThresholdHours hour threshold)" -Status Critical
                $results.OverallHealth = 'Critical'
            }
            
            Write-HealthStatus "Last sync time: $($timeStatus.LastSyncTime)" -Status Info
        }
        
        if ($timeStatus.PollIntervalSeconds) {
            $pollMinutes = [Math]::Round($timeStatus.PollIntervalSeconds / 60, 1)
            Write-HealthStatus "Poll interval: $pollMinutes minutes" -Status Info
        }
    }
    
    # Check 3: Configuration
    Write-Host "`n3. NTP Configuration" -ForegroundColor White
    $config = Get-NTPConfiguration
    $results.Checks.Configuration = $config
    
    if ($config.NtpServer) {
        Write-HealthStatus "NTP Servers: $($config.NtpServer)" -Status Info
        Write-HealthStatus "Type: $($config.Type)" -Status Info
        
        if ($config.SpecialPollInterval) {
            $pollMinutes = [Math]::Round($config.SpecialPollInterval / 60, 1)
            Write-HealthStatus "Configured poll interval: $pollMinutes minutes" -Status Info
        }
    }
    else {
        Write-HealthStatus "Could not read NTP configuration" -Status Warning
        if ($results.OverallHealth -eq 'OK') {
            $results.OverallHealth = 'Warning'
        }
    }
    
    # Check 4: Peer Status (optional)
    if ($CheckPeers) {
        Write-Host "`n4. NTP Peer Status" -ForegroundColor White
        $peerStatus = Get-PeerStatus
        $results.Checks.Peers = $peerStatus
        
        if ($peerStatus.IsHealthy) {
            Write-HealthStatus "Found $($peerStatus.PeerCount) configured peer(s)" -Status Info
            
            foreach ($peer in $peerStatus.Peers) {
                Write-Host "`n  Peer: $($peer.Name)" -ForegroundColor Gray
                Write-Host "    State: $($peer.State)" -ForegroundColor Gray
                Write-Host "    Stratum: $($peer.Stratum)" -ForegroundColor Gray
                if ($peer.LastSync) {
                    Write-Host "    Last Sync: $($peer.LastSync)" -ForegroundColor Gray
                }
            }
        }
        else {
            Write-HealthStatus "Failed to query peers: $($peerStatus.Error)" -Status Warning
        }
    }
    
    # Summary
    Write-Host "`n=== Health Summary ===" -ForegroundColor Cyan
    $summaryStatus = switch ($results.OverallHealth) {
        'OK'       { 'OK' }
        'Warning'  { 'Warning' }
        'Critical' { 'Critical' }
    }
    Write-HealthStatus "Overall Status: $($results.OverallHealth)" -Status $summaryStatus
    
    # Export JSON if requested
    if ($ExportJson) {
        try {
            $results | ConvertTo-Json -Depth 10 | Set-Content -Path $JsonPath -ErrorAction Stop
            Write-Host "`nResults exported to: $JsonPath" -ForegroundColor Green
        }
        catch {
            Write-Host "`nFailed to export JSON: $_" -ForegroundColor Red
        }
    }
    
    # Set exit code based on health
    $exitCode = switch ($results.OverallHealth) {
        'OK'       { 0 }
        'Warning'  { 1 }
        'Critical' { 2 }
    }
    
    exit $exitCode
}
catch {
    Write-Host "`nFATAL ERROR: $_" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 3
}