<#
 .SYNOPSIS
    Deploys a template to Azure

 .DESCRIPTION
    Deploys an Azure Resource Manager template

 .PARAMETER subscriptionId
    The subscription id where the template will be deployed.

 .PARAMETER resourceGroupName
    The resource group where the template will be deployed. Can be the name of an existing or a new resource group.

 .PARAMETER resourceGroupLocation
    Optional, a resource group location. If specified, will try to create a new resource group in this location. If not specified, assumes resource group is existing.

 .PARAMETER deploymentName
    The deployment name.cls

 .PARAMETER templateFilePath
    Optional, path to the template file. Defaults to template.json.

 .PARAMETER parametersFilePath
    Optional, path to the parameters file. Defaults to parameters.json. If file is not found, will prompt for parameter values based on template.
#>

param(
 
 [string]
 $subscriptionId = "bxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",

 
 [string]
 $resourceGroupName = "CoreInfra",

 [string]
 $resourceGroupLocation,

 
 [string]
 $deploymentName = "MyFirstVM",

 [string]
 $templateFilePath = "ARM_SimpleVM.json",

 [string]
 $parametersFilePath = "parameters.json"#"CustomScriptExtensionParameters.json"
)

<#
.SYNOPSIS
    Registers RPs
#>
Function RegisterRP {
    Param(
        [string]$ResourceProviderNamespace
    )

    Write-Host "Registering resource provider '$ResourceProviderNamespace'";
    Register-AzureRmResourceProvider -ProviderNamespace $ResourceProviderNamespace;
}

#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************
$ErrorActionPreference = "Stop"

Write-Host "INFO --- Starting script at $(Get-Date -Format "dd-MM-yyyy HH:mm")"
# sign in
Write-Host "Logging in...";

#$cred = Get-Credential -UserName 6f08a82b-50f0-472d-888f-70cc1cc925be -Message "Enter the credentials"
#Login-AzureRmAccount -Credential $cred -ServicePrincipal -TenantId 3xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx


#Select-AzureRmProfile -Path "c:\folder\azureprofile.json"

# select subscription
Write-Host "Selecting subscription '$subscriptionId'";
Select-AzureRmSubscription -SubscriptionID $subscriptionId;
Write-Host "Here...";

# Register RPs
$resourceProviders = @("microsoft.compute","microsoft.devtestlab","microsoft.storage","microsoft.network");
if($resourceProviders.length) {
    Write-Host "Registering resource providers"
    foreach($resourceProvider in $resourceProviders) {
        RegisterRP($resourceProvider);
    }
}

#Create or check for existing resource group
$resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if(!$resourceGroup)
{
    Write-Host "Resource group '$resourceGroupName' does not exist. To create a new resource group, please enter a location.";
    if(!$resourceGroupLocation) {
        $resourceGroupLocation = Read-Host "resourceGroupLocation";
    }
    Write-Host "Creating resource group '$resourceGroupName' in location '$resourceGroupLocation'";
    New-AzureRmResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation
}
else{
    Write-Host "Using existing resource group '$resourceGroupName'";
}

# Start the deployment
Write-Host "Starting deployment...";
Write-Host $templateFilePath;
$ex;

if(Test-Path $parametersFilePath) {
    Write-Host 'with param file'
    New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath -TemplateParameterFile $parametersFilePath -ErrorAction Stop -ErrorVariable $ex;

} else {
Write-Host 'no param file'
    New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile $templateFilePath;
}
Write-Host "Ending deployment...";

Write-Host "INFO --- Ending script at $(Get-Date -Format "dd-MM-yyyy HH:mm")"

