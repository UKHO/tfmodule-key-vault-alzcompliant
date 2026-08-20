terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source                = "hashicorp/azurerm"
      version               = ">= 5.0.0"
      configuration_aliases = [azurerm.hub, azurerm.secondary]
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.4.0"
    }
  }
}