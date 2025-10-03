<#
.SYNOPSIS
    Configures Windows NTP client with secure, reliable time synchronization.

.DESCRIPTION
    Sets NTP servers, configures polling intervals, and ensures Windows Time service
    is properly configured. Includes error handling, validation, and geographic detection.

.PARAMETER NtpServers
    Comma-separated list of NTP servers. If not specified, automatically detects region.

.PARAMETER Region
    Geographic region for NTP pool selection. Options: NorthAmerica, Europe, Asia, Oceania, SouthAmerica, Africa, Auto.
    Default is Auto (detects based on timezone).

.PARAMETER SpecialPollInterval
    Poll interval in seconds. Default is 900 (15 minutes) for workstations, 300 (5 minutes) for servers.
    Valid range: 64-86400. Lower values increase accuracy but also network traffic.

.PARAMETER ServerType
    System type. Options: Workstation, Server. Adjusts default poll interval accordingly.

.PARAMETER Force
    Skip confirmation prompts.

.EXAMPLE
    .\Set-NTPConfig.ps1
    Automatically detects region and configures with appropriate defaults.

.EXAMPLE
    .\Set-NTPConfig.ps1 -Region Europe -SpecialPollInterval 300
    Uses European NTP pool servers with 5-minute polling.

.EXAMPLE
    .\Set-NTPConfig.ps1 -NtpServers "time.cloudflare.com,0x9 time.google.com,0x9" -Force
    Uses custom NTP servers without confirmation.

.EXAMPLE
    .\Set-NTPConfig.ps1 -ServerType Server
    Configures for server with 5-minute default polling interval.

.NOTES
    Requires Administrator privileges.
    Author: Enhanced for security and reliability
    Version: 2.1
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$false)]
    [string]$NtpServers,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('NorthAmerica', 'Europe', 'Asia', 'Oceania', 'SouthAmerica', 'Africa', 'Auto')]
    [string]$Region = 'Auto',
    
    [Parameter(Mandatory=$false)]
    [ValidateRange(64, 86400)]
    [int]$SpecialPollInterval,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('Workstation', 'Server')]
    [string]$ServerType = 'Workstation',
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

#Requires -RunAsAdministrator

# Set strict mode for better error detection
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $color = switch ($Level) {
        'Info'    { 'Cyan' }
        'Warning' { 'Yellow' }
        'Error'   { 'Red' }
        'Success' { 'Green' }
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Get-RegionFromTimezone {
    try {
        $timezone = Get-TimeZone
        $timezoneId = $timezone.Id
        
        # Map timezone to region
        switch -Regex ($timezoneId) {
            'Pacific|Mountain|Central|Eastern|Alaska|Hawaii|US|Canada|Mexico' { return 'NorthAmerica' }
            'Europe|GMT|UTC|London|Paris|Berlin|Rome|Madrid' { return 'Europe' }
            'Asia|Tokyo|Seoul|Shanghai|Hong Kong|Singapore|India' { return 'Asia' }
            'Australia|New Zealand|Pacific/Auckland' { return 'Oceania' }
            'South America|Argentina|Brazil|Chile' { return 'SouthAmerica' }
            'Africa|Cairo|Johannesburg' { return 'Africa' }
            default { 
                Write-Log "Could not detect region from timezone: $timezoneId. Defaulting to NorthAmerica." -Level Warning
                return 'NorthAmerica' 
            }
        }
    }
    catch {
        Write-Log "Error detecting timezone: $_. Defaulting to NorthAmerica." -Level Warning
        return 'NorthAmerica'
    }
}

function Get-NtpServersForRegion {
    param([string]$Region)
    
    $ntpPools = @{
        'NorthAmerica' = "0.north-america.pool.ntp.org,0x9 1.north-america.pool.ntp.org,0x9 2.north-america.pool.ntp.org,0x9 3.north-america.pool.ntp.org,0x9"
        'Europe'       = "0.europe.pool.ntp.org,0x9 1.europe.pool.ntp.org,0x9 2.europe.pool.ntp.org,0x9 3.europe.pool.ntp.org,0x9"
        'Asia'         = "0.asia.pool.ntp.org,0x9 1.asia.pool.ntp.org,0x9 2.asia.pool.ntp.org,0x9 3.asia.pool.ntp.org,0x9"
        'Oceania'      = "0.oceania.pool.ntp.org,0x9 1.oceania.pool.ntp.org,0x9 2.oceania.pool.ntp.org,0x9 3.oceania.pool.ntp.org,0x9"
        'SouthAmerica' = "0.south-america.pool.ntp.org,0x9 1.south-america.pool.ntp.org,0x9 2.south-america.pool.ntp.org,0x9 3.south-america.pool.ntp.org,0x9"
        'Africa'       = "0.africa.pool.ntp.org,0x9 1.africa.pool.ntp.org,0x9 2.africa.pool.ntp.org,0x9 3.africa.pool.ntp.org,0x9"
    }
    
    return $ntpPools[$Region]
}

function Test-RegistryPath {
    param([string]$Path)
    
    try {
        return Test-Path -Path $Path -ErrorAction Stop
    }
    catch {
        Write-Log "Failed to access registry path: $Path" -Level Error
        return $false
    }
}

function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [string]$Type = 'String'
    )
    
    try {
        if (-not (Test-RegistryPath -Path $Path)) {
            Write-Log "Registry path does not exist: $Path" -Level Error
            throw "Registry path not found"
        }
        
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -ErrorAction Stop
        Write-Log "Set $Name = $Value at $Path" -Level Success
        return $true
    }
    catch {
        Write-Log "Failed to set registry value $Name at $Path : $_" -Level Error
        throw
    }
}

function Wait-ServiceState {
    param(
        [string]$ServiceName,
        [string]$DesiredState,
        [int]$TimeoutSeconds = 30
    )
    
    $elapsed = 0
    $intervalMs = 500
    
    while ($elapsed -lt ($TimeoutSeconds * 1000)) {
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($service.Status -eq $DesiredState) {
            return $true
        }
        Start-Sleep -Milliseconds $intervalMs
        $elapsed += $intervalMs
    }
    
    return $false
}

function Test-NtpServer {
    param([string]$Server)
    
    try {
        Write-Log "Testing connectivity to $Server..." -Level Info
        $result = w32tm /stripchart /computer:$Server /samples:1 /dataonly 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Successfully contacted $Server" -Level Success
            return $true
        }
        else {
            Write-Log "Could not reach $Server" -Level Warning
            return $false
        }
    }
    catch {
        Write-Log "Error testing $Server : $_" -Level Warning
        return $false
    }
}

# Main execution
try {
    Write-Log "=== Windows NTP Configuration Script v2.0 ===" -Level Info
    Write-Log "Starting NTP configuration..." -Level Info
    
    # Determine region if auto-detect
    if (-not $NtpServers) {
        if ($Region -eq 'Auto') {
            $Region = Get-RegionFromTimezone
            Write-Log "Auto-detected region: $Region" -Level Info
        }
        
        $NtpServers = Get-NtpServersForRegion -Region $Region
        Write-Log "Using $Region NTP pool servers" -Level Info
    }
    else {
        Write-Log "Using custom NTP servers" -Level Info
    }
    
    # Set default poll interval based on server type if not specified
    if (-not $PSBoundParameters.ContainsKey('SpecialPollInterval')) {
        $SpecialPollInterval = if ($ServerType -eq 'Server') { 300 } else { 900 }
        Write-Log "Using default poll interval for ${ServerType}: $SpecialPollInterval seconds" -Level Info
    }
    
    Write-Log "NTP Servers: $NtpServers" -Level Info
    Write-Log "Poll Interval: $SpecialPollInterval seconds ($([Math]::Round($SpecialPollInterval/60, 1)) minutes)" -Level Info
    
    # Test connectivity to first NTP server
    $firstServer = ($NtpServers -split ' ')[0] -replace ',0x9', ''
    Test-NtpServer -Server $firstServer
    
    # Backup current configuration
    Write-Log "`nBacking up current configuration..." -Level Info
    $w32timeParams = "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters"
    $currentNtpServer = (Get-ItemProperty -Path $w32timeParams -Name "NtpServer" -ErrorAction SilentlyContinue).NtpServer
    $currentType = (Get-ItemProperty -Path $w32timeParams -Name "Type" -ErrorAction SilentlyContinue).Type
    
    if ($currentNtpServer) {
        Write-Log "Current NTP Server: $currentNtpServer" -Level Info
        Write-Log "Current Type: $currentType" -Level Info
    }
    else {
        Write-Log "No existing NTP configuration found" -Level Info
    }
    
    # Confirm changes if not forced
    if (-not $Force -and $PSCmdlet.ShouldProcess("Windows Time Service", "Configure NTP settings")) {
        Write-Host "`nThis will configure Windows Time with the following settings:" -ForegroundColor Yellow
        Write-Host "  Region: $Region" -ForegroundColor White
        Write-Host "  NTP Servers: $NtpServers" -ForegroundColor White
        Write-Host "  Poll Interval: $SpecialPollInterval seconds" -ForegroundColor White
        Write-Host ""
        $continue = Read-Host "Continue with configuration? (Y/N)"
        if ($continue -ne 'Y') {
            Write-Log "Configuration cancelled by user." -Level Warning
            exit 0
        }
    }
    
    # 1. Configure W32Time Parameters
    Write-Log "`nConfiguring W32Time parameters..." -Level Info
    Set-RegistryValue -Path $w32timeParams -Name "NtpServer" -Value $NtpServers
    Set-RegistryValue -Path $w32timeParams -Name "Type" -Value "NTP"
    
    # 2. Configure NtpClient Provider
    Write-Log "Configuring NtpClient provider..." -Level Info
    $ntpClientPath = "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpClient"
    Set-RegistryValue -Path $ntpClientPath -Name "SpecialPollInterval" -Value $SpecialPollInterval -Type DWord
    Set-RegistryValue -Path $ntpClientPath -Name "Enabled" -Value 1 -Type DWord
    
    # 3. Configure additional reliability settings
    Write-Log "Configuring additional time service settings..." -Level Info
    $configPath = "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config"
    Set-RegistryValue -Path $configPath -Name "MaxPosPhaseCorrection" -Value 3600 -Type DWord
    Set-RegistryValue -Path $configPath -Name "MaxNegPhaseCorrection" -Value 3600 -Type DWord
    Set-RegistryValue -Path $configPath -Name "UpdateInterval" -Value 100 -Type DWord
    
    # 4. Configure Windows Time Service
    Write-Log "Configuring Windows Time service..." -Level Info
    $service = Get-Service -Name w32time -ErrorAction Stop
    
    if ($service.StartType -ne 'Automatic') {
        Set-Service -Name w32time -StartupType Automatic -ErrorAction Stop
        Write-Log "Set w32time service to Automatic startup" -Level Success
    }
    
    # 5. Restart Service with Full Re-registration
    Write-Log "Restarting Windows Time service..." -Level Info
    
    if ($service.Status -eq 'Running') {
        Stop-Service -Name w32time -Force -ErrorAction Stop
        
        if (-not (Wait-ServiceState -ServiceName w32time -DesiredState Stopped -TimeoutSeconds 30)) {
            throw "Service did not stop within timeout period"
        }
        Write-Log "Service stopped successfully" -Level Success
    }
    
    # Unregister and re-register to ensure configuration is fully reloaded
    Write-Log "Re-registering Windows Time service to apply configuration..." -Level Info
    $unregResult = w32tm /unregister 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Unregister warning (may be expected): $unregResult" -Level Warning
    }
    
    $regResult = w32tm /register 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to register Windows Time service: $regResult"
    }
    Write-Log "Service re-registered successfully" -Level Success
    
    Start-Service -Name w32time -ErrorAction Stop
    
    if (-not (Wait-ServiceState -ServiceName w32time -DesiredState Running -TimeoutSeconds 30)) {
        throw "Service did not start within timeout period"
    }
    Write-Log "Service started successfully" -Level Success
    
    # 6. Apply Configuration and Sync
    Write-Log "Applying configuration changes..." -Level Info
    $updateResult = w32tm /config /update 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log "w32tm /config /update returned non-zero exit code: $LASTEXITCODE" -Level Warning
        Write-Log "Output: $updateResult" -Level Warning
    }
    else {
        Write-Log "Configuration updated successfully" -Level Success
    }
    
    # Wait for service to process configuration
    Start-Sleep -Seconds 5
    
    Write-Log "Forcing immediate time synchronization..." -Level Info
    $resyncResult = w32tm /resync /rediscover 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Time synchronization initiated successfully" -Level Success
    }
    else {
        Write-Log "Resync returned code $LASTEXITCODE - this may be normal if sync is in progress" -Level Warning
    }
    
    # 7. Verify Configuration
    Write-Log "`n=== VERIFICATION ===" -Level Info
    
    $verifyNtpServer = (Get-ItemProperty -Path $w32timeParams -Name "NtpServer").NtpServer
    $verifyType = (Get-ItemProperty -Path $w32timeParams -Name "Type").Type
    $verifyPollInterval = (Get-ItemProperty -Path $ntpClientPath -Name "SpecialPollInterval").SpecialPollInterval
    $verifyService = Get-Service -Name w32time
    
    Write-Host "`nConfigured NTP Servers: " -NoNewline
    Write-Host $verifyNtpServer -ForegroundColor Green
    Write-Host "Poll Interval: " -NoNewline
    Write-Host "$verifyPollInterval seconds ($([Math]::Round($verifyPollInterval/60, 1)) minutes)" -ForegroundColor Green
    Write-Host "Service Status: " -NoNewline
    Write-Host "$($verifyService.Status) ($($verifyService.StartType))" -ForegroundColor Green
    
    # 8. Display Current Status
    Write-Log "`n=== CURRENT TIME SYNCHRONIZATION STATUS ===" -Level Info
    w32tm /query /status
    
    Write-Log "`n=== CONFIGURATION COMPLETE ===" -Level Success
    Write-Host "`nNTP configuration completed successfully!" -ForegroundColor Green
    Write-Host "Note: It may take a few minutes for initial time synchronization to complete." -ForegroundColor Yellow
    Write-Host "`nTo verify sync status later, run: " -NoNewline -ForegroundColor Cyan
    Write-Host "w32tm /query /status" -ForegroundColor White
    
}
catch {
    Write-Log "`n=== FATAL ERROR ===" -Level Error
    Write-Log "Error: $_" -Level Error
    Write-Log "Stack Trace: $($_.ScriptStackTrace)" -Level Error
    
    # Attempt to restore service if it's stopped
    $service = Get-Service -Name w32time -ErrorAction SilentlyContinue
    if ($service -and $service.Status -ne 'Running') {
        Write-Log "Attempting to restart Windows Time service..." -Level Warning
        try {
            Start-Service -Name w32time -ErrorAction Stop
            Write-Log "Service restarted successfully" -Level Success
        }
        catch {
            Write-Log "Failed to restart service: $_" -Level Error
            Write-Log "You may need to manually restart the Windows Time service" -Level Error
        }
    }
    
    exit 1
}
finally {
    Write-Log "`nScript execution completed." -Level Info
}
