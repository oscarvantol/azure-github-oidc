# Publish to Azure from GitHub with OpenId Connect Auth

Using OIDC is the best way to deploy to Azure from GitHub because simply... it does not depend on a password or a cert. So no real secrets and no expiry.

## Why this
The documentation how to do this can be found here on GitHub: [configuring-openid-connect-in-azure](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure)
and here on MS docs: [use-the-azure-login-action-with-openid-connect](https://docs.microsoft.com/en-us/azure/developer/github/connect-from-azure?tabs=azure-portal%2Clinux#use-the-azure-login-action-with-openid-connect)

Anyway why this repo? Mostly because I struggled somewhat the first time setting this up. It contains a bunch of steps and the model can be a bit complex to understand the first time. While playing with this I captured my steps in a powershell script and an example workflow.yml. I hope this helps you!
