terraform {
    backend "local" {
    }
}

provider azurerm {
    features {
    }
}

provider random {
}

data "azurerm_client_config" "current_client" {
}

variable location {
    default = "eastus"
}

resource "azurerm_resource_group" "rg" {
    name = "tf-keyvault-access-policy-rg"
    location = var.location
}

resource "random_id" "keyvault" {
    byte_length = 8
}

resource "azurerm_key_vault" "keyvault" {
    name = format("%.24s", lower(replace("tfkeyvaultaccesspolicy${random_id.keyvault.hex}", "/[[:^alnum:]]/", "")))
    location = var.location
    resource_group_name = azurerm_resource_group.rg.name
    sku_name = "standard"
    soft_delete_retention_days = 90
    tenant_id = data.azurerm_client_config.current_client.tenant_id

    access_policy {
        tenant_id = data.azurerm_client_config.current_client.tenant_id
        object_id = data.azurerm_client_config.current_client.object_id

        key_permissions = [
            "create",
            "get",
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

resource "random_integer" "windows-password-length" {
  min = 8
  max = 123
}

resource "random_password" "random-windows-password" {
  length      = random_integer.windows-password-length.result
  upper       = true
  lower       = true
  number      = true
  special     = true
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
  min_special = 1
}

resource "azurerm_key_vault_secret" "windows-password" {
  name         = "windows-password"
  value        = random_password.random-windows-password.result
  key_vault_id = azurerm_key_vault.keyvault.id
}
