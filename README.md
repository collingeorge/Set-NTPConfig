# Set-NTPConfig
Accurate Time for Windows 11

Download and run:

powershell -ExecutionPolicy Bypass -File "C:\Path\To\Set-NTPConfig.ps1"


Check configuration:

w32tm /query /status


Example output:

The command completed successfully.
Sending resync command to local computer
The command completed successfully.

--- CURRENT TIME CONFIGURATION ---
[Configuration]

EventLogFlags: 2 (Local)
AnnounceFlags: 5 (Local)
TimeJumpAuditOffset: 28800 (Local)
MinPollInterval: 6 (Local)
MaxPollInterval: 6 (Local)
MaxNegPhaseCorrection: 54000 (Local)
MaxPosPhaseCorrection: 54000 (Local)
MaxAllowedPhaseOffset: 0 (Local)

FrequencyCorrectRate: 2 (Local)
PollAdjustFactor: 5 (Local)
LargePhaseOffset: 50000000 (Local)
SpikeWatchPeriod: 900 (Local)
LocalClockDispersion: 10 (Local)
HoldPeriod: 5 (Local)
PhaseCorrectRate: 1 (Local)
UpdateInterval: 256 (Local)


[TimeProviders]

NtpClient (Local)
DllName: C:\WINDOWS\SYSTEM32\w32time.DLL (Local)
Enabled: 1 (Local)
InputProvider: 1 (Local)
AllowNonstandardModeCombinations: 1 (Local)
ResolvePeerBackoffMinutes: 15 (Local)
ResolvePeerBackoffMaxTimes: 7 (Local)
CompatibilityFlags: 2147483648 (Local)
EventLogFlags: 1 (Local)
LargeSampleSkew: 3 (Local)
SpecialPollInterval: 64 (Local)
Type: NTP (Local)
NtpServer: time.cloudflare.com,0x9 time.google.com,0x9 time.nist.gov,0x9 time.apple.com,0x9 (Local)

NtpServer (Local)
DllName: C:\WINDOWS\SYSTEM32\w32time.DLL (Local)
Enabled: 0 (Local)
InputProvider: 0 (Local)


Leap Indicator: 0(no warning)
Stratum: 1 (primary reference - syncd by radio clock)
Precision: -23 (119.209ns per tick)
Root Delay: 0.0000000s
Root Dispersion: 10.0000000s
ReferenceId: 0x4C4F434C (source name:  "LOCL")
Last Successful Sync Time: 5/30/2025 09:06:45
Source: Local CMOS Clock
Poll Interval: 6 (64s)

PS C:\WINDOWS\system32> w32tm /query /status
Leap Indicator: 0(no warning)
Stratum: 2 (secondary reference - syncd by (S)NTP)
Precision: -23 (119.209ns per tick)
Root Delay: 0.0000000s
Root Dispersion: 10.0000000s
ReferenceId: 0x84A36102 (source IP:  132.163.97.2)
Last Successful Sync Time: 5/30/2025 09:07:01
Source: time.nist.gov,0x9
Poll Interval: 6 (64s)
