$AppName = 'replace-with-app-reg-name'
$GitHubOrg = 'replace-with-your-org'
$GitHubRepo = 'replace-with-your-repo'

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
   $AppId=$(az ad app create --display-name ${AppName} --query appId -o tsv)
}


$ServicePrincipal=$(az ad sp list --filter "appId eq '$AppId'" --query [].id -o tsv)

if ($ServicePrincipal) {
   Write-Output "Service Principal already exists: $ServicePrincipal"
} else {
   Write-Output "Creating Service Principal"
   $ServicePrincipal=$(az ad sp create --id $AppId --query id -o tsv)
   
   Write-Output "Assigning contributor role on subscription!"
   az role assignment create --role contributor --subscription $SubId --assignee-object-id $ServicePrincipal --assignee-principal-type ServicePrincipal
}
 
$AppObjectId=$(az ad app show --id $AppId --query id -o tsv)
Write-Output "Application ObjectId $AppObjectId"

$currentCredsResult = az rest --method GET --uri "https://graph.microsoft.com/beta/applications/$AppObjectId/federatedIdentityCredentials"
$currentCredsResult.Value

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

$mainBranchFic = @{
  "name"= "main-branch"
  "issuer"= "https://token.actions.githubusercontent.com"
  "subject"= "repo:${GitHubRepoPath}:ref:refs/heads/main"
  "description"= "main branch access"
   "audiences"= @( "api://AzureADTokenExchange")
}
$mainBranchFic = ConvertTo-Json $mainBranchFic -Compress
$mainBranchFic = $mainBranchFic -replace "`"", "\`""

az rest --method POST --uri "https://graph.microsoft.com/beta/applications/$AppObjectId/federatedIdentityCredentials" --headers "Content-Type=application/json" --body $mainBranchFic


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

