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

module "keyvault" {
  source                   = "Azure/avm-res-keyvault-vault/azurerm"
  version                  = "0.5.1"
  name                     = module.naming.key_vault.name_unique
  enable_telemetry         = var.enable_telemetry
  location                 = azurerm_resource_group.this.location
  resource_group_name      = azurerm_resource_group.this.name
  tenant_id                = data.azurerm_client_config.this.tenant_id
  purge_protection_enabled = false
  sku_name                 = "standard"
  tags                     = var.tags

  role_assignments = {
    my_app_secrets_user = {
      role_definition_id_or_name = "Key Vault Secrets User"
      principal_id               = "dcade1b3-d52e-479e-aefd-6e6e4128959f" # some random AD group I have already made
    },
    devops_principal_secrets_officer = {
      role_definition_id_or_name = "Key Vault Secrets Officer"
      principal_id               = data.azurerm_client_config.this.object_id
    },
  }
}
