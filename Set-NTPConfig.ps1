# Requires admin privileges

# 1. Set trusted, accurate NTP servers
$ntpServers = "time.cloudflare.com,0x9 time.google.com,0x9 time.nist.gov,0x9 time.apple.com,0x9"

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
