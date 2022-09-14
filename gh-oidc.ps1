$AppName = Read-Host "Enter the name of the app registration"
$GitHubOrg = Read-Host "Enter the name of the GitHub organization or user"
$GitHubRepo = Read-Host "Enter the name of the Repository"

$GitHubRepoPath = "$GitHubOrg/$GitHubRepo"

$SubName = (az account show --query name -o tsv)

$SubId = (az account show --query id -o tsv)
$TenantId = (az account show --query tenantId -o tsv)
Write-Output "Subscription: $SubName($SubId)"
Write-Output "TenantId: $TenantId"

$AppId=$(az ad app list --filter "displayName eq '$AppName'" --query [].appId -o tsv)

if ($AppId){
   Write-Output "App already exists: $AppId"
} else {
   Write-Output "Creating App"
   $AppId=$(az ad app create --display-name $AppName --query appId -o tsv)
   Write-Output "App created ${AppId}"
}


$ServicePrincipal=$(az ad sp show --id $AppId --query objectId -o tsv)
if ($ServicePrincipal) {
   Write-Output "Service Principal already exists: $ServicePrincipal"
} else {
   Write-Output "Creating Service Principal"
   $ServicePrincipal=$(az ad sp create --id $AppId --query objectId -o tsv)
   
   Write-Output "Assigning contributor role on subscription!"
   az role assignment create --role contributor --subscription $SubId --assignee-object-id $ServicePrincipal --assignee-principal-type ServicePrincipal
}
 
$AppObjectId=$(az ad app show --id $AppId --query objectId -o tsv)
Write-Output "Application ObjectId $AppObjectId"


Write-Output "Adding federated identity credentials (fic)"

$createPrFic = Read-Host "Do you want to add fic for pull requests? (y/N)"
if ($createPrFic -eq 'y')
{
   $prFic = @{
      "name"= "pull-request"
      "issuer"= "https://token.actions.githubusercontent.com"
      "subject"= "repo:${GitHubRepoPath}:pull_request"
      "description"= "pull request access"
      "audiences"= @( "api://AzureADTokenExchange")
   }

   $prFic = ConvertTo-Json $prFic -Compress
   $prFic = $prFic -replace "`"", "\`""
   az rest --method POST --uri "https://graph.microsoft.com/beta/applications/$AppObjectId/federatedIdentityCredentials" --headers "Content-Type=application/json" --body $prFic
}

$branchName = Read-Host "Create fic for a branch? (type the branch name or press enter to skip)"
if ($branchName)
{
   $branchFic = @{
   "name"= "branch-${branchName}"
   "issuer"= "https://token.actions.githubusercontent.com"
   "subject"= "repo:${GitHubRepoPath}:ref:refs/heads/${branchName}"
   "description"= "branch access"
      "audiences"= @( "api://AzureADTokenExchange")
   }
   $branchFic = ConvertTo-Json $branchFic -Compress
   $branchFic = $branchFic -replace "`"", "\`""
   az rest --method POST --uri "https://graph.microsoft.com/beta/applications/$AppObjectId/federatedIdentityCredentials" --headers "Content-Type=application/json" --body $branchFic
}

$envName = Read-Host "Create fic for an environment? (type the environment name or press enter to skip)"
if ($envName)
{
   $envFic = @{
   "name"= "env-${envName}"
   "issuer"= "https://token.actions.githubusercontent.com"
   "subject"= "repo:${GitHubRepoPath}:environment:${envName}"
   "description"= "environment access - ${envName}"
      "audiences"= @( "api://AzureADTokenExchange")
   }
   $envFic = ConvertTo-Json $envFic -Compress
   $envFic = $envFic -replace "`"", "\`""
   az rest --method POST --uri "https://graph.microsoft.com/beta/applications/$AppObjectId/federatedIdentityCredentials" --headers "Content-Type=application/json" --body $envFic
}


Write-Output "AZURE_CLIENT_ID=$AppId"
Write-Output "AZURE_SUBSCRIPTION_ID=$SubId"
Write-Output "AZURE_TENANT_ID=$TenantId"

$confirmation = Read-Host "Login to GitHub and set these secrets? (y/N)"
if ($confirmation -eq 'y') {
   gh auth login 
   gh secret set AZURE_CLIENT_ID -b $AppId -a actions --repo $GitHubRepoPath
   gh secret set AZURE_SUBSCRIPTION_ID -b $SubId -a actions --repo $GitHubRepoPath
   gh secret set AZURE_TENANT_ID -b $TenantId -a actions --repo $GitHubRepoPath
}

