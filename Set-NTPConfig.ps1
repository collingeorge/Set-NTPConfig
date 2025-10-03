<#
.SYNOPSIS
    Configures Windows NTP client with secure, reliable time synchronization.

.DESCRIPTION
    Sets NTP servers, configures polling intervals, and ensures Windows Time service
    is properly configured. Handles missing registry keys and forces resync.

.PARAMETER NtpServers
    Comma-separated list of NTP servers. If not specified, automatically detects region.

.PARAMETER Region
    Geographic region for NTP pool selection. Options: NorthAmerica, Europe, Asia, Oceania, SouthAmerica, Africa, Auto.
    Default is Auto (detects based on timezone).

.PARAMETER SpecialPollInterval
    Poll interval in seconds. Default is 900 (15 minutes) for workstations, 300 (5 minutes) for servers.

.PARAMETER ServerType
    System type. Options: Workstation, Server. Adjusts default poll interval accordingly.

.PARAMETER Force
    Skip confirmation prompts.
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [string]$NtpServers,
    [ValidateSet('NorthAmerica','Europe','Asia','Oceania','SouthAmerica','Africa','Auto')]
    [string]$Region = 'Auto',
    [ValidateRange(64,86400)]
    [int]$SpecialPollInterval,
    [ValidateSet('Workstation','Server')]
    [string]$ServerType = 'Workstation',
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Log {
    param([string]$Message, [string]$Level='Info')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $color = switch ($Level) {
        'Info' { 'Cyan' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        'Success' { 'Green' }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Get-RegionFromTimezone {
    try {
        $tz = (Get-TimeZone).Id
        switch -Regex ($tz) {
            'Pacific|Mountain|Central|Eastern|Alaska|Hawaii|US|Canada|Mexico' { return 'NorthAmerica' }
            'Europe|GMT|London|Paris|Berlin|Rome|Madrid' { return 'Europe' }
            'Asia|Tokyo|Seoul|Shanghai|Hong Kong|Singapore|India' { return 'Asia' }
            'Australia|New Zealand|Pacific/Auckland' { return 'Oceania' }
            'South America|Argentina|Brazil|Chile' { return 'SouthAmerica' }
            'Africa|Cairo|Johannesburg' { return 'Africa' }
            default { Write-Log "Could not detect region: $tz. Defaulting to NorthAmerica" -Level Warning; return 'NorthAmerica' }
        }
    } catch { Write-Log "Error detecting timezone: $_. Defaulting to NorthAmerica" -Level Warning; return 'NorthAmerica' }
}

function Get-NtpServersForRegion {
    param([string]$Region)
    $pools = @{
        'NorthAmerica' = "0.north-america.pool.ntp.org,0x9 1.north-america.pool.ntp.org,0x9 2.north-america.pool.ntp.org,0x9 3.north-america.pool.ntp.org,0x9"
        'Europe'       = "0.europe.pool.ntp.org,0x9 1.europe.pool.ntp.org,0x9 2.europe.pool.ntp.org,0x9 3.europe.pool.ntp.org,0x9"
        'Asia'         = "0.asia.pool.ntp.org,0x9 1.asia.pool.ntp.org,0x9 2.asia.pool.ntp.org,0x9 3.asia.pool.ntp.org,0x9"
        'Oceania'      = "0.oceania.pool.ntp.org,0x9 1.oceania.pool.ntp.org,0x9 2.oceania.pool.ntp.org,0x9 3.oceania.pool.ntp.org,0x9"
        'SouthAmerica' = "0.south-america.pool.ntp.org,0x9 1.south-america.pool.ntp.org,0x9 2.south-america.pool.ntp.org,0x9 3.south-america.pool.ntp.org,0x9"
        'Africa'       = "0.africa.pool.ntp.org,0x9 1.africa.pool.ntp.org,0x9 2.africa.pool.ntp.org,0x9 3.africa.pool.ntp.org,0x9"
    }
    return $pools[$Region]
}

function Ensure-RegistryPath {
    param([string]$Path)
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
}

# ---- Main Execution ----
Write-Log "=== Windows NTP Configuration Script v2.9 ==="

# Auto-detect region and servers
if (-not $NtpServers) {
    if ($Region -eq 'Auto') { $Region = Get-RegionFromTimezone; Write-Log "Auto-detected region: $Region" }
    $NtpServers = Get-NtpServersForRegion -Region $Region
    Write-Log "Using $Region NTP pool servers"
} else { Write-Log "Using custom NTP servers" }

# Set default poll interval
if (-not $SpecialPollInterval) { $SpecialPollInterval = if ($ServerType -eq 'Server') { 300 } else { 900 } }
Write-Log "Poll interval: $SpecialPollInterval seconds ($([Math]::Round($SpecialPollInterval/60,1)) minutes)"

# Confirm
if (-not $Force) {
    Write-Host "`nThis will configure Windows Time:" -ForegroundColor Yellow
    Write-Host "  NTP Servers: $NtpServers" -ForegroundColor White
    Write-Host "  Poll Interval: $SpecialPollInterval seconds" -ForegroundColor White
    if ((Read-Host "Continue? (Y/N)") -ne 'Y') { Write-Log "Cancelled by user" -Level Warning; exit 0 }
}

# Ensure service exists
if (-not (Get-Service -Name w32time -ErrorAction SilentlyContinue)) {
    Write-Log "Windows Time service not found. Registering..." -Level Info
    w32tm /register
}

# Ensure registry paths exist
$w32timeParams = "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters"
$ntpClientPath  = "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpClient"
$configPath     = "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config"

Ensure-RegistryPath -Path $w32timeParams
Ensure-RegistryPath -Path $ntpClientPath
Ensure-RegistryPath -Path $configPath

# Set registry values
Set-ItemProperty -Path $w32timeParams -Name "NtpServer" -Value $NtpServers
Set-ItemProperty -Path $w32timeParams -Name "Type" -Value "NTP"
Set-ItemProperty -Path $ntpClientPath -Name "SpecialPollInterval" -Value $SpecialPollInterval -Type DWord
Set-ItemProperty -Path $ntpClientPath -Name "Enabled" -Value 1 -Type DWord
Set-ItemProperty -Path $configPath -Name "MaxPosPhaseCorrection" -Value 3600 -Type DWord
Set-ItemProperty -Path $configPath -Name "MaxNegPhaseCorrection" -Value 3600 -Type DWord
Set-ItemProperty -Path $configPath -Name "UpdateInterval" -Value 100 -Type DWord

# Ensure service startup
$service = Get-Service -Name w32time
if ($service.StartType -ne 'Automatic') { Set-Service -Name w32time -StartupType Automatic }

# Restart service
Stop-Service -Name w32time -Force
Start-Sleep 2
Start-Service -Name w32time
Start-Sleep 2

# Force update and resync
w32tm /config /update
w32tm /resync /rediscover

# Verify
Write-Log "`n=== CURRENT TIME SYNCHRONIZATION STATUS ==="
w32tm /query /status
Write-Log "`nConfigured NTP Servers: $NtpServers"
Write-Log "Poll Interval: $SpecialPollInterval seconds"
Write-Log "Windows Time service: $(Get-Service w32time).Status"

Write-Log "`n=== CONFIGURATION COMPLETE ===" -Level Success
