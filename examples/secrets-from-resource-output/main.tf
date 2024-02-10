terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.7.0, < 4.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0, < 4.0.0"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4.1, < 4.0.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      # useful when doing demos and test/dev!
      prevent_deletion_if_contains_resources = false
    }
  }
  skip_provider_registration = true
}

# We need the tenant id for the key vault.
data "azurerm_client_config" "this" {}

# This allows us to randomize the region for the resource group.
module "regions" {
  source  = "Azure/regions/azurerm"
  version = ">= 0.3.0"
}

# This allows us to randomize the region for the resource group.
resource "random_integer" "region_index" {
  min = 0
  max = length(module.regions.regions) - 1
}

# This ensures we have unique CAF compliant names for our resources.
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.0"
}

# This is required for resource modules
resource "azurerm_resource_group" "this" {
  name     = module.naming.resource_group.name_unique
  location = module.regions.regions[random_integer.region_index.result].name
}

# create a storage account as a sample resource to get secrets from
module "storage_account" {
  source                    = "Azure/avm-res-storage-storageaccount/azurerm"
  version                   = "0.1.0"
  name                      = module.naming.storage_account.name_unique
  resource_group_name       = azurerm_resource_group.this.name
  shared_access_key_enabled = true
}

# get the IP client running terraform
data "http" "my_ip" {
  url = "https://ifconfig.me/ip"
}

module "keyvault" {
  source                        = "Azure/avm-res-keyvault-vault/azurerm"
  version                       = "0.5.1"
  name                          = module.naming.key_vault.name_unique
  enable_telemetry              = var.enable_telemetry
  location                      = azurerm_resource_group.this.location
  resource_group_name           = azurerm_resource_group.this.name
  tenant_id                     = data.azurerm_client_config.this.tenant_id
  purge_protection_enabled      = false
  public_network_access_enabled = true # so we can check the secrets get created ok.
  sku_name                      = "standard"
  tags                          = var.tags

  network_acls = {
    ip_rules = [data.http.my_ip.response_body]
  }

  role_assignments = {
    devops_principal_secrets_officer = {
      role_definition_id_or_name = "Key Vault Secrets Officer"
      principal_id               = data.azurerm_client_config.this.object_id
    },
  }

  secrets = {
    "my_storage_account_primary_key" = {
      name = "my-storage-key"
    }
  }

  # secret values are marked as sensitive and thus can not be used in a for_each loop
  secrets_value = {
    # the 'resource' output in AVM provides access to all outputs created by the resource.
    "my_storage_account_primary_key" = module.storage_account.resource.primary_access_key
  }
}
