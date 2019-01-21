Function Set-HyperVMemoryDump {
    [cmdletbinding()]
    param(
        [string]$ComputerName,
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][Validateset("Kernel","Minidump","ActiveDump","Complete")][string]$Type,
        [PSCredential]$Credential
    )
    

    if (-not($ComputerName)) {
        #if not a remote command assume local
        $ComputerName = $env:COMPUTERNAME
    }
    
    if ($Credential) {
        $session = New-PSSession -ComputerName $ComputerName -Credential $Credential
    } else {
        $session = New-PSSession -ComputerName $ComputerName
    }
    if (-not ($session) ) {
        Write-Error "Could not establish ps session"
    }
    
    Invoke-Command -Session $session -ArgumentList $Type -ScriptBlock {
        Param ([String]$Type)
        $FPPresent = $(Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl -Name FilterPages -ErrorAction SilentlyContinue)
        Switch ($Type) {
            "Kernel" {
                Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl -Name CrashDumpEnabled -Value 0x2
                if ($FPPresent) { 
                    Remove-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl -Name FilterPages -Force
                }
                    
            };
            "Minidump" {
                Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl -Name CrashDumpEnabled -Value 0x3
                if ($FPPresent) { 
                    Remove-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl -Name FilterPages -Force
                }
            };
            "ActiveDump" {
                Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl -Name CrashDumpEnabled -Value 0x1
                if (-not($FPPresent)) { 
                    New-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl -Name FilterPages -Value 0x1 | Out-Null
                } else {
                    Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl -Name FilterPages -Value 0x1
                }

            };
            "Complete" {
                Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl -Name CrashDumpEnabled -Value 0x1
                if ($FPPresent) { 
                    Remove-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl -Name FilterPages -Force | Out-Null
                }
            };
            default {
                Write-Error "Not a valid dump type"
            }
        }
    }
}


function Get-HyperVMemoryDump {
    [cmdletbinding()]
    [outputtype([string])]
    param (
        [string]$ComputerName,
        [PSCredential]$Credential
    )
    if (-not($ComputerName)) {
        #if not a remote command assume local
        $ComputerName = $env:COMPUTERNAME
    }
    if ($Credential) {
        $session = New-PSSession -ComputerName $ComputerName -Credential $Credential
    } else {
        $session = New-PSSession -ComputerName $ComputerName
    }
    if (-not ($session) ) {
        Write-Error "Could not establish ps session"
    }

    Invoke-Command -Session $session -ArgumentList $Type -ScriptBlock {
        $CrashControl = Get-ItemPropertyValue -Path HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl -Name CrashDumpEnabled
        $FPPresent = $(Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl -Name FilterPages -ErrorAction SilentlyContinue)
        if ($FPPresent) { 
            $FPValue = Get-ItemPropertyValue -Path HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl -Name FilterPages 
        } else {
            $FPValue = $null
        }
        
        if (($CrashControl -eq 1) -and -not $FPPresent) { Write-Output "Complete" }
        elseif (($CrashControl -eq 1) -and $FPPresent -and ($FPValue -eq 1)) { Write-Output "ActiveDump" }
        elseif (($CrashControl -eq 2) -and -not $FPPresent ) { Write-Output "Kernel" }
        elseif (($CrashControl -eq 3) -and -not $FPPresent ) { Write-Output "Minidump" }
        else {Write-Output "UnknownType" }    
    }
}


