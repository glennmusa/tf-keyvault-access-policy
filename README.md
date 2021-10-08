# tf-keyvault-access-policy

An experiment for assigning a Service Principal an Azure KeyVault access policy when executing Terraform as that Service Principal.

The Terraform template in this repository will create an Azure KeyVault and configure it with an Access Policy that permits the Service Principal to store a randomly generated Windows password as a KeyVault secret.

## Quickstart

In these steps we will:

- create a Service Principal
- set some environment variables so that Terraform will deploy resources as the Service Principal
- use Terraform to deploy the template in this repository

1. **Login to Azure**

    Login to Azure with the Azure CLI.

    Run the `login` command:

    ```plaintext
    az login
    ```

1. **Create a Service Principal**

    Create a Service Principal with Azure CLI. 

    Run the `ad sp create-for-rbac` command:

    ```plaintext
    az ad sp create-for-rbac
    ```

    **We'll need `appId`, `password`, and `tenant`.** from the command result. The Service Principal's client secret will only appear this one time. Capture these values before clearing the terminal.

1. **Set environment variables for Terraform azurerm**

    The azurerm provider for Terraform can inspect environment variables in order to deploy with a Service Principal.

    See these docs for more info: <https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/guides/service_principal_client_secret#environment-variables>

    Set the necessary values for azurerm to execute Terraform as a Service Principal:

    ```bash
    export ARM_CLIENT_ID={the value of 'appId' from the az ad sp create-for-rbac result}
    export ARM_CLIENT_SECRET={the value of 'password' from the az ad sp create-for-rbac result} 
    export ARM_SUBSCRIPTION_ID=$(az account show --query id --output tsv)
    export ARM_TENANT_ID={the value of 'tenant' from the az ad sp create-for-rbac result} 
    ```

1. **Login with the Service Principal**

    Login with the Service Principal with Azure CLI:

    ```plaintext
    az login --service-principal \
      -u "$ARM_CLIENT_ID" \
      -p "$ARM_CLIENT_SECRET" \
      --tenant "$ARM_TENANT_ID"
    ```

1. **Deploy with Terraform**

    Now you're all setup to run Terraform as a Service Principal.

    First, run initialize a working directory:

    ```plaintext
    terraform init
    ```

    Then `terraform apply` and accept the prompt:

    ```plaintext
    terraform apply
    ```

## How this works

The Terraform template in this repository takes advantage of the azurerm Terraform provider's `client_config` data source.

See this doc for more info: <https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config>

We use this `client_config` resource to provide the `tenant_id` property on the `azurerm_keyvault` resource as well as to create an out-of-the-box KeyVault Access Policy assignment for the executing principal (whether that's a user or a Service Principal):

```terraform
resource "azurerm_key_vault" "keyvault" {
    
    # other required properties

    tenant_id = data.azurerm_client_config.current_client.tenant_id

    access_policy {
    
        tenant_id = data.azurerm_client_config.current_client.tenant_id
        object_id = data.azurerm_client_config.current_client.object_id

        key_permissions = [
            # desired permissions
        ]

        secret_permissions = [
            "set",
            "get",
            "delete",
            "purge",
            "recover"
        ]
    }
}
```

With this access policy configured, the Service Principal that is executing Terraform is able to create secrets in that Keyvault:

```terraform
resource "azurerm_key_vault_secret" "windows-password" {
  name         = "windows-password"
  value        = random_password.random-windows-password.result
  key_vault_id = azurerm_key_vault.keyvault.id
}
```

## Clean Up

This will clean up any Azure resources provisioned by the template in this repository.

1. **Run Terraform destroy** 

    Deprovision the resources your Service Principal deployed with Terraform with `destroy`:

    ```plaintext
    terraform destroy
    ```
