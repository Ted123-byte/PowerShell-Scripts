#Name  = AZURE - Key Vault 
#Policy Name:GCSS - Ensure Azure Key Vault is not Publicly Accessible
#Description: This policy identifies Azure Key Vault configurations where default is set to 'Allow'. Default should be set to 'Deny' to prevent public access. 
#Guardrail ID = CSB_0142

#Parameters
Param (
    [Parameter(Mandatory=$false)]    
    [string]$OutputPath = 'C:\Temp',
    [Parameter(Mandatory=$false)]    
    [Switch]$SelectCurrentSubscription     
)

#Function to Set table values
Function Get-Report{
    param($ResourceName,$SubscriptionName,$SubscriptionID,$RGName,$RGType,$Location,$defaultAction,$bypass,$virtualNetworkResourceIds)

    $obj = New-Object -TypeName PSObject
    $obj | Add-Member -MemberType NoteProperty -Name Date -value (Get-Date).ToString("MM-dd-yyyy")
    $obj | Add-Member -MemberType NoteProperty -Name ResourceName -Value $ResourceName
    $obj | Add-Member -MemberType NoteProperty -Name SubscriptionName -value $SubscriptionName
    $obj | Add-Member -MemberType NoteProperty -Name SubscriptionID -value $SubscriptionID         
    $obj | Add-Member -MemberType NoteProperty -Name ResourceGroup -Value $RGName
    $obj | Add-Member -MemberType NoteProperty -Name ResourceType -Value $RGType                    
    $obj | Add-Member -MemberType NoteProperty -Name PrimaryLocation -Value $Location
    $obj | Add-Member -MemberType NoteProperty -Name 'Public Access' -Value $publicaccess
    $obj | Add-Member -MemberType NoteProperty -Name 'Firewall Settings' -Value $virtualNetworkResourceIds
    $obj | Add-Member -MemberType NoteProperty -Name 'Firewall Bypass' -Value $bypass
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

#Get Current Context
$CurrentContext = Get-AzContext

#Get Azure Subscriptions
if ($SelectCurrentSubscription) {
    #Only selection current subscription
    Write-Verbose "Only running for selected subscription $($CurrentContext.Subscription.Name)" -Verbose
    $Subscriptions = Get-AzSubscription -SubscriptionId $CurrentContext.Subscription.Id -TenantId $CurrentContext.Tenant.Id

}else {
    Write-Verbose "Running for all subscriptions in tenant" -Verbose
    $Subscriptions = Get-AzSubscription -TenantId $CurrentContext.Tenant.Id | Where-Object {$_.Name -notmatch '.*SBX.*'}
}

$Report = @()

foreach ($Subscription in $Subscriptions) {
    #Choose subscription
    Write-Verbose "Changing to Subscription $($Subscription.Name)" -Verbose


    $Context = Set-AzContext -TenantId $Subscription.TenantId -SubscriptionId $Subscription.Id -Force

    #Loop through resources
    $Resources = Get-AzResource | where resourcetype -eq "Microsoft.KeyVault/vaults"
    Write-Host "Resources for $($Subscription.Name): $($Resources.Count)" 

    foreach($Resource in $Resources) {

        # Get the Key Vault
        $vault = Get-AzKeyVault -VaultName $Resource.Name

        $ntw= $vault.NetworkAcls

        if (($vault.PublicNetworkAccess -eq "Enabled") -and ($ntw.DefaultAction -eq "Deny"))
            {
                $publicaccess = "No access"
            }
        elseif (($vault.PublicNetworkAccess -eq "Disabled") -and ($ntw.DefaultAction -eq "Deny"))
            {
                $publicaccess = "No access"
            }
            elseif (($vault.PublicNetworkAccess -eq $null) -and ($ntw.DefaultAction -eq "Deny"))
            {
                $publicaccess = "No access"
            }
            else
            {
                $publicaccess = "Open"
            }

        If ($ntw.Bypass -eq "AzureServices") {
            $bypass = "Enabled"
        }
        Elseif ($ntw.Bypass -eq "None") {
            $bypass = "Disabled"
        }
        
        $virtualNetworkResourceIds = $ntw.VirtualNetworkResourceIds

        # Check if virtual network resource IDs is empty
        if (!$virtualNetworkResourceIds) {$virtualNetworkResourceIds = "Misconfigured"}
        
        else {
        $virtualNetworkResourceIds = "Configured" 
    }

        $Report += Get-Report $Resource.Name $Context.Subscription.Name $Context.Subscription.SubscriptionId $Resource.ResourceGroupName $Resource.ResourceType $Resource.Location $publicaccess $bypass $virtualNetworkResourceIds
        
    }
}

# Define Policy Information
$PolicyInfo = @(
    [PSCustomObject]@{
        Detail = "Name"
        Value = "AZURE - Key Vault."
    },
    [PSCustomObject]@{
        Detail = "Policy Name"
        Value = "GCSS - Ensure Azure Key Vault is not Publicly Accessible."
    },
    [PSCustomObject]@{
        Detail = "Description"
        Value = "This policy identifies Azure Key Vault configurations where default is set to 'Allow'. Default should be set to 'Deny' to prevent public access."
    },
    [PSCustomObject]@{
        Detail = "Guardrail ID"
        Value = "CSB_0142"
    }
)

#Stylesheet for HTML table
$Header = @"
<body>
<br>

<ul>"Name"  =  AZURE - Key Vault.</ul> 
<ul>"Policy Name"  =  GCSS - Ensure Azure Key Vault is not Publicly Accessible.</ul>
<ul>"Description"  =  This policy identifies Azure Key Vault configurations where default is set to 'Allow'. Default should be set to 'Deny' to prevent public access.</ul>
<ul>"Guardrail ID" =  CSB_0142.</ul>

<u>Public Access:</u><br />
<ul>"No Access"  =  Either "Allow public access from specific virtual networks and IP addresses" or "Disable public access" is selected.</ul>
<ul><span style='color: #FF0000;'>"Open"</span>  =  The Key Vault is publicly accessible.</ul><br />

<u>Firewall Settings:</u><br />
<ul>"Configured"  =  The "Allow public access from specific virtual networks and IP addresses" is selected and vNet/subnet(s) are configured to connect to your resource securely and directly using service endpoints.</ul>
<ul><span style='color: #FFa500;'>"Misconfiguration"</span>  =  The "Allow public access from specific virtual networks and IP addresses" is selected but <b><u>NO</u></b> vNet/subnet(s) are configured.</ul><br />

<u>Firewall Bypass:</u><br />
<ul>"Enabled"  =  Enabling access to resources allow trusted Microsoft services to bypass the firewall.</ul>
<ul><span style='color: #0000FF;'>"Disabled"</span>  =  Disabling access to resources for trusted Microsoft services.</ul>

<ul>    
<b><u>NOTE:</u></b> If this feature is "Disabled", the Key Vault <b><u>will not</u></b> be able to perform the following actions: <br />
<br>
<li>Specifies whether Azure Virtual Machines are permitted to retrieve certificates stored as secrets from the key vault.</li>
<li>Specifies whether Azure Resource Manager is permitted to retrieve secrets from the key vault.</li>
<li>Specifies whether Azure Disk Encryption is permitted to retrieve secrets from the vault and unwrap keys.</li>
</ul>
<br />

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
    $HTML = $HTML = $Report | Sort-Object -Property ResourceType | ConvertTo-Html -Head $Header | Set-CellColor -Property "Public Access" -Color Red -Filter "Public Access -eq 'Open'" | Set-CellColor -Property "Firewall Settings" -Color orange -Filter "Firewall Settings -eq 'Misconfigured'" | Set-CellColor -Property "Firewall Bypass" -Color blue -Filter "Firewall Bypass -eq 'Disabled'"
    $HTMLFileName = "KeyVaultcReport-CA-$(Get-Date -Format "yyyy-MM-dd-HHmmss").html"
    $ExcelFileName = "KeyVaultReport-CA-$(Get-Date -Format "yyyy-MM-dd-HHmmss").xlsx"


    $HTML | Out-File "$OutputPath\$HTMLFileName"
    $Report | Export-Excel -Path "$OutputPath\$ExcelFileName" -WorksheetName "Key Vault Details" -AutoSize -TableName "KeyVaultReport" -TableStyle Medium9
    $PolicyInfo | Export-Excel -Path "$OutputPath\$ExcelFileName" -WorksheetName "Guardrail Information" -AutoSize -TableName "GuardrailDetails" -Append -Show -TableStyle Medium9
} 

else {
  
    $Report | Export-Excel -Path ".\KeyVaultComplianceReport-CA-$(Get-Date -Format "yyyy-MM-dd-HHmmss").xlsx" -WorksheetName "Key Vault Details" -AutoSize -TableName "Key Vault Public Report" -TableStyle Medium9
    $PolicyInfo | Export-Excel -Path ".\KeyVaultComplianceReport-CA-$(Get-Date -Format "yyyy-MM-dd-HHmmss").xlsx" -WorksheetName "Guardrail Information" -AutoSize -TableName "GuardrailDetails" -Append -Show
}

