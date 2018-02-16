

    [CmdletBinding()]
    Param
    (
    # Choose the Subscription Name
    [Parameter(Mandatory=$false)]
    [ValidateSet("TSE-Enterprise","PC-NL","PC-UK","DownSb","Sandbox","Visual Studio Enterprise")][String]$SubscriptionName = "Visual Studio Enterprise",
    # Choose the ResourceGroup location
    [Parameter(Mandatory=$false)]
    [ValidateSet("NE", "WE")][String]$ResourceGroupLocation = "WE",
    # Choose the RBAC Role name
    [Parameter(Mandatory=$false)]
    [String]$RBACRoleName = "Contributor",
    [Parameter(Mandatory=$false)]
    [String]$WRSIdTag = "231",
    [Parameter(Mandatory=$false)]
    [String]$ApplicationNameTag = "Dul",
    [Parameter(Mandatory=$false)]
    [ValidateSet("DEV","TST","QA","PROD","SBX")][String]$EnvironmentTag = "Dev",
    [Parameter(Mandatory=$false)]
    [String]$WBSCodeTag = "12dfdf",
    [Parameter(Mandatory=$false)]
    [ValidateSet("Low","Medium","High")][String]$BIAScoreTag = "Low",
    [Parameter(Mandatory=$false)]
    [String]$ADGroup = "Dummy-Dev-RG",    
    [Parameter(Mandatory=$false)]
    [ValidatePattern("[\D\d]+[@][t][a][t][a][s][t][e][e][l][.][c][o][m]")][String]$ManagedByTag = "Dipak.patil@tatasteel.com",
    [Parameter(Mandatory=$false)]
    [ValidatePattern("[\D\d]+[@][t][a][t][a][s][t][e][e][l][.][c][o][m]")][String]$UsedByTag= "Dick.Vriend@tatasteel.com"
    )

    Write-Host "INFO --- Logging in...";

    try
    {    
        #$cred = Get-Credential -UserName 6f08a82b-50f0-472d-888f-70cc1cc925be -Message "Enter the credentials"
        #Login-AzureRmAccount -Credential $cred -ServicePrincipal -TenantId 033a7408-6de4-42db-920e-57ae321da0e5

    }
    catch
    {
        Write-Error -Message $_.Exception
        throw $_.Exception    
    }

    # Stop the runbook if something fails
    $ErrorActionPreference = "Stop"
    # Select the Azure Subscription
    Write-Output "INFO --- Switching to subscription $SubscriptionName"
    $Subscription = Select-AzureRmSubscription -Subscription b6c72194-a2d4-49a2-9317-9f42d823cec6
    # Check if location is valid
    $AllowedRegions = 'NE','WE'

    If ($ResourceGroupLocation -ilike 'NE') {
        $LongResourceGroupLocation = "North Europe"
        Write-Output "INFO --- Region is set to $ResourceGroupLocation, which is valid."
        Write-Output "INFO --- Long Resource Group Location Name is $LongResourceGroupLocation"
    }
    ElseIf($ResourceGroupLocation -ilike 'WE'){
        $LongResourceGroupLocation = "West Europe"
        Write-Output "INFO --- Region is set to $ResourceGroupLocation, which is valid."
        Write-Output "INFO --- Long Resource Group Location Name is $LongResourceGroupLocation"
    }
    Else {
        Write-Output "INFO --- Region $ResourceGroupLocation is not valid.Please choose one of the following:"
        Write-Output $AllowedRegions
        Write-Error –Message "ERROR --- Runbook has failed. Please check the output of the job."
    }

    # Create the resource group name, but need confirmation on Resource Group naming convention, currently following is in place
    $ResourceGroupName = $ApplicationNameTag + "-" + $EnvironmentTag + "-" +"RG"

    Write-Output "INFO --- Preparing.."


    # Check if the AAD Group exists. If not, fail
    $AADGroup = Get-AzureRmADGroup -SearchString $ADGroup
    If (($AADGroup).DisplayName -eq $Null) {
        Write-Output "ERROR --- Azure AD Group with name $ResourceGroupName doesn't exist."
        Write-Output "ERROR --- Please create the AAD Group first and add the Administrator user to it, before running this script again."
        Write-Error –Message "Script has failed. Please check the output for more details."
    }
    Else {
        Write-Output "INFO --- Azure AD Group exists."
    }


    #Check if Resource Group exists. If yes, fail.
    $ResourceGroupCheck = Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    If ($ResourceGroupCheck -eq $Null) {
        Write-Output "INFO --- Check succeeded. Resource Group $ResourceGroupName doesn't exist."
    }
    Else {
        Write-Output "ERROR --- Resource group $ResourceGroupName already exists. Exiting script."
        Write-Output "ERROR --- Please check if the Resource Group exists."
        Write-Error –Message "Script has failed. Please check the output for more details."
    }


    # Create the Resource Group with the location and tags.
    $ResourceGroup = New-AzureRmResourceGroup -Name $ResourceGroupName -Location $LongResourceGroupLocation
    # Create the resource group for the user
    Write-Output "INFO --- Creating resource group with name $ResourceGroupName in $LongResourceGroupLocation $($ResourceGroup.ProvisioningState)"

    # Assign the Azure Role to the Resource Group
    Write-Output "INFO --- Assigning the Azure role to the Resource Group"
    New-AzureRmRoleAssignment -ResourceGroupName $ResourceGroupName -RoleDefinitionName $RBACRoleName -ObjectId $AADGroup.Id.Guid -ErrorAction Continue

    # Add multiple tags to the Resource Group
    $Tags = (Get-AzureRmResourceGroup -Name $ResourceGroupName).Tags
    Write-Output $Tags
    Write-Output "INFO --- Assigning the tag values to the Resource Group"

    $Tags += @{WRSID = "$WRSIdTag"}
    $Tags += @{ApplicationName = "$ApplicationNameTag"}
    $Tags += @{Environment="$EnvironmentTag"}
    $Tags += @{BillTo = "$WBSCodeTag"}
    $Tags += @{Administrator = "$ManagedByTag"}
    $Tags += @{UsedBy = "$UsedByTag"}
    $Tags += @{BIAScore = "$BIAScoreTag"}
    $Tags += @{Region = "$ResourceGroupLocation"}

    If($SubscriptionName -eq 'Sandbox' -or $SubscriptionName -eq 'visual studio EnterPrise'){
        $Tags += @{ExpiresOn = (Get-Date).AddMonths(3).ToString("dd-MM-yyyy HH:mm:ss")}

        Write-Output "INFO --- Creating a schedule to send email alert to Sandbox resource group admin and user before its deletion"
        $automationAccountName = "AutomationAccountWE"
        $runbookName = "Send_Email"
        $params = @{'RGNAME'=$ResourceGroupName}
        $scheduleName = "SendEmail14_$ResourceGroupName"

        New-AzureRmAutomationSchedule –AutomationAccountName $automationAccountName –Name $scheduleName –StartTime (Get-Date).AddMinutes(10) -ResourceGroupName CoreInfra -OneTime      
        Register-AzureRmAutomationScheduledRunbook –AutomationAccountName $automationAccountName –Name $runbookName –ScheduleName $scheduleName –Parameters $params -ResourceGroupName CoreInfra

        Write-Output "INFO --- Creating a schedule to delete the resource group after 3 months"    
        $runbookName = "Delete_SandboxResourceGroup"
        $params = @{'RGNAME'=$ResourceGroupName}
        $scheduleName = "DeleteRG14_$ResourceGroupName"

        New-AzureRmAutomationSchedule –AutomationAccountName $automationAccountName –Name $scheduleName –StartTime (Get-Date).AddDays(1) -ResourceGroupName CoreInfra -OneTime      
        Register-AzureRmAutomationScheduledRunbook –AutomationAccountName $automationAccountName –Name $runbookName –ScheduleName $scheduleName –Parameters $params -ResourceGroupName CoreInfra
    }

    Write-Output "INFO --- Creating the following tags:"
    Write-Output $Tags

    # Write all the tags back to the Resource Groups
    $Null = Set-AzureRmResourceGroup -Name $ResourceGroupName -Tag $Tags

    # Set ARM policies for RG

    #Geo policy - restricting locations to West Europe and North Europe
    $definition = '{"if": {"not": {"field": "location","in": [ "northeurope", "westeurope"]}},"then": {"effect": "deny"}}'
    $policydef = New-AzureRmPolicyDefinition -Name GeoPolicy -Description 'Only North Europe and West Europe allowed' -Policy $definition
 
    # Assign the policy
    New-AzureRmPolicyAssignment -Name GeoPolicy -PolicyDefinition $policydef -Scope $ResourceGroup.ResourceId


    #IP address policy -- restricting Public IP assignment policy
    $definition = '{"if":{"anyOf":[{"source":"action","like":"Microsoft.Network/publicIPAddresses/*"}]},"then":{"effect":"deny"}}'
    $policydef = New-AzureRmPolicyDefinition -Name NoPubIPPolicyDefinition -Description 'No public IP addresses allowed' -Policy $definition
 
    # Assign the policy
    New-AzureRmPolicyAssignment -Name NoPublicIPPolicyAssignment -PolicyDefinition $policydef -Scope $ResourceGroup.ResourceId


    #VMSKU policy -- for Dev environment or Sandbox subscription restrict user to Basic VMs
    If($EnvironmentTag -eq 'DEV' -or $EnvironmentTag -eq 'SBX' -or $SubscriptionName -eq 'Sandbox'){
 
        $definition = '{"if": {"allOf": [{"field": "type","equals": "Microsoft.Compute/virtualMachines"},{"not": {"field": "Microsoft.Compute/virtualMachines/sku.name","in": ["Basic_A0", "Basic_A1", "Basic_A2", "Basic_A3", "Basic_A4", "Standard_A0", "Standard_A1", "Standard_A2", "Standard_A2_v2", "Standard_F1", "Standard_F2", "Standard_F2s", "Standard_F4"]}}]},"then": {"effect": "Deny"}}'
        $policydef = New-AzureRmPolicyDefinition -Name DEVVMSKU -Description 'On Dev/Sandbox, no SSD and big configuration VM allowed' -Policy $definition
 
        # Assign the policy
        New-AzureRmPolicyAssignment -Name DEVVMSKU -PolicyDefinition $policydef -Scope $ResourceGroup.ResourceId

    }

    #Set Service Principal for the RG
    $aadApp = 'ARM-SP-'+$ApplicationNameTag
    $app = Get-AzureRmADApplication -DisplayNameStartWith $aadApp

    if($app -eq $null){
        Write-Host "INFO --- Service application does not exist."

        $password = ConvertTo-SecureString -String "Password@123" -AsPlainText -Force

        # Create an Application in Active Directory
        Write-Output "INFO --- Creating AAD application..."
    
        $azureAdApplication = New-AzureRmADApplication -DisplayName $aadApp -HomePage "http://$ResourceGroupName.com" -IdentifierUris "http://$ResourceGroupName.com" -Password $password
        $azureAdApplication | Format-Table

        # Create the Service Principal
        Write-Output "INFO --- Creating AAD service principal..."
        $servicePrincipal = New-AzureRmADServicePrincipal -ApplicationId $azureAdApplication.ApplicationId
        $servicePrincipal | Format-Table

        Write-Output "INFO --- Sleeping for 10s to give the service principal a chance to finish creating."
        Start-Sleep -s 10
 
        # Assign the Service Principal the Contributor Role to the Subscription.
        # Roles can be Granted at the Resource Group Level if Desired.
        Write-Output "INFO --- Assigning the Contributor role to the service principal..."
        New-AzureRmRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $azureAdApplication.ApplicationId -ErrorAction Continue
       
        Write-Output "INFO --- Client ID: $($azureAdApplication.ApplicationId)"
    }


    # Output all the usefull information
    Write-Output "*************** Details ***************"
    Write-Output "Resource Group Name: $ResourceGroupName"
    Write-Output "Resource Group Location: $ResourceGroupLocation"
    Write-Output "Virtual Machine Naming Convention: $("$NamingConvention" + "*"), e.g. $("$NamingConvention" + "SQL001") (Max. 15 characters)"
    Write-Output "Resource Group User: $ManagedByTag"
    Write-Output "User Role: $RBACRoleName"
    Write-Output "Subscription Name: $SubscriptionName"
    Write-Output "Application ID: $azureAdApplication.ApplicationId"
    Write-Output "Resource Group Tags:"
    Write-Output $Tags
    Write-Output "*************** Details ***************"
    # Ending script
    Write-Output "INFO --- Ending New-ResourceGroup script at $(Get-Date -Format "dd-MM-yyyy HH:mm")"




