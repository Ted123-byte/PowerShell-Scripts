
#Name  =  AZURE - Managed Disks.
#Policy Name  =  GCSS - Ensure Azure Managed Disks are blocked to the public.
#Description  =  By default, Azure Managed Disks attached to Virtual Machines should not allow public access.
#Guardrail ID =  CSB_0053


# Parameters
Param (
    [Parameter(Mandatory=$false)]    
    [string]$OutputPath = 'C:\Temp',
    [Parameter(Mandatory=$false)]    
    [Switch]$SelectCurrentSubscription     
)

Function Get-Report {
    param(
        [string]$SubscriptionName,
        [string]$SubscriptionID,
        [string]$RGName,
        [string]$RGType,
        [string]$Location,
        [string]$DiskName,
        [string]$NetworkAccessPolicy,
        [string]$PublicNetworkAccess,
        [string]$Status
    )

    $obj = New-Object PSObject
    $obj | Add-Member -MemberType NoteProperty -Name Date -Value (Get-Date).ToString("MM-dd-yyyy")
    $obj | Add-Member -MemberType NoteProperty -Name SubscriptionName -Value $SubscriptionName
    $obj | Add-Member -MemberType NoteProperty -Name SubscriptionID -Value $SubscriptionID
    $obj | Add-Member -MemberType NoteProperty -Name RGName -Value $RGName
    $obj | Add-Member -MemberType NoteProperty -Name RGType -Value $RGType
    $obj | Add-Member -MemberType NoteProperty -Name Location -Value $Location
    $obj | Add-Member -MemberType NoteProperty -Name DiskName -Value $DiskName
    $obj | Add-Member -MemberType NoteProperty -Name NetworkAccessPolicy -Value $NetworkAccessPolicy
    $obj | Add-Member -MemberType NoteProperty -Name PublicNetworkAccess -Value $PublicNetworkAccess
    $obj | Add-Member -MemberType NoteProperty -Name Status -Value $Status
    return $obj
}

  #Function to set Cell-Color in HTML Table
Function Set-CellColor
{   
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory,Position=0)]
        [string]$Property,
        [Parameter(Mandatory,Position=1)]
        [string]$Color,
        [Parameter(Mandatory,ValueFromPipeline)]
        [Object[]]$InputObject,
        [Parameter(Mandatory)]
        [string]$Filter,
        [switch]$Row
    )
    
    Begin {
        Write-Verbose "$(Get-Date): Function Set-CellColor begins"
        If ($Filter)
        {   If ($Filter.ToUpper().IndexOf($Property.ToUpper()) -ge 0)
            {   $Filter = $Filter.ToUpper().Replace($Property.ToUpper(),"`$Value")
                Try {
                    [scriptblock]$Filter = [scriptblock]::Create($Filter)
                }
                Catch {
                    Write-Warning "$(Get-Date): ""$Filter"" caused an error, stopping script!"
                    Write-Warning $Error[0]
                    Exit
                }
            }
            Else
            {   Write-Warning "Could not locate $Property in the Filter, which is required.  Filter: $Filter"
                Exit
            }
        }
    }
    
    Process {
        ForEach ($Line in $InputObject)
        {   If ($Line.IndexOf("<tr><th") -ge 0)
            {   Write-Verbose "$(Get-Date): Processing headers..."
                $Search = $Line | Select-String -Pattern '<th ?[a-z\-:;"=]*>(.*?)<\/th>' -AllMatches
                $Index = 0
                ForEach ($Match in $Search.Matches)
                {   If ($Match.Groups[1].Value -eq $Property)
                    {   Break
                    }
                    $Index ++
                }
                If ($Index -eq $Search.Matches.Count)
                {   Write-Warning "$(Get-Date): Unable to locate property: $Property in table header"
                    Exit
                }
                Write-Verbose "$(Get-Date): $Property column found at index: $Index"
            }
            If ($Line -match "<tr( style=""background-color:.+?"")?><td")
            {   $Search = $Line | Select-String -Pattern '<td ?[a-z\-:;"=]*>(.*?)<\/td>' -AllMatches
                $Value = $Search.Matches[$Index].Groups[1].Value -as [double]
                If (-not $Value)
                {   $Value = $Search.Matches[$Index].Groups[1].Value
                }
                If (Invoke-Command $Filter)
                {   If ($Row)
                    {   Write-Verbose "$(Get-Date): Criteria met!  Changing row to $Color..."
                        If ($Line -match "<tr style=""background-color:(.+?)"">")
                        {   $Line = $Line -replace "<tr style=""background-color:$($Matches[1])","<tr style=""background-color:$Color"
                        }
                        Else
                        {   $Line = $Line.Replace("<tr>","<tr style=""background-color:$Color"">")
                        }
                    }
                    Else
                    {   Write-Verbose "$(Get-Date): Criteria met!  Changing cell to $Color..."
                        $Line = $Line.Replace($Search.Matches[$Index].Value,"<td style=""background-color:$Color"">$Value</td>")
                    }
                }
            }
            Write-Output $Line
        }
    }
    
    End {
        Write-Verbose "$(Get-Date): Function Set-CellColor completed"
    }
}

# Initialize report collection
$Report = @()

if ($SelectCurrentSubscription) {
    $subscriptions = @(Get-AzContext | Select-Object -ExpandProperty Subscription)
} else {
    $subscriptions = Get-AzSubscription
}

foreach ($subscription in $subscriptions) {
    # Set the context to the current subscription
    Set-AzContext -SubscriptionId $subscription.Id

    Write-Host "Checking subscription: $($subscription.Name) - $($subscription.Id)"

    $disks = Get-AzDisk

    foreach ($disk in $disks) {
        # Assuming the disk object has 'ResourceGroupName' and 'Location' properties
        $RGName = $disk.ResourceGroupName
        $RGType= "Microsoft.Compute/disks"
        $location = $disk.Location


        $networkAccessPolicy = $disk.NetworkAccessPolicy
        $publicNetworkAccess = $disk.PublicNetworkAccess

        if ($networkAccessPolicy -eq "AllowAll" -and $publicNetworkAccess -eq "Enabled") {
            $status = "Open"
        } elseif ($networkAccessPolicy -eq "AllowPrivate" -and $publicNetworkAccess -eq "Disabled") {
            $status = "Disk Access with Private endpoint"
        } elseif ($networkAccessPolicy -eq "DenyAll" -and $publicNetworkAccess -eq "Disabled") {
            $status = "Disabled"
        } else {
            $status = "Unknown or Custom Configuration"
        }

        $Report += Get-Report -SubscriptionName $subscription.Name -SubscriptionID $subscription.Id -RGName $RGName -RGType $RGType -Location $location -DiskName $disk.Name -NetworkAccessPolicy $networkAccessPolicy -PublicNetworkAccess $publicNetworkAccess -Status $status
    }
    Write-Host "Finished checking subscription: $($subscription.Name) - $($subscription.Id)"
    Write-Host "==================================================="
}

# Define Policy Information
$PolicyInfo = @(
    [PSCustomObject]@{
        Detail = "Name"
        Value = "AZURE - Managed Disks."
    },
    [PSCustomObject]@{
        Detail = "Policy Name"
        Value = "GCSS - Ensure Azure Managed Disks are blocked to the public."
    },
    [PSCustomObject]@{
        Detail = "Description"
        Value = "By default, Azure Managed Disks attached to Virtual Machines should not allow public access"
    },
    [PSCustomObject]@{
        Detail = "Guardrail ID"
        Value = "CSB_0053"
    }
)


#Stylesheet for HTML table
$Header = @"
<body>
<br>

<u>Guardrail Metadata:</u><br />

<ul>"Name"  =  AZURE - Managed Disks.</ul> 
<ul>"Policy Name"  =  GCSS - Ensure Azure Managed Disks are blocked to the public.</ul>
<ul>"Description"  =  By default, Azure Managed Disks attached to Virtual Machines should not allow public access.</ul>
<ul>"Guardrail ID" =  CSB_0053.</ul>

<u>NetworkAccessPolicy:</u><br />
<ul>"DenyAll"  =  "Disable public and private access" has been selected.</ul>
<ul>"AllowAll" =  "Enable public access from all networks" is selected.</ul>
<ul>"AllowPrivate" =  "Disable public access and enable private access" is selected.</ul>

<u>PublicNetworkAccess:</u><br />
<ul>"Disabled"  =  JSON Resource Script configured to <b><u>Disabled</u></b>.</ul>
<ul>"Enabled"  =  JSON Resource Script configured to <b><u>Enabled</u></b>.</ul>

<u>Status:</u><br />
<ul><span style='color: #FFa500;'>"Open"</span> =  Disk is accessible from any network, including the public internet. No restrictions in place to prevent external parties from accessing the disk.</ul>
<ul>"Disk Access with Private endpoint"  =  Disk is set up for secure and private connectivity within a specific network environment.</ul>
<ul>"Disabled" = Disk is not accessible from any network or the public internet. This is a secure state that ensures the disk's data is isolated and protected from external access.</ul>

</body>

<br>
<style>
TABLE {border-width: 1px; border-style: solid; border-color: black; background-color: #f2f2f2; border-collapse: collapse;}
TH {border-width: 1px; padding: 3px; border-style: solid; border-color: black; background-color: #99ccff;}
TD {border-width: 1px; padding: 3px; border-style: solid; border-color: black;}
</style>
"@

if ($OutputPath) {
    #Export to CSV file
    Write-Verbose "Exporting HTML file to $OutputPath" -Verbose
    $HTML = $Report | ConvertTo-Html -Head $Header | Set-CellColor -Property "Status" -Color orange -Filter "Status -eq 'Open'"
    $HTMLFileName = "DiskNetworkConfigReport-CA-$(Get-Date -Format "yyyy-MM-dd-HHmmss").html"
    $ExcelFileName = "DiskNetworkConfigReport-CA-$(Get-Date -Format "yyyy-MM-dd-HHmmss").xlsx"


    $HTML | Out-File "$OutputPath\$HTMLFileName"
    $Report | Export-Excel -Path "$OutputPath\$ExcelFileName" -WorksheetName "Disk Details" -AutoSize -TableName "DiskReport" -TableStyle Medium9
    $PolicyInfo | Export-Excel -Path "$OutputPath\$ExcelFileName" -WorksheetName "Guardrail Information" -AutoSize -TableName "GuardrailDetails" -Append -Show -TableStyle Medium9
} 

else {
  
    $Report | Export-Excel -Path ".\SQLSecurityComplianceReport-CA-$(Get-Date -Format "yyyy-MM-dd-HHmmss").xlsx" -WorksheetName "Disk Details" -AutoSize -TableName "DiskReport" -TableStyle Medium9
    $PolicyInfo | Export-Excel -Path ".\SQLSecurityComplianceReport-CA-$(Get-Date -Format "yyyy-MM-dd-HHmmss").xlsx" -WorksheetName "Guardrail Information" -AutoSize -TableName "GuardrailDetails" -Append -Show
}

