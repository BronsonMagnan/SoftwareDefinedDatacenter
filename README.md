# SoftwareDefinedDatacenter

CrashDumpConfig.ps1 - Contains two functions for configuring the type of crash dump to create on stop error.


`Set-HyperVMemoryDump [-ComputerName] [-Credential] -Type (Kernel|Minidump|ActiveDump|Complete)` This will set the crash dump method on a local or remote hyper-v host.


`Get-HyperVMemoryDump [-ComputerName] [-Credential]` Returns the crash dump method on a local or remote hyper-v host, using the same format as the Type parameter
