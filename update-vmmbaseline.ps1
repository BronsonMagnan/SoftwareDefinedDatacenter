#Run me on the VMM server

$baselines = @(
    "SQL",
    "Runtimes",
    "Office2016",
    "Office2010",
    "Server2016",
    "Defender",
    "MSRT",
    "Silverlight",
    "SystemCenter",
    "zOther",
    "Exchange2016",
    "WindowsAdminCenter",
    "AdvancedThreatAnalytics"
); #end baselines
$baselines = $baselines | sort


#Make the baselines if they do not exist
foreach ($baseline in $baselines) {
    $testbaseline = Get-SCBaseline | where {$_.name -eq $baseline}
    Write-Host "Checking if baseline exists $baseline :" -NoNewline
    if (-not($testbaseline)) {
        write-host -ForegroundColor Red "False"
        New-SCBaseline -Name $baseline
    } else {
        Write-Host -ForegroundColor Green "True"
    }
}

write-host "Getting valid updates"
$ValidUpdates = Get-SCUpdate  | Where-Object {$_.IsDeclined -eq $false} |Where-Object {$_.IsExpired -eq $false} | Where-Object {$_.IsSuperseded -eq $false} 
Write-Host "Found $($ValidUpdates.Count) valid updates"

foreach ($baseline in ($baselines| where {$_ -ne "zOther"})) {
    Write-Host "Processing updates for baseline $baseline"
    switch ($baseline) {
        "SQL" {
            $updatesForThisBaseline = @()
            $updatesForThisBaseline = $ValidUpdates | where {$_.ProductFamilies -like "SQL Server"}
            $ValidUpdates = $ValidUpdates | where {$_ -notin $updatesForThisBaseline}
            break;
        }; 
        "Runtimes" {
            $updatesForThisBaseline = @()
            $updatesForThisBaseline = $ValidUpdates | where {$_.ProductFamilies -like "Developer Tools, Runtimes, and Redistributables" }
            $ValidUpdates = $ValidUpdates | where {$_ -notin $updatesForThisBaseline}
            break;
        }; 
        "Office2016" {
            $updatesForThisBaseline = @()
            $updatesForThisBaseline = $ValidUpdates | where {$_.Products -like "Office 2016"}
            $ValidUpdates = $ValidUpdates | where {$_ -notin $updatesForThisBaseline}
            break;
        }; 
        "Office2010" {
            $updatesForThisBaseline = @()
            $updatesForThisBaseline = $ValidUpdates | where {$_.Products -like "Office 2010"}
            $ValidUpdates = $ValidUpdates | where {$_ -notin $updatesForThisBaseline}
            break;
        }; 
        "Server2016" {
            $updatesForThisBaseline = @()
            $updatesForThisBaseline = $ValidUpdates | where {$_.Products -like "Windows Server 2016" -and $_.Name -notlike "*(1709)*" -and $_.Name -notlike "*(1803)*" -and $_.name -notlike "*Windows Server Next*"}
            $ValidUpdates = $ValidUpdates | where {$_ -notin $updatesForThisBaseline}
            break;
        }; 
        "Defender" {
            $updatesForThisBaseline = @()
            $updatesForThisBaseline = $ValidUpdates | where {$_.Products -like "Windows Defender"}
            $ValidUpdates = $ValidUpdates | where {$_ -notin $updatesForThisBaseline}
            break;
        }; 
        "MSRT" {
            $updatesForThisBaseline = @()
            $updatesForThisBaseline = $ValidUpdates | where {$_.Name -like "Windows Malicious Software Removal Tool x64*"}
            $ValidUpdates = $ValidUpdates | where {$_ -notin $updatesForThisBaseline}
            break;
        }; 
        "Silverlight" {
            $updatesForThisBaseline = @()
            $updatesForThisBaseline = $ValidUpdates | where {$_.Name -like "*Silverlight*"}
            $ValidUpdates = $ValidUpdates | where {$_ -notin $updatesForThisBaseline}
            break;
        }; 
        "SystemCenter" {
            $updatesForThisBaseline = @()
            $updatesForThisBaseline = $ValidUpdates | where {$_.ProductFamilies -like "System Center" -or $_.name -like "*Data Protection*"}
            $ValidUpdates = $ValidUpdates | where {$_ -notin $updatesForThisBaseline}
            break;
        }; 
        "Exchange2016" {
            $updatesForThisBaseline = @()
            $updatesForThisBaseline = $ValidUpdates | where {$_.Products -like "*Exchange*2016*"}
            $ValidUpdates = $ValidUpdates | where {$_ -notin $updatesForThisBaseline}
            break;
        };
        "WindowsAdminCenter" {
            $updatesForThisBaseline = @()
            $updatesForThisBaseline = $ValidUpdates | where {$_.Products -like "*admin*center*"}
            $ValidUpdates = $ValidUpdates | where {$_ -notin $updatesForThisBaseline}
            break;
        };
        "AdvancedThreatAnalytics" {
            $updatesForThisBaseline = @()
            $updatesForThisBaseline = $ValidUpdates | where {$_.Products -like "*threat*"}
            $ValidUpdates = $ValidUpdates | where {$_ -notin $updatesForThisBaseline}
            break;
        };

    } #end switch
    
    #Filter out superscedence - skip this for Defender and MSRT updates, and Exchange, this technique does not work for them
    if (-not ($baseline -eq "Defender" -or $baseline -eq "MSRT" -or $baseline -like "*exchange*")) {
        $OldKBList = @()
        foreach ($update in $updatesForThisBaseline) { 
            if ($update.UpdatesSuperseded) { 
               #this is a string varible
               $OldKBList += $update.UpdatesSuperseded.split(",").trim()
            }
        }
        $OldKBList = $OldKBList | sort | sort -Unique
        #Now make sure we remove any updates that really are superseded, but WSUS does not report
        $updatesForThisBaseline = $updatesForThisBaseline | where {$OldKBList -notcontains $_.KBArticle}
    } # end supersedence filter

    #Handle MSRT supersedence by release date
    if ($baseline -eq "MSRT") {
        $CreationDates = @()
        foreach ($update in $updatesForThisBaseline) { 
            $CreationDates += ("{0:yyyyMMdd}" -f $update.CreationDate )
        }
        #Sorting raw datetime objects does not work, so converting to a string that will.
        $newestDate = $CreationDates | sort -Descending | select -First 1
        $updatesForThisBaseline = $updatesForThisBaseline | where {  ("{0:yyyyMMdd}" -f $_.CreationDate) -eq $newestDate}
    } # end MSRT supersedence filter


    Write-Output "Valid updates for baseline $baseline is $($updatesForThisBaseline.count)"
    $thisbaseline = Get-SCBaseline -Name $baseline
    if ($thisbaseline.UpdateCount -ne 0) {
        Write-Host "Removing $($thisbaseline.UpdateCount) existing updates from baseline $($thisbaseline.Name)"
        $thisbaseline | Set-SCBaseline -RemoveUpdates $( $thisbaseline.Updates ) | Out-Null
    }
    Write-Host "Refreshing $($updatesForThisBaseline.count) updates from baseline $($thisbaseline.Name)"
    $thisbaseline | Set-SCBaseline -AddUpdates $updatesForThisBaseline | Out-Null
}


