# Windows High-Precision NTP Configuration Script

This PowerShell script configures secure, accurate, and frequent time synchronization on Windows 10/11 systems using geo-optimized NTP server pools for optimal performance and reliability.

## Features

- Sets regional NTP server pools (North America) for low-latency synchronization
- Polls every ~60 seconds for high accuracy
- Applies recommended `0x9` flags (SpecialInterval + Client)
- Forces immediate time sync
- Ensures Windows Time service is configured and running
- Ideal for environments requiring tight time precision (e.g., financial systems, monitoring, logging)

## NTP Server Pools Used

| Pool Server                          | Organization    | Notes                                      |
|--------------------------------------|-----------------|--------------------------------------------|
| 0.north-america.pool.ntp.org         | NTP Pool Project| Primary - Automatically selects West Coast servers |
| 1.north-america.pool.ntp.org         | NTP Pool Project| Secondary - Geographic redundancy          |
| 2.north-america.pool.ntp.org         | NTP Pool Project| Tertiary - Load-balanced stratum 1/2 servers |
| 3.north-america.pool.ntp.org         | NTP Pool Project| Quaternary - High availability             |

**Why Pools Over Static Servers?**
- **Geo-optimization**: Automatically resolves to nearby servers (10-30ms latency vs 50-100ms from global endpoints)
- **Redundancy**: Thousands of volunteer servers worldwide, 99.99% uptime
- **Load balancing**: Distributes queries to prevent overload during spikes
- **Future-proof**: Maintains performance as network topology changes

All servers are configured with `,0x9` flag:
> `0x9 = SpecialInterval (0x1) + Client Mode (0x8)`

## Script Contents

```powershell
# Requires admin privileges

# 1. Set trusted, accurate NTP servers (SWITCHED TO POOLS FOR GEO-OPTIMIZATION)
# Original: "time.cloudflare.com,0x9 time.google.com,0x9 time.nist.gov,0x9 time.apple.com,0x9"
$ntpServers = "0.north-america.pool.ntp.org,0x9 1.north-america.pool.ntp.org,0x9 2.north-america.pool.ntp.org,0x9 3.north-america.pool.ntp.org,0x9"

Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -Name "NtpServer" -Value $ntpServers
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -Name "Type" -Value "NTP"

# 2. Configure NtpClient provider
$ntpClientPath = "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpClient"

# Poll every 60 seconds (can change to 120/300 if needed)
Set-ItemProperty -Path $ntpClientPath -Name "SpecialPollInterval" -Value 60 -Type DWord
Set-ItemProperty -Path $ntpClientPath -Name "Enabled" -Value 1 -Type DWord

# 3. Ensure Windows Time service is automatic and running
Set-Service w32time -StartupType Automatic
Restart-Service w32time

# 4. Apply and force immediate sync
w32tm /config /update
Start-Sleep -Seconds 3
w32tm /resync /nowait

# 5. Output current configuration
Write-Host "`n--- CURRENT TIME CONFIGURATION ---"
w32tm /query /configuration
w32tm /query /status
```

## Usage

**Option 1: Run Directly**

- Open PowerShell as Administrator
- Paste the script and press Enter

**Option 2: Save and Run as .ps1**

- Save script as `Set-NTPConfig.ps1`
- Run it with PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Path\To\Set-NTPConfig.ps1"
```

## Verify Sync Status

After running the script, check time sync with:

```powershell
w32tm /query /status
```

Expected output includes:

- Source: one of the configured NTP servers
- Stratum: 2 (synced from a stratum 1 server)
- Last Successful Sync Time: recent timestamp
- Poll Interval: 64 seconds

## Revert to Original Static Servers
To restore the original Cloudflare/Google/NIST/Apple configuration:

```powershell
$originalServers = "time.cloudflare.com,0x9 time.google.com,0x9 time.nist.gov,0x9 time.apple.com,0x9"
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -Name "NtpServer" -Value $originalServers
w32tm /config /update
w32tm /resync /nowait
```

## Optional Commands

| Task                    | Command                                                          |
|-------------------------|------------------------------------------------------------------|
| View current peers      | `w32tm /query /peers`                                            |
| Sync test to NTP server | `w32tm /stripchart /computer:time.nist.gov /samples:5 /dataonly` |
| Show config summary     | `w32tm /query /configuration`                                    |

## Revert to Original Static Servers
To restore the original Cloudflare/Google/NIST/Apple configuration:

```powershell
$originalServers = "time.cloudflare.com,0x9 time.google.com,0x9 time.nist.gov,0x9 time.apple.com,0x9"
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -Name "NtpServer" -Value $originalServers
w32tm /config /update
w32tm /resync /nowait
```

## Changelog
v1.1 (2025-09-21)

Switched from static servers to regional NTP pools for improved latency and reliability
Updated documentation with pool benefits and revert instructions
Adjusted poll interval documentation for clarity
Added "Tested On" compatibility section

v1.0 (Initial Release)

Original static server configuration (Cloudflare, Google, NIST, Apple)
Basic time synchronization setup

## Tested On
Windows 11 Enteprise (Build 26100.4946)

## License
This project is licensed under the MIT License - see the LICENSE file for details.

## Contribute
Have a trustworthy NTP pool recommendation or regional variant? Submit a pull request or open an issue.

## Support
Need help with .reg, .bat, .exe, GPO/Intune deployment, or regional pool customization? Open an issue or PR, and assistance will be provided.

## Credits
Created with the assistance of Grok by xAI for automation, pool optimization research, and documentation refinement. Original concept developed with OpenAI and ChatGPT.
