#Connect in using powershell direct
$vm = "PatchTest"
$pass = ConvertTo-SecureString -AsPlainText -Force -String "insert_vm_admin_password_here"
$cred = [PSCredential]::new("WIN0NTQF3MDETA\Administrator",$pass)
$session = New-PSSession -VMName $vm -Credential $cred
if (-not ($session) ) { Write-Error "Could not connect to VM"; exit }

#get list of current drivers
$CurrentDrivers = Invoke-Command -Session $session -ScriptBlock {
    Get-ChildItem -Path C:\windows\System32\drivers -Filter *.sys
}


foreach ($driver in $CurrentDrivers) {
    $CurrentVersion = if ($driver.VersionInfo -match "FileVersion:\s+\d+.\d+.\d+.\d+") { [VERSION](($matches[0]).replace("FileVersion:","").trim()) } else {$null}

    #Search for copies in the SXS store.
    $SXSResults = invoke-command -Session $session -ArgumentList $driver.name -ScriptBlock {
        param($drivername)
        Get-ChildItem -Path C:\windows\WinSxS -Filter $drivername -Recurse
    }

    $multipleversions = @()
    foreach ($sxsresult in $SXSResults) { 
        $thisVersion = if ($sxsresult.VersionInfo -match "FileVersion:\s+\d+.\d+.\d+.\d+") { [VERSION](($matches[0]).replace("FileVersion:","").trim()) } else {$null}
        $multipleVersions += $thisVersion
    }
    $multipleVersions = $multipleVersions | sort 
    $CV = $true;
    foreach ($version in $multipleversions) { 
        if ($CurrentVersion -lt $version) {
            #version is fine, active is bad
            $CV = $false;
        }
    } 
    if ($CV) { 
        Write-Host "Active Driver $($driver.name) - version $($CurrentVersion)" -ForegroundColor Green 
    } else {
        Write-Host "Active Driver $($driver.name) - version $($CurrentVersion)" -ForegroundColor Red
    }
    foreach ($version in $multipleversions) { 
        if ($CV) {
            Write-Host "WinSXS Driver $($driver.name) - version $($Version)" -ForegroundColor Gray
        } else {
            if ($CurrentVersion -lt $version) {
                Write-Host "WinSXS Driver $($driver.name) - version $($Version)" -ForegroundColor Yellow
            } else {
                Write-Host "WinSXS Driver $($driver.name) - version $($Version)" -ForegroundColor Gray
            }
        }
        
    }

}

