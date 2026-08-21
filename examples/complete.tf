# Example: Basic Key Vault with Modern Module Pattern
# This example demonstrates how to use the modernized Key Vault module
# with proper provider configuration to support count, for_each, and depends_on

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.70.0"
    }
  }
}

# ============================================
# Provider Configuration (REQUIRED)
# ============================================
# Configure three providers for the module to use

# Default provider - Spoke subscription (where Key Vault resources are created)
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
  subscription_id = var.spoke_subscription_id
}

# Hub provider - Hub subscription (where primary DNS zone resides)
provider "azurerm" {
  alias           = "hub"
  features {}
  subscription_id = var.hub_subscription_id
}

# Secondary provider - Secondary subscription (for secondary DNS zone, if needed)
# Note: This must be configured even if you don't use secondary private endpoint
provider "azurerm" {
  alias           = "secondary"
  features {}
  subscription_id = var.secondary_subscription_id != null ? var.secondary_subscription_id : var.hub_subscription_id
}

# ============================================
# Variables
# ============================================

variable "spoke_subscription_id" {
  description = "Subscription ID for spoke (where Key Vault will be created)"
  type        = string
}

variable "hub_subscription_id" {
  description = "Subscription ID for hub (where primary DNS zone resides)"
  type        = string
}

variable "secondary_subscription_id" {
  description = "Subscription ID for secondary DNS zone (optional)"
  type        = string
  default     = null
}

# ============================================
# Example 1: Basic Key Vault (Single Instance)
# ============================================

module "key_vault_basic" {
  source = "../"  # Path to the module

  # CRITICAL: Pass provider configurations to the module
  providers = {
    azurerm           = azurerm           # Spoke subscription
    azurerm.primary       = azurerm.primary       # Hub subscription
    azurerm.secondary = azurerm.secondary # Secondary subscription
  }

  # Required variables
  resource_group_name = "rg-myapp-prod"
  environment         = "prod"

  # Networking
  virtual_network_name                = "vnet-spoke-prod"
  subnet_name                         = "subnet-privateendpoints"
  virtual_network_resource_group_name = "rg-network-prod"

  # DNS Configuration
  private_dns_zone_name                = "privatelink.vaultcore.azure.net"
  private_dns_zone_resource_group_name = "rg-dns-hub"

  # Private Endpoints
  enable_primary_private_endpoint   = true
  enable_secondary_private_endpoint = false

  # Optional: Custom name
  key_vault_name = "kv-myapp-prod-001"

  tags = {
    Environment = "production"
    Application = "myapp"
    ManagedBy   = "Terraform"
  }
}

# ============================================
# Example 2: Conditional Creation with count
# ============================================

variable "create_key_vault" {
  description = "Whether to create the Key Vault"
  type        = bool
  default     = true
}

module "key_vault_conditional" {
  source = "../"
  count  = var.create_key_vault ? 1 : 0  # ✅ Now supported!

  providers = {
    azurerm           = azurerm
    azurerm.primary       = azurerm.primary
    azurerm.secondary = azurerm.secondary
  }

  resource_group_name  = "rg-myapp-test"
  environment          = "test"
  virtual_network_name = "vnet-spoke-test"
  subnet_name          = "subnet-privateendpoints"

  enable_primary_private_endpoint = true
}

# Access outputs from conditional module
output "conditional_key_vault_id" {
  value = var.create_key_vault ? module.key_vault_conditional[0].key_vault_id : null
}

# ============================================
# Example 3: Multiple Instances with for_each
# ============================================

variable "environments" {
  description = "Map of environments to create Key Vaults for"
  type = map(object({
    resource_group_name = string
    virtual_network_name = string
  }))
  default = {
    dev = {
      resource_group_name  = "rg-myapp-dev"
      virtual_network_name = "vnet-spoke-dev"
    }
    test = {
      resource_group_name  = "rg-myapp-test"
      virtual_network_name = "vnet-spoke-test"
    }
    prod = {
      resource_group_name  = "rg-myapp-prod"
      virtual_network_name = "vnet-spoke-prod"
    }
  }
}

module "key_vault_multi_env" {
  source   = "../"
  for_each = var.environments  # ✅ Now supported!

  providers = {
    azurerm           = azurerm
    azurerm.primary       = azurerm.primary
    azurerm.secondary = azurerm.secondary
  }

  resource_group_name  = each.value.resource_group_name
  environment          = each.key
  key_vault_name       = "kv-myapp-${each.key}"
  
  virtual_network_name = each.value.virtual_network_name
  subnet_name          = "subnet-privateendpoints"

  enable_primary_private_endpoint = true

  tags = {
    Environment = each.key
    ManagedBy   = "Terraform"
  }
}

# Access outputs from for_each
output "all_key_vault_ids" {
  value = { for k, v in module.key_vault_multi_env : k => v.key_vault_id }
}

# ============================================
# Example 4: Using depends_on for Dependencies
# ============================================

# Create prerequisite resources
resource "azurerm_resource_group" "main" {
  name     = "rg-myapp-staging"
  location = "UK South"
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-spoke-staging"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "main" {
  name                 = "subnet-privateendpoints"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

module "key_vault_with_dependencies" {
  source = "../"

  providers = {
    azurerm           = azurerm
    azurerm.primary       = azurerm.primary
    azurerm.secondary = azurerm.secondary
  }

  # ✅ Now you can use depends_on!
  depends_on = [
    azurerm_virtual_network.main,
    azurerm_subnet.main
  ]

  resource_group_name                 = azurerm_resource_group.main.name
  environment                         = "staging"
  virtual_network_name                = azurerm_virtual_network.main.name
  subnet_name                         = azurerm_subnet.main.name
  virtual_network_resource_group_name = azurerm_resource_group.main.name

  enable_primary_private_endpoint = true

  tags = {
    Environment = "staging"
  }
}

# ============================================
# Example 5: Dual Private Endpoints
# ============================================

module "key_vault_dual_endpoints" {
  source = "../"

  providers = {
    azurerm           = azurerm
    azurerm.primary       = azurerm.primary
    azurerm.secondary = azurerm.secondary  # Secondary subscription required
  }

  resource_group_name = "rg-myapp-prod"
  environment         = "prod"

  # Shared networking (both endpoints use this)
  virtual_network_name                = "vnet-spoke-prod"
  subnet_name                         = "subnet-privateendpoints"
  virtual_network_resource_group_name = "rg-network-prod"

  # Primary DNS configuration (in hub subscription)
  private_dns_zone_name                = "privatelink.vaultcore.azure.net"
  private_dns_zone_resource_group_name = "rg-dns-hub"

  # Enable both private endpoints
  enable_primary_private_endpoint   = true
  enable_secondary_private_endpoint = true

  # Secondary DNS configuration (in secondary subscription)
  # Note: secondary_private_dns_zone_name defaults to "privatelink.vaultcore.azure.net"
  secondary_private_dns_zone_resource_group_name = "rg-dns-secondary"

  key_vault_name = "kv-myapp-prod-001"

  tags = {
    Environment = "production"
    HA          = "enabled"
  }
}

# ============================================
# Example 7: Dual Endpoints with Custom DNS Link Management
# ============================================

module "key_vault_custom_dns_links" {
  source = "../"

  providers = {
    azurerm           = azurerm
    azurerm.primary       = azurerm.primary
    azurerm.secondary = azurerm.secondary
  }

  resource_group_name = "rg-myapp-prod"
  environment         = "prod"

  # Networking
  virtual_network_name                = "vnet-spoke-prod"
  subnet_name                         = "subnet-privateendpoints"
  virtual_network_resource_group_name = "rg-network-prod"

  # Enable both endpoints
  enable_primary_private_endpoint   = true
  enable_secondary_private_endpoint = true

  # Secondary DNS configuration
  secondary_private_dns_zone_resource_group_name = "rg-dns-secondary"
  
  # Disable automatic VNet link creation - we'll manage it externally
  create_secondary_dns_zone_vnet_links = false

  key_vault_name = "kv-myapp-prod-custom-dns"

  tags = {
    Environment = "production"
    DNSManaged  = "external"
  }
}

# Manually create the DNS zone VNet link (when create_secondary_dns_zone_vnet_links = false)
resource "azurerm_private_dns_zone_virtual_network_link" "custom_secondary_link" {
  provider              = azurerm.secondary
  name                 = "custom-link-keyvault-secondary"
  resource_group_name  = "rg-dns-secondary"
  private_dns_zone_name = "privatelink.vaultcore.azure.net"
  virtual_network_id   = data.azurerm_virtual_network.spoke.id
  registration_enabled = false

  tags = {
    Environment = "production"
    ManagedBy   = "terraform-external"
  }
}

# ============================================
# Example 6: With RBAC Assignments
# ============================================

module "key_vault_with_rbac" {
  source = "../"

  providers = {
    azurerm           = azurerm
    azurerm.primary       = azurerm.primary
    azurerm.secondary = azurerm.secondary
  }

  resource_group_name  = "rg-myapp-prod"
  environment          = "prod"
  virtual_network_name = "vnet-spoke-prod"
  subnet_name          = "subnet-privateendpoints"

  enable_primary_private_endpoint = true

  # Grant secret management permissions
  secret_officers = [
    "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",  # DevOps Service Principal
  ]

  # Grant read-only secret access
  secret_users = [
    "11111111-2222-3333-4444-555555555555",  # Application Managed Identity
    "66666666-7777-8888-9999-000000000000",  # Web App Managed Identity
  ]

  tags = {
    Environment = "production"
  }
}

# ============================================
# Outputs
# ============================================

output "basic_key_vault_id" {
  description = "The ID of the basic Key Vault"
  value       = module.key_vault_basic.key_vault_id
}

output "basic_key_vault_uri" {
  description = "The URI of the basic Key Vault"
  value       = module.key_vault_basic.key_vault_uri
}

output "basic_key_vault_name" {
  description = "The name of the basic Key Vault"
  value       = module.key_vault_basic.key_vault_name
}
