# ⚙️ Windows High-Precision NTP Configuration Script

This PowerShell script configures **secure**, **accurate**, and **frequent** time synchronization on **Windows 10/11** systems using reliable public NTP servers.

---

## 🚀 Features

- ✅ Sets **trusted stratum 1 NTP servers** (Cloudflare, Google, NIST, Apple)
- ✅ Polls every **~60 seconds** for high accuracy
- ✅ Applies recommended `0x9` flags (SpecialInterval + Client)
- ✅ Forces immediate time sync
- ✅ Ensures Windows Time service is configured and running
- ✅ Ideal for environments requiring **tight time precision** (e.g. financial systems, monitoring, logging)

---

## 🔒 Trusted NTP Servers Used

| Server                | Organization    | Notes                           |
|-----------------------|-----------------|---------------------------------|
| `time.cloudflare.com` | Cloudflare      | Low-latency, global network     |
| `time.google.com`     | Google          | Secure, stratum 1               |
| `time.nist.gov`       | NIST (US Gov)   | Official US atomic time         |
| `time.apple.com`      | Apple           | Stable and widely distributed   |

All servers are configured with `,0x9` flag:  
> `0x9 = SpecialInterval (0x1) + Client Mode (0x8)`

---

## 📜 Script Contents

```powershell
# Set secure, high-precision NTP configuration on Windows
$ntpServers = "time.cloudflare.com,0x9 time.google.com,0x9 time.nist.gov,0x9 time.apple.com,0x9"

# Configure NTP parameters
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -Name "NtpServer" -Value $ntpServers
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -Name "Type" -Value "NTP"

# Set frequent sync interval (64 seconds)
$ntpClientPath = "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpClient"
Set-ItemProperty -Path $ntpClientPath -Name "SpecialPollInterval" -Value 64 -Type DWord
Set-ItemProperty -Path $ntpClientPath -Name "Enabled" -Value 1 -Type DWord

# Ensure Windows Time service is enabled
Set-Service w32time -StartupType Automatic
Restart-Service w32time

# Apply changes and force sync
w32tm /config /update
Start-Sleep -Seconds 3
w32tm /resync /nowait

# Output config and status
w32tm /query /configuration
w32tm /query /status
````


## 🧪 Usage
🖱️ Option 1: Run Directly
  - ✅ Open PowerShell as Administrator
  - ✅ Paste the script and press Enter

## 📁 Option 2: Save and Run as .ps1
  - ✅ Save script as Set-NTPConfig.ps1
  - ✅ Run it with powershell:

```
powershell -ExecutionPolicy Bypass -File "C:\Path\To\Set-NTPConfig.ps1"
```

## 📊 Verify Sync Status
After running the script, check time sync with:

```
w32tm /query /status
```
Expected output includes:

Source: one of the configured NTP servers

Stratum: 2 (synced from a stratum 1 server)

Last Successful Sync Time: recent timestamp

Poll Interval: 64 seconds


## 📁 Optional Commands
| Task                    | Command                                                          |
| ----------------------- | ---------------------------------------------------------------- |
| View current peers      | `w32tm /query /peers`                                            |
| Sync test to NTP server | `w32tm /stripchart /computer:time.nist.gov /samples:5 /dataonly` |
| Show config summary     | `w32tm /query /configuration`                                    |


## 🛠️ Requirements
Windows 10 / 11

Admin privileges

PowerShell 5.0+ (built-in)

## 📥 Contribute

Have a trustworthy threat feed to recommend? Submit a pull request or open an issue.

## 📜 License
MIT License

## 🙋‍♂️ Support
Need help with .reg, .bat, .exe, or GPO/Intune deployment?
Open an issue or PR and we’ll assist you!


