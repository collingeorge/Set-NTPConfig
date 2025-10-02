# Set-NTPConfig

PowerShell script that configures secure, accurate, and reliable time synchronization on Windows 10/11 systems using geo-optimized public NTP server pools.

## ✨ Features

- **🌍 Automatic Region Detection** - Detects your timezone and selects optimal NTP pool servers
- **🔒 Enhanced Security** - Admin privilege verification, input validation, and error handling
- **📊 Comprehensive Logging** - Timestamped, color-coded output with detailed status messages
- **✅ Verification & Testing** - Tests NTP server connectivity and verifies configuration
- **🔄 Reliable Service Management** - Proper service state verification with timeout handling
- **📝 Configuration Backup** - Logs current settings before making changes
- **⚙️ Flexible Parameters** - Customize servers, regions, and poll intervals
- **🛡️ Production-Ready** - Full error handling and rollback on failure

## 🚀 Quick Start

### Option 1: Auto-Configure (Recommended)

Open PowerShell as Administrator and run:

```powershell
.\Set-NTPConfig.ps1
```

This will:
- Auto-detect your region
- Use appropriate default poll interval (15 min for workstations, 5 min for servers)
- Configure Windows Time service
- Verify the configuration

### Option 2: Specify Region

```powershell
.\Set-NTPConfig.ps1 -Region Europe
```

### Option 3: Custom Servers

```powershell
.\Set-NTPConfig.ps1 -NtpServers "time.cloudflare.com,0x9 time.google.com,0x9" -Force
```

### Option 4: Server Configuration

```powershell
.\Set-NTPConfig.ps1 -ServerType Server -SpecialPollInterval 300
```

## 📋 Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `NtpServers` | String | (Auto) | Comma-separated NTP servers with flags. If not specified, uses regional pool. |
| `Region` | String | Auto | Geographic region: NorthAmerica, Europe, Asia, Oceania, SouthAmerica, Africa, Auto |
| `SpecialPollInterval` | Int | 900/300 | Poll interval in seconds (64-86400). Default: 900s workstation, 300s server |
| `ServerType` | String | Workstation | System type: Workstation or Server. Affects default poll interval. |
| `Force` | Switch | False | Skip confirmation prompts |

## 🌐 Regional NTP Pools

The script uses geo-optimized NTP pools for low latency and high reliability:

| Region | Pool Servers | Benefits |
|--------|--------------|----------|
| **North America** | 0-3.north-america.pool.ntp.org | 10-30ms latency, West Coast optimization |
| **Europe** | 0-3.europe.pool.ntp.org | European data center routing |
| **Asia** | 0-3.asia.pool.ntp.org | Asian-Pacific optimization |
| **Oceania** | 0-3.oceania.pool.ntp.org | Australia/NZ proximity |
| **South America** | 0-3.south-america.pool.ntp.org | Latin American routing |
| **Africa** | 0-3.africa.pool.ntp.org | African continent coverage |

### Why Regional Pools?

✅ **Geo-optimization** - Automatically resolves to nearby servers (10-30ms vs 50-100ms)  
✅ **Redundancy** - Thousands of volunteer servers worldwide, 99.99% uptime  
✅ **Load balancing** - Distributes queries across multiple servers  
✅ **Future-proof** - Adapts to network topology changes automatically

## ⚙️ Technical Details

### NTP Server Flags

All servers are configured with `,0x9` flag:
- `0x9 = SpecialInterval (0x1) + Client Mode (0x8)`
- Uses the `SpecialPollInterval` registry value
- Treats server as a peer in client mode

### Poll Interval Recommendations

| Environment | Recommended Interval | Reasoning |
|-------------|---------------------|-----------|
| **Workstations** | 900-3600s (15-60 min) | Balanced accuracy with minimal network load |
| **Servers** | 300-900s (5-15 min) | Higher accuracy for logging/transactions |
| **High-Precision** | 64-300s (1-5 min) | Financial systems, monitoring (increases traffic) |
| **Low-Priority** | 3600-86400s (1-24 hr) | Minimal network usage, lower accuracy |

⚠️ **Warning**: Poll intervals under 300 seconds significantly increase network traffic. Use only when necessary.

### Registry Configuration

The script configures:

```
HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters
├── NtpServer (REG_SZ)
└── Type (REG_SZ)

HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpClient
├── SpecialPollInterval (REG_DWORD)
└── Enabled (REG_DWORD)

HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config
├── MaxPosPhaseCorrection (REG_DWORD) - 3600 seconds
├── MaxNegPhaseCorrection (REG_DWORD) - 3600 seconds
└── UpdateInterval (REG_DWORD) - 100
```

## 🔍 Verification

After running the script, verify configuration:

```powershell
# Check sync status
w32tm /query /status

# View configured peers
w32tm /query /peers

# Test specific NTP server
w32tm /stripchart /computer:time.nist.gov /samples:5 /dataonly
```

### Expected Output

```
Source: 0.north-america.pool.ntp.org
Stratum: 2 (synced from stratum 1)
Last Successful Sync Time: <recent timestamp>
Poll Interval: 15 (32768s)
```

## 🔄 Rollback / Restore Defaults

### Restore Windows Default (time.windows.com)

```powershell
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -Name "NtpServer" -Value "time.windows.com,0x9"
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -Name "Type" -Value "NTP"
Restart-Service w32time
w32tm /config /update
w32tm /resync
```

### Restore to Domain Time (Domain-Joined Computers)

```powershell
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -Name "Type" -Value "NT5DS"
Restart-Service w32time
w32tm /config /update
w32tm /resync
```

## 🛠️ Troubleshooting

### Issue: "Access Denied" Error

**Solution**: Run PowerShell as Administrator

```powershell
# Check if running as admin
([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
```

### Issue: Service Won't Start

**Solution**: Check Windows Time service dependencies

```powershell
# Check service status
Get-Service w32time | Format-List *

# Check event logs
Get-EventLog -LogName System -Source "Microsoft-Windows-Time-Service" -Newest 20
```

### Issue: Time Won't Sync

**Solution**: Verify firewall allows NTP (UDP 123)

```powershell
# Test NTP connectivity
w32tm /stripchart /computer:time.nist.gov /samples:3 /dataonly

# Check firewall rules
Get-NetFirewallRule -DisplayName "*time*"
```

### Issue: "The specified time server cannot be reached"

**Possible Causes**:
1. Firewall blocking UDP port 123
2. Network connectivity issue
3. NTP server temporarily unavailable (pools auto-retry)

**Solution**: Wait 5-10 minutes for automatic retry or manually resync:

```powershell
w32tm /resync /rediscover
```

## 📊 Advanced Usage

### Monitor Time Sync Health

Create a monitoring script:

```powershell
# Check-NTPHealth.ps1
$status = w32tm /query /status
$lastSync = ($status | Select-String "Last Successful Sync Time").ToString()
$source = ($status | Select-String "Source").ToString()

Write-Host "NTP Source: $source"
Write-Host $lastSync

# Alert if last sync > 1 hour ago
# (Add your alerting logic here)
```

### Scheduled Task for Periodic Checks

```powershell
# Create scheduled task to verify NTP sync daily
$action = New-ScheduledTaskAction -Execute 'w32tm' -Argument '/resync'
$trigger = New-ScheduledTaskTrigger -Daily -At 3am
Register-ScheduledTask -TaskName "Daily NTP Sync" -Action $action -Trigger $trigger -RunLevel Highest
```

## 🔐 Security Considerations

### What the Script Does

✅ Verifies administrator privileges before execution  
✅ Validates all input parameters  
✅ Uses error handling with try-catch blocks  
✅ Backs up current configuration  
✅ Verifies registry paths before writing  
✅ Tests NTP server connectivity  
✅ Implements service state verification with timeouts  
✅ Logs all operations with timestamps  

### What to Review Before Running

1. **NTP Server Trust** - Ensure you trust the NTP servers being configured
2. **Network Policies** - Verify your organization allows external NTP traffic (UDP 123)
3. **Domain Policies** - Check if Group Policy controls time settings (will override)
4. **Audit Requirements** - Some compliance frameworks require specific time sources

## 📈 Version History

### v2.0 (2025-10-01)
- ✨ Added automatic region detection based on timezone
- 🔒 Implemented comprehensive error handling and validation
- ✅ Added NTP server connectivity testing
- 📊 Enhanced logging with timestamps and color coding
- ⚙️ Added configuration backup and verification
- 🛡️ Implemented service state management with timeouts
- 📝 Added support for all geographic regions
- ⚡ Improved poll interval defaults (workstation vs server)
- 🔧 Added additional reliability registry settings
- 📚 Complete parameter documentation and help system

### v1.1 (2025-09-21)
- Switched from static servers to regional NTP pools
- Updated documentation with pool benefits
- Adjusted poll interval documentation

### v1.0 (Initial Release)
- Original static server configuration
- Basic time synchronization setup

## 🧪 Tested On

- ✅ Windows 11 Enterprise (Build 26100.4946)
- ✅ Windows 11 Pro (Build 22631)
- ✅ Windows 10 Pro (Build 19045)
- ✅ Windows Server 2022
- ✅ Windows Server 2019

## 🤝 Contributing

Have a trustworthy NTP pool recommendation, regional variant, or improvement? Submit a pull request or open an issue!

### Development Guidelines

1. Maintain backward compatibility
2. Add comprehensive error handling
3. Update help documentation
4. Test on multiple Windows versions
5. Follow PowerShell best practices

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **NTP Pool Project** - For providing global volunteer NTP infrastructure
- **Original Script** - Created with assistance from Grok by xAI and OpenAI ChatGPT
- **v2.0 Enhancement** - Security and reliability improvements by Claude (Anthropic)

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/collingeorge/Set-NTPConfig/issues)
- **Documentation**: [NTP Pool Project](https://www.ntppool.org/)
- **Windows Time Service**: [Microsoft Docs](https://docs.microsoft.com/windows-server/networking/windows-time-service/)

---

**⚠️ Important Notes**

1. **Domain-Joined Computers**: May sync from domain controller. Check Group Policy before using.
2. **Network Requirements**: Requires outbound UDP port 123 access
3. **Execution Policy**: May need to run with `-ExecutionPolicy Bypass` if policies are restrictive
4. **Backup Recommendation**: Export registry keys before running in production environments

---

## 📖 Additional Resources

### Useful Commands Reference

| Task | Command |
|------|---------|
| Check current configuration | `w32tm /query /configuration` |
| View sync status | `w32tm /query /status` |
| List active peers | `w32tm /query /peers` |
| Force immediate sync | `w32tm /resync /rediscover` |
| Test NTP server | `w32tm /stripchart /computer:<server> /samples:5` |
| View service status | `Get-Service w32time \| Format-List *` |
| Check event logs | `Get-EventLog -LogName System -Source "*Time*" -Newest 20` |
| Export configuration | `w32tm /query /configuration > ntp-config.txt` |

### Understanding Stratum Levels

| Stratum | Description | Use Case |
|---------|-------------|----------|
| 0 | Reference clock (atomic, GPS) | Physical time source |
| 1 | Primary servers (directly connected to stratum 0) | Data centers, ISPs |
| 2 | Secondary servers (sync from stratum 1) | **Most common for end users** |
| 3-15 | Lower tiers (sync from higher stratum) | Internal networks |
| 16 | Unsynchronized | Not synced to any source |

**Note**: The script configures your system as a client that syncs from stratum 1/2 servers in the NTP pool, making your system stratum 2/3.

### Network Firewall Configuration

If you're having connectivity issues, ensure UDP port 123 is allowed:

**Windows Firewall Rule** (if needed):
```powershell
New-NetFirewallRule -DisplayName "NTP Client" `
    -Direction Outbound `
    -Protocol UDP `
    -RemotePort 123 `
    -Action Allow `
    -Profile Any
```

**Corporate Firewall**: Contact your network administrator to allow:
- **Protocol**: UDP
- **Port**: 123 (outbound)
- **Destinations**: NTP pool servers (or specific IPs if required)

### Group Policy Considerations

If you're in a domain environment, check for time-related GPOs:

```powershell
# Check if Group Policy is controlling time settings
Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\W32Time\Parameters" -ErrorAction SilentlyContinue
Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\W32Time\TimeProviders\NtpClient" -ErrorAction SilentlyContinue
```

**If GPO is configured**: Your manual changes may be overridden. Options:
1. Request GPO exemption for your system
2. Configure at the domain level
3. Use a local override (not recommended for compliance)

## 🔬 Understanding the `0x9` Flag

The `0x9` flag in the NTP server configuration is a hexadecimal value that combines two settings:

```
0x9 = 0x1 + 0x8
```

- **0x1 (SpecialInterval)**: Use the `SpecialPollInterval` registry value instead of calculated interval
- **0x8 (Client Mode)**: Configure as a client (request time from server)

Other common flags:
- **0x1**: SpecialInterval only
- **0x8**: Client mode only
- **0x9**: Both (recommended for most scenarios)

## 🎯 Use Cases

### 1. Development Workstation
```powershell
.\Set-NTPConfig.ps1 -Region Auto -SpecialPollInterval 900
```
**Why**: 15-minute intervals provide good accuracy without excessive network traffic.

### 2. Production Server
```powershell
.\Set-NTPConfig.ps1 -ServerType Server -SpecialPollInterval 300 -Force
```
**Why**: 5-minute intervals ensure accurate timestamps for logging and transactions.

### 3. High-Precision Financial System
```powershell
.\Set-NTPConfig.ps1 -ServerType Server -SpecialPollInterval 64 -Force
```
**Why**: Minimum allowed interval (64s) for maximum time accuracy. Monitor network impact.

### 4. Remote Office with Slow Connection
```powershell
.\Set-NTPConfig.ps1 -SpecialPollInterval 3600 -Force
```
**Why**: 1-hour intervals reduce bandwidth usage while maintaining reasonable accuracy.

### 5. Multi-Region Deployment
```powershell
# North America
.\Set-NTPConfig.ps1 -Region NorthAmerica -ServerType Server -Force

# Europe
.\Set-NTPConfig.ps1 -Region Europe -ServerType Server -Force

# Asia
.\Set-NTPConfig.ps1 -Region Asia -ServerType Server -Force
```
**Why**: Optimize latency for each geographic location in your infrastructure.

## 🐛 Known Issues & Limitations

### Issue 1: First Sync Takes Several Minutes
**Cause**: Windows Time service needs to establish trust with NTP servers  
**Impact**: Low - Normal behavior  
**Workaround**: Wait 5-10 minutes after initial configuration

### Issue 2: Sync Fails on VMware/Hyper-V Guests
**Cause**: VM time sync may conflict with Windows Time service  
**Solution**: Disable VM time synchronization:
```powershell
# VMware
# Disable VMware Tools time sync in VM settings

# Hyper-V
Get-VMIntegrationService -VMName "YourVM" -Name "Time Synchronization" | Disable-VMIntegrationService
```

### Issue 3: Large Time Corrections Fail
**Cause**: Windows limits time adjustments to prevent system issues  
**Solution**: The script configures `MaxPosPhaseCorrection` and `MaxNegPhaseCorrection` to 3600 seconds (1 hour). For larger corrections:
```powershell
# Stop service and set time manually if difference > 1 hour
Stop-Service w32time
w32tm /register
Set-Date -Date "2025-10-01 12:00:00"
Start-Service w32time
```

### Issue 4: Domain-Joined Computer Ignores Configuration
**Cause**: Domain Group Policy overrides local settings  
**Detection**: Check registry under `HKLM:\SOFTWARE\Policies\`  
**Solution**: Configure time settings via Group Policy Management Console

## 🔒 Compliance & Audit

### For Regulated Environments

Many compliance frameworks require accurate time synchronization:

| Framework | Requirement | Script Compliance |
|-----------|-------------|-------------------|
| **PCI DSS** | Synchronized time sources | ✅ Uses trusted NTP pools |
| **HIPAA** | Accurate timestamps for audit logs | ✅ Configurable intervals |
| **SOX** | Time synchronization for financial records | ✅ High-precision options |
| **NIST 800-53** | AU-8: Time Stamps | ✅ External authoritative source |
| **ISO 27001** | A.12.4.4: Clock synchronization | ✅ Multiple redundant sources |

### Audit Logging

The script logs all operations. For compliance, consider:

```powershell
# Redirect script output to log file
.\Set-NTPConfig.ps1 -Force | Tee-Object -FilePath "C:\Logs\NTP-Config-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
```

### Validation Script

Create a validation script for periodic compliance checks:

```powershell
# Validate-NTPConfig.ps1
$status = w32tm /query /status
$lastSync = ($status | Select-String "Last Successful Sync Time").ToString()

# Parse last sync time
if ($lastSync -match "(\d{1,2}/\d{1,2}/\d{4} \d{1,2}:\d{2}:\d{2} [AP]M)") {
    $syncTime = [DateTime]::Parse($matches[1])
    $hoursSinceSync = ((Get-Date) - $syncTime).TotalHours
    
    if ($hoursSinceSync -gt 24) {
        Write-Warning "Time not synced in $([Math]::Round($hoursSinceSync, 1)) hours!"
        exit 1
    }
    else {
        Write-Host "Time sync healthy: last synced $([Math]::Round($hoursSinceSync, 1)) hours ago" -ForegroundColor Green
        exit 0
    }
}
```

## 📞 Getting Help

### Before Opening an Issue

1. ✅ Run with `-Verbose` flag for detailed output
2. ✅ Check Windows Event Logs for Time-Service errors
3. ✅ Verify firewall allows UDP 123 outbound
4. ✅ Test NTP server connectivity manually
5. ✅ Review the troubleshooting section above

### When Opening an Issue

Please include:
- Windows version and build number
- PowerShell version (`$PSVersionTable`)
- Complete error message
- Output of `w32tm /query /status`
- Output of `Get-Service w32time | Format-List *`
- Whether system is domain-joined
- Any relevant Group Policy settings

### Community Support

- **Stack Overflow**: Tag questions with `windows-time-service` and `ntp`
- **Reddit**: r/PowerShell and r/sysadmin
- **Microsoft Forums**: Windows Server or Windows 10/11 forums

---

Made with ❤️ for reliable time synchronization
