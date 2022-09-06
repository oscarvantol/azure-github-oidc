

$AppName = 'SomeThing'
$Repo = 'orgname/reponame'


$SubId = (az account show --query id -o tsv)
$TenantId = (az account show --query tenantId -o tsv)

$AppId=$(az ad app list --filter "displayName eq '$AppName'" --query [].appId -o tsv)
if ($AppId -eq null)
{
   $AppId=$(az ad app create --display-name ${AppName} --query appId -o tsv)
}


$ServicePrincipal=$(az ad sp list --filter "appId eq '$AppId'" --query [].id -o tsv)
if ($ServicePrincipal -eq null)
{
   $ServicePrincipal=$(az ad sp create --id $AppId --query id -o tsv)
   az role assignment create --role contributor --subscription $SubId --assignee-object-id $ServicePrincipal --assignee-principal-type ServicePrincipal
}
 
$AppObjectId=$(az ad app show --id $AppId --query id -o tsv)

$prFic = ConvertTo-Json(@{
  "name"= "prfic"
        "issuer"= "https://token.actions.githubusercontent.com"
        "subject"= "repo:${Repo}:pull_request"
        "description"= "pr"
        "audiences"= @( "api://AzureADTokenExchange")
}) 
$prFicBody = $prFic -replace "`"", "\`""
az rest --method POST --uri "https://graph.microsoft.com/beta/applications/$AppObjectId/federatedIdentityCredentials" --headers "Content-Type=application/json" --body $prFicBody


$mainFic = ConvertTo-Json(@{
  "name"= "mainfic"
        "issuer"= "https://token.actions.githubusercontent.com"
        "subject"= "repo:${Repo}:ref:refs/heads/main"
        "description"= "main"
        "audiences"= @( "api://AzureADTokenExchange")
}) 
$mainFicBody = $mainFic -replace "`"", "\`""
az rest --method POST --uri "https://graph.microsoft.com/beta/applications/$AppObjectId/federatedIdentityCredentials" --headers "Content-Type=application/json" --body $mainFicBody

az rest --method GET --uri "https://graph.microsoft.com/beta/applications/$AppObjectId/federatedIdentityCredentials"


Write-Output AZURE_CLIENT_ID=$AppId
Write-Output AZURE_SUBSCRIPTION_ID=$SubId
Write-Output AZURE_TENANT_ID=$TenantId

