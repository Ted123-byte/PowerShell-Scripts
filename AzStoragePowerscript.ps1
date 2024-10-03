# Define input parameters
Param (
    [Parameter(Mandatory=$false)]    
    [string]$OutputPath = 'C:\Temp',
    [Parameter(Mandatory=$false)] # Optional switch to select current subscription only
    [Switch]$SelectCurrentSubscription
)

# Start the main process inside a try-catch to handle errors
try {
    # Check the provided SelectCurrentSubscription switch and get appropriate subscriptions
    $subscriptions = if ($SelectCurrentSubscription) {
        Write-Host "Running for current subscription"
        # Get the current Azure subscription
        Get-AzContext | Select-Object -ExpandProperty Subscription
    } else {
        Write-Host "Running for all subscriptions"
        # Get all Azure subscriptions
        Get-AzSubscription
    }

    
    Write-Host "Retrieved $($subscriptions.Count) subscriptions"

    # Initialize an array to hold result data
    $results = @()

    # Process each subscription
    foreach ($subscription in $subscriptions) {
        Write-Host "Processing subscription: $($subscription.SubscriptionName)"
        # Set the current Azure context to the subscription being processed
        Set-AzContext -SubscriptionId $subscription.Id

        # Initialize dictionaries to hold mapping between storage accounts and associated app services/SQL servers/batch service
        $storageAccountAppServices = @{}
        $sqlServerStorageAccounts = @{}
        $batchStorageAccountAssociations = @{}
       $storageWorkspaceAssociations = @{}


        # Get all resource groups in the subscription
        $resourceGroups = Get-AzResourceGroup

    # Initialize a dictionary to hold the mapping between boot diagnostics storage accounts and associated VMs
    $bootDiagStorageAccountVms = @{}



# Process each resource group in the subscription
foreach ($resourceGroup in $resourceGroups) {
    # Retrieve all VMs in the current resource group
    $vms = Get-AzVM -ResourceGroupName $resourceGroup.ResourceGroupName

    foreach ($vm in $vms) {
        # Determine if the VM uses Managed or Unmanaged Disks
        $diskType = if ($vm.StorageProfile.OsDisk.ManagedDisk -ne $null) { "Managed" } else { "Unmanaged" }
        $vhdUri = if ($diskType -eq "Unmanaged") { $vm.StorageProfile.OsDisk.Vhd.Uri } else { "N/A" }
        
        # Check Boot Diagnostics Status
        $diagEnabled = $vm.DiagnosticsProfile.BootDiagnostics.Enabled
        $diagStorageUri = if ($diagEnabled) { $vm.DiagnosticsProfile.BootDiagnostics.StorageUri } else { "N/A" }
        $storageAccountName = if ($diagEnabled) { (($diagStorageUri -split '://')[1] -split '\.')[0] } else { "N/A" }

        Write-Host "      Boot Diagnostics Storage Account Name: $storageAccountName"
        Write-Host "VM Name: $($vm.Name)"
        Write-Host "                    "

        # Store the association between the VM and its boot diagnostics storage account
        if (-not $bootDiagStorageAccountVms.ContainsKey($storageAccountName)) {
            $bootDiagStorageAccountVms[$storageAccountName] = @()
        }
        $bootDiagStorageAccountVms[$storageAccountName] += $vm.Name
    }
}


           
          
        # Retrieve all App Services and SQL Servers in the subscription
        $allAppServices = Get-AzWebApp
        $allSQLServers = Get-AzSqlServer

        # Process each App Service to identify associated storage accounts
        foreach ($appService in $allAppServices) {
            # Get production slot settings for the App Service
            $appSettings = Get-AzWebAppSlot -ResourceGroupName $appService.ResourceGroup -Name $appService.Name -Slot Production
            # Identify the storage setting in App Settings
            $storageSetting = $appSettings.SiteConfig.AppSettings | Where-Object { $_.Name -eq 'AzureWebJobsStorage' }
            # Extract storage account name from the setting value
            $appServiceStorageAccountName = $storageSetting.Value -split ';' | Where-Object { $_ -like 'AccountName=*' } | ForEach-Object { ($_ -split '=')[1] }

            # If an associated storage account is found, add it to the dictionary
            if ($appServiceStorageAccountName) {
                if (-not $storageAccountAppServices.ContainsKey($appServiceStorageAccountName)) {
                    $storageAccountAppServices[$appServiceStorageAccountName] = @()
                }
                $storageAccountAppServices[$appServiceStorageAccountName] += $appService
            }
        }

        # Process each SQL Server to identify associated storage accounts
        foreach ($sqlServer in $allSQLServers) {
            # Get audit settings for the SQL Server
            $audits = Get-AzSqlServerAudit -ResourceGroupName $sqlServer.ResourceGroupName -ServerName $sqlServer.ServerName

            foreach ($audit in $audits) {
                # Extract storage account name from the audit resource ID
                $splitResourceId = $audit.StorageAccountResourceId -split '/'
                $sqlServerStorageAccountName = $splitResourceId[-1]

                # If an associated storage account is found, add it to the dictionary
                if ($sqlServerStorageAccountName) {
                    if (-not $sqlServerStorageAccounts.ContainsKey($sqlServerStorageAccountName)) {
                        $sqlServerStorageAccounts[$sqlServerStorageAccountName] = @()
                    }
                    $sqlServerStorageAccounts[$sqlServerStorageAccountName] += $sqlServer
                }
            }
        }

# Retrieve all Azure Batch accounts in the current subscription
$batchAccounts = Get-AzBatchAccount

if ($batchAccounts.Count -eq 0) {
    Write-Host "  No Azure Batch accounts found in this subscription."
} else {
    Write-Host "  Found $($batchAccounts.Count) Azure Batch account(s) in subscription $($subscription.Name)."
    
    foreach ($batchAccount in $batchAccounts) {
        Write-Host "    Checking Batch account: $($batchAccount.AccountEndpoint)"
        
        $storageAccount = 'Not Set'
        if ($batchAccount.AutoStorageProperties -or $batchAccount.AutoStorage.StorageAccountId) {
            $storageAccountId = $batchAccount.AutoStorageProperties.StorageAccountId
            # Extract the storage account name from its ID
            $storageAccount = $storageAccountId.Split('/')[-1]
        } else {
            Write-Host "      No linked storage account or AutoStorage not configured for this Batch account."
        }
        
        # Store the association between the Batch account and its storage account name
        if (-not $batchStorageAccountAssociations.ContainsKey($storageAccount)) {
            $batchStorageAccountAssociations[$storageAccount] = @()
        }
        $batchStorageAccountAssociations[$storageAccount] += $batchAccount

        Write-Host "      Linked Storage Account Name: $storageAccount"
    }
}






# Retrieve all Azure Machine Learning workspaces in the current subscription using the specific command
$mlWorkspaces = Get-AzMLWorkspace

if ($mlWorkspaces -eq $null -or $mlWorkspaces.Count -eq 0) {
    Write-Host "  No Azure Machine Learning workspaces found in this subscription."
} else {
    Write-Host "  Found $($mlWorkspaces.Count) Azure Machine Learning workspace(s) in the subscription."

    foreach ($workspace in $mlWorkspaces) {
        Write-Host "  Checking Machine Learning Workspace: $($workspace.Name) in Resource Group: $($workspace.ResourceGroupName)"
        
        # Check for linked storage account
        $storageAccountName = 'None' # Default if no storage account is linked
        if ($workspace.StorageAccount -ne $null) {
            # Extract the storage account name from its URI
            $storageAccountName = $workspace.StorageAccount.Split('/')[-1]
        } else {
            Write-Host "    No storage account linked to this Machine Learning workspace."
        }

        # Store the association in the hashtable
        if (-not $storageWorkspaceAssociations.ContainsKey($storageAccountName)) {
            $storageWorkspaceAssociations[$storageAccountName] = @()
        }
        $storageWorkspaceAssociations[$storageAccountName] += $workspace

        # Output the storage account name
        Write-Host "    Linked Storage Account Name: $storageAccountName"
    }

    # Output the full dictionary of associations
    Write-Host "Storage Account to Workspace Associations:"
    $storageWorkspaceAssociations.GetEnumerator() | ForEach-Object {
        Write-Host "  Storage Account: $($_.Key) is linked to Workspace(s): $($_.Value.Name -join ', ')"
    }
}



#additonal storage association must be done here
   



        # Retrieve all storage accounts in the subscription
        $storageAccounts = Get-AzStorageAccount
        Write-Host "Retrieved $($storageAccounts.Count) storage accounts for $($subscription.SubscriptionName)"

        # Process each storage account
        foreach ($storageAccount in $storageAccounts) {
            Write-Host "Checking storage account: $($storageAccount.StorageAccountName)"
            # Collect storage account settings
        $publicNetworkAccess = $storageAccount.publicNetworkAccess
        $defaultaction = $storageAccount.NetworkRuleSet.DefaultAction
        $allowBlobPublicAccess = $storageAccount.AllowBlobPublicAccess
        $bypass = $storageAccount.NetworkRuleSet.Bypass
        $minimumTlsVersion = $storageAccount.MinimumTlsVersion
        $encryptionServices = $storageAccount.Encryption.Services
        $networkRuleSet = $storageAccount.routingPreference.routingChoice
        $allServicesEncrypted = $true
        $virtualNetworkAttached = "Not Configured" 
        $AccountVer = $storageAccount.kind
       

# Construct the Resource ID for the storage account
        $resourceId = "/subscriptions/$($subscription.Id)/resourceGroups/$($storageAccount.ResourceGroupName)/providers/Microsoft.Storage/storageAccounts/$($storageAccount.StorageAccountName)"

        # Check for Private Endpoint Connections
        $privateEndpoints = Get-AzResource -ResourceId $resourceId -ExpandProperties | Select-Object -ExpandProperty Properties | Select-Object -ExpandProperty privateEndpointConnections

        # Determine if Private Endpoint is used
        $usesPrivateEndpoint = if ($privateEndpoints -or $privateEndpoints.Count -gt 0) { "Yes" } else { "No" }


# Determine the version based on the Kind property
if ($storageAccount.Kind -eq "StorageV2") {
    $AccountVer = "V2"
} elseif ($storageAccount.Kind -eq "Storage") {
    $AccountVer = "V1"
} else {
    $AccountVer = "Unknown"
}

# Categorize storage account based on its name
$category = "General" # Default category
if ($storageAccount.StorageAccountName -like "*veeam*") {
    $category = "Backup"
} elseif ($storageAccount.StorageAccountName -like "*diag*") {
    $category = "Boot Diagnostic"
}
elseif ($storageAccount.StorageAccountName -like "*bkup*") {
    $category = "Backup"
}
   # Ensure $publicNetworkAccess is set to "Enabled" if it's null
if ($null -eq $publicNetworkAccess) {
    $publicNetworkAccess = "Enabled"
}

# Determine public network access description based on properties
if ($publicNetworkAccess -eq "Enabled" -and $defaultAction -eq "Deny") {
    $publicNetworkAccessDescription = "Enabled from selected virtual networks and IP addresses"
} else {
    $publicNetworkAccessDescription = $publicNetworkAccess
}
        # Check each service encryption
        if ($encryptionServices.Blob.Enabled -ne $true) { $allServicesEncrypted = $false }
        if ($encryptionServices.File.Enabled -ne $true) { $allServicesEncrypted = $false }
        if ( $encryptionServices.Table.Enabled -ne $true) { $allServicesEncrypted = $false }
        if ($encryptionServices.Queue.Enabled -ne $true) { $allServicesEncrypted = $false }

        if ($allServicesEncrypted -eq $false){
            $allencrypt= "Partially Configured"
             } else {
        $allencrypt = "Fully Configured"
    }

     # Check for virtual network rules configured for the storage account
    if ($storageAccount.NetworkRuleSet.VirtualNetworkRules.Count -gt 0) {
        $virtualNetworkAttached = "Configured"
    } else {
        $virtualNetworkAttached = "Not Configured"
    }


     # Check if routingPreference is set
    if ($null -ne $storageAccount.routingPreference) {
        $routingChoice = "Defined"
    } else {
        # Assume default routing or mark as not configured
        $routingChoice = "Unidentified"
    }


            # Check for associated app services and SQL servers and VM and Batch Service
            $associatedVMNames = $bootDiagStorageAccountVms[$storageAccount.StorageAccountName]
            $associatedAppServices = $storageAccountAppServices[$storageAccount.StorageAccountName]
            $associatedSQLServers = $sqlServerStorageAccounts[$storageAccount.StorageAccountName]
            $associatedBSServers = $batchStorageAccountAssociations[$storageAccount.StorageAccountName]
            $associatedMLServers =$storageWorkspaceAssociations[$storageAccount.StorageAccountName]

# Retrieve associated VM names for the current storage account

    if ($associatedVMNames) {
        foreach ($vmName in $associatedVMNames) {
            $obj = [PSCustomObject]@{
                StorageAccountName = $storageAccount.StorageAccountName
                'StorageUseCase' = "Virtual Machine"
                'Service Name' = $vmName  # Correctly use the VM name from the list
                PublicNetworkAccess = $publicNetworkAccessDescription
                AllowBlobAnonymousAccess = $allowBlobPublicAccess
                RoutingChoice = $routingChoice
                Encryption = $allencrypt
                FirewallBypass = $bypass
                VirtualNetwork = $virtualNetworkAttached
                AccountVer = $AccountVer
                MinimumTlsVersion = $minimumTlsVersion
               usesPrivateEndpoint =$usesPrivateEndpoint
            }

            $results += $obj
        }
    } 

            # If app services are associated with the storage account, process them
            # Check if there are any associated app services
elseif ($associatedAppServices) {
    foreach ($appService in $associatedAppServices) {
        # Identify the type of the app service (web app, function app, logic app)
        $appSettings = Get-AzWebAppSlot -ResourceGroupName $appService.ResourceGroup -Name $appService.Name -Slot Production
        $appSettingsNames = $appSettings.SiteConfig.AppSettings.Name

        # Determine the app type based on certain app settings
        if ($appSettingsNames -contains "APP_KIND") {
            $appType = "Logic App"
        } elseif ($appSettingsNames -contains "FUNCTIONS_EXTENSION_VERSION" ) {
            $appType = "Function App"
        } else {
            $appType = "Web App"
        }

        Write-Host "App Service $($appService.Name) is a $appType"

        # Create a custom PowerShell object to hold the data and add it to the results
        $obj = [PSCustomObject]@{
            StorageAccountName = $storageAccount.StorageAccountName
            'StorageUseCase' = $appType
            'Service Name' = $appService.Name
            PublicNetworkAccess = $publicNetworkAccessDescription
            AllowBlobAnonymousAccess = $allowBlobPublicAccess
            RoutingChoice = $routingChoice
            Encryption = $allencrypt
            FirewallBypass = $bypass
            VirtualNetwork = $virtualNetworkAttached
            AccountVer = $AccountVer
            MinimumTlsVersion = $minimumTlsVersion
            usesPrivateEndpoint =$usesPrivateEndpoint
        }

        $results += $obj
    }
# Check if there are any associated SQL servers
} elseif ($associatedSQLServers) {
    foreach ($sqlServer in $associatedSQLServers) {
        Write-Host "SQL Server associated: $($sqlServer.ServerName)"
        # Create a custom PowerShell object to hold the data and add it to the results
        $obj = [PSCustomObject]@{
            StorageAccountName = $storageAccount.StorageAccountName
            'StorageUseCase' = "SQL Server"
            'Service Name' = $sqlServer.ServerName
            PublicNetworkAccess = $publicNetworkAccessDescription
            AllowBlobAnonymousAccess = $allowBlobPublicAccess
            RoutingChoice = $routingChoice
            Encryption = $allencrypt
            FirewallBypass = $bypass
            VirtualNetwork = $virtualNetworkAttached
            AccountVer = $AccountVer
            MinimumTlsVersion = $minimumTlsVersion
            usesPrivateEndpoint =$usesPrivateEndpoint
        }

        $results += $obj
    }

}elseif ($associatedBSServers) {
    foreach ($batchAccount in $associatedBSServers) {
        # Create a custom PowerShell object to hold the data and add it to the results
        $obj = [PSCustomObject]@{
            StorageAccountName = $storageAccount.StorageAccountName
            'StorageUseCase' = "Batch Service"
            'Service Name' = $batchAccount.AccountEndpoint.Split('.')[0]
            PublicNetworkAccess = $publicNetworkAccessDescription
            AllowBlobAnonymousAccess = $allowBlobPublicAccess
            RoutingChoice = $routingChoice
            Encryption = $allencrypt
            FirewallBypass = $bypass
            VirtualNetwork = $virtualNetworkAttached
            AccountVer = $AccountVer
            MinimumTlsVersion = $minimumTlsVersion
            usesPrivateEndpoint =$usesPrivateEndpoint
        }

        $results += $obj
    }

}elseif ($associatedMLServers) {
    foreach ($workspace in $associatedMLServers) {
        # Create a custom PowerShell object to hold the data and add it to the results
        $obj = [PSCustomObject]@{
            StorageAccountName = $storageAccount.StorageAccountName
            'StorageUseCase' = "Machine Learning Workspace"
            'Service Name' = $workspace.name.Split('.')[0]
            PublicNetworkAccess = $publicNetworkAccessDescription
            AllowBlobAnonymousAccess = $allowBlobPublicAccess
            RoutingChoice = $routingChoice
            Encryption = $allencrypt
            FirewallBypass = $bypass
            VirtualNetwork = $virtualNetworkAttached
            AccountVer = $AccountVer
            MinimumTlsVersion = $minimumTlsVersion
            usesPrivateEndpoint =$usesPrivateEndpoint
        }

        $results += $obj
    }

  


# If the storage account has no associated services or does not match the above categories
} else {

    $obj = [PSCustomObject]@{
        StorageAccountName = $storageAccount.StorageAccountName
        'StorageUseCase' = "N/A"
        'Service Name' = "N/A"
        PublicNetworkAccess = $publicNetworkAccessDescription
        AllowBlobAnonymousAccess = $allowBlobPublicAccess
        RoutingChoice = $routingChoice
        Encryption = $allencrypt
        FirewallBypass = $bypass
        VirtualNetwork = $virtualNetworkAttached
        AccountVer = $AccountVer
        MinimumTlsVersion = $minimumTlsVersion
        usesPrivateEndpoint =$usesPrivateEndpoint
    }

    $results += $obj
}

        }


    }

# Define the Excel file name based on the current date and time
    $ExcelFileName = "AzureStorage-CA-$(Get-Date -Format 'yyyy-MM-dd-HHmmss').xlsx"

    # Check if an output path was provided and set the full path to the Excel file
    $ExcelFilePath = if ($OutputPath) { Join-Path -Path $OutputPath -ChildPath $ExcelFileName } else { ".\$ExcelFileName" }

    # Export the main results to the Excel file
    $results | Export-Excel -Path $ExcelFilePath -WorksheetName "Data" -AutoSize -TableStyle Medium9

    # Define your definitions for a new worksheet
    $definitions = @(
        [PSCustomObject]@{
            Term = "Routing Choice"
            Definition = "Unidentified:The status cannot be determined since it is not specified in the 'Resource JSON .`n  Defined: Network routing configuration is specified "
        },
        [PSCustomObject]@{
            Term = "VirtualNetwork"
            Definition = "Virtual network rules are a security feature designed to enhance the protection of your storage account by allowing you to permit access exclusively to traffic originating from one or more designated networks. When a virtual network rule is 'Not Configured', it implies that the storage account does not have any such restrictions in place, potentially allowing access from any network, subject to other access policies or security settings."
        },
       [PSCustomObject]@{
        Term = "Encryption Configuration"
        Definition = "Fully Configured: Encryption is turned on for Blob, File, Table, and Queue services within the storage account.`n Partially Configured: One or more, but not all, of the available encryption services are enabled."
    },
            [PSCustomObject]@{
            Term = "FirewallBypass"
            Definition = "Allows specific Azure-related traffic to pass through the firewall without restriction. It's meant to ensure essential operational data such as logs and performance metrics can be collected and that services managed by Azure can communicate with the resource, despite any firewall rules that are in place."
            
            }


        # Add more definitions as needed
    )

    # Append the definitions to a new worksheet in the same Excel file
    $definitions | Export-Excel -Path $ExcelFilePath -WorksheetName "Definitions" -AutoSize -Append -TableStyle Medium9

} catch {
    # Handle any errors that occur
    Write-Error $_.Exception
}


