# Migration Guide: Legacy to Modern Module

This guide helps you migrate from the legacy version of this Key Vault module to the modern version that supports `count`, `for_each`, and `depends_on`.

## What Changed?

### Summary

The module has been modernized to follow current Terraform best practices:

- ✅ **Removed internal provider configurations** - Providers are now passed from the caller
- ✅ **Removed subscription ID variables** - Subscription configuration is now handled via providers
- ✅ **Added support for `count`, `for_each`, and `depends_on`** - Module is no longer "legacy"

### Breaking Changes

1. **Provider Configuration**: You must now configure and pass providers to the module
2. **Variable Removal**: The following variables have been removed:
   - `spoke_subscription_id`
   - `hub_subscription_id`
   - `secondary_subscription_id`

## Migration Steps

### Step 1: Configure Providers in Your Root Module

**Before (Legacy - Not Allowed):**
```hcl
module "key_vault" {
  source = "./tfmodule-keyvault"

  spoke_subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  hub_subscription_id   = "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"
  
  # ... other variables
}
```

**After (Modern - Required):**
```hcl
# First, configure providers in your root module
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
  subscription_id = var.spoke_subscription_id
}

provider "azurerm" {
  alias           = "hub"
  features {}
  subscription_id = var.hub_subscription_id
}

provider "azurerm" {
  alias           = "secondary"
  features {}
  subscription_id = var.secondary_subscription_id
}

# Then pass providers to the module
module "key_vault" {
  source = "./tfmodule-keyvault"

  providers = {
    azurerm           = azurerm           # Spoke subscription
    azurerm.primary       = azurerm.primary       # Hub subscription
    azurerm.secondary = azurerm.secondary # Secondary subscription
  }

  # Remove subscription_id variables - no longer needed!
  # spoke_subscription_id = "xxx"  # DELETE THIS
  # hub_subscription_id   = "yyy"  # DELETE THIS
  
  # Keep all other variables the same
  resource_group_name = "rg-myapp-prod"
  environment         = "prod"
  # ... rest of your configuration
}
```

### Step 2: Update Your Variables

Create or update your root module's `variables.tf`:

```hcl
variable "spoke_subscription_id" {
  description = "Subscription ID for spoke (Key Vault)"
  type        = string
}

variable "hub_subscription_id" {
  description = "Subscription ID for hub (Primary DNS)"
  type        = string
}

variable "secondary_subscription_id" {
  description = "Subscription ID for secondary (Secondary DNS)"
  type        = string
  default     = null  # Optional
}
```

### Step 3: Update Your tfvars Files

Your `terraform.tfvars` values can stay the same, but they're now used in provider configuration:

```hcl
# terraform.tfvars
spoke_subscription_id     = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
hub_subscription_id       = "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"
secondary_subscription_id = "zzzzzzzz-zzzz-zzzz-zzzz-zzzzzzzzzzzz"
```

## Complete Migration Examples

### Example 1: Single Key Vault

**Before (Legacy):**
```hcl
module "key_vault" {
  source = "./tfmodule-keyvault"

  spoke_subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  hub_subscription_id   = "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"
  
  resource_group_name  = "rg-myapp-prod"
  environment          = "prod"
  virtual_network_name = "vnet-spoke-prod"
  subnet_name          = "subnet-privateendpoints"
}
```

**After (Modern):**
```hcl
# Provider configuration (add this to your root module)
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
  subscription_id = var.spoke_subscription_id
}

provider "azurerm" {
  alias           = "hub"
  features {}
  subscription_id = var.hub_subscription_id
}

provider "azurerm" {
  alias           = "secondary"
  features {}
  subscription_id = var.hub_subscription_id  # Can reuse hub if no secondary needed
}

# Module call
module "key_vault" {
  source = "./tfmodule-keyvault"

  providers = {
    azurerm           = azurerm
    azurerm.primary       = azurerm.primary
    azurerm.secondary = azurerm.secondary
  }

  # Subscription IDs removed - configured via providers now
  resource_group_name  = "rg-myapp-prod"
  environment          = "prod"
  virtual_network_name = "vnet-spoke-prod"
  subnet_name          = "subnet-privateendpoints"
}
```

### Example 2: With Secondary Private Endpoint

**Before (Legacy):**
```hcl
module "key_vault" {
  source = "./tfmodule-keyvault"

  spoke_subscription_id     = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  hub_subscription_id       = "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"
  secondary_subscription_id = "zzzzzzzz-zzzz-zzzz-zzzz-zzzzzzzzzzzz"
  
  resource_group_name               = "rg-myapp-prod"
  environment                       = "prod"
  enable_secondary_private_endpoint = true
  
  # Note: secondary_private_dns_zone_name defaults to "privatelink.vaultcore.azure.net"
  secondary_private_dns_zone_resource_group_name = "rg-dns-secondary"
}
```

**After (Modern):**
```hcl
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
  subscription_id = var.spoke_subscription_id
}

provider "azurerm" {
  alias           = "hub"
  features {}
  subscription_id = var.hub_subscription_id
}

provider "azurerm" {
  alias           = "secondary"
  features {}
  subscription_id = var.secondary_subscription_id
}

module "key_vault" {
  source = "./tfmodule-keyvault"

  providers = {
    azurerm           = azurerm
    azurerm.primary       = azurerm.primary
    azurerm.secondary = azurerm.secondary
  }

  resource_group_name               = "rg-myapp-prod"
  environment                       = "prod"
  enable_secondary_private_endpoint = true
  
  # Note: secondary_private_dns_zone_name defaults to "privatelink.vaultcore.azure.net"
  secondary_private_dns_zone_resource_group_name = "rg-dns-secondary"
}
```

## New Capabilities After Migration

Once migrated, you can now use:

### 1. `depends_on` - Control Dependencies

```hcl
module "key_vault" {
  source = "./tfmodule-keyvault"
  
  providers = {
    azurerm           = azurerm
    azurerm.primary       = azurerm.primary
    azurerm.secondary = azurerm.secondary
  }

  depends_on = [
    azurerm_virtual_network.main,
    azurerm_private_dns_zone.hub
  ]
  
  # ... rest of configuration
}
```

### 2. `count` - Conditional Creation

```hcl
module "key_vault" {
  source = "./tfmodule-keyvault"
  count  = var.create_key_vault ? 1 : 0

  providers = {
    azurerm           = azurerm
    azurerm.primary       = azurerm.primary
    azurerm.secondary = azurerm.secondary
  }
  
  # ... rest of configuration
}

# Access outputs:
output "key_vault_id" {
  value = var.create_key_vault ? module.key_vault[0].key_vault_id : null
}
```

### 3. `for_each` - Multiple Instances

```hcl
module "key_vault" {
  source   = "./tfmodule-keyvault"
  for_each = toset(["dev", "test", "prod"])

  providers = {
    azurerm           = azurerm
    azurerm.primary       = azurerm.primary
    azurerm.secondary = azurerm.secondary
  }

  resource_group_name = "rg-myapp-${each.key}"
  environment         = each.key
  key_vault_name      = "kv-myapp-${each.key}"
  
  # ... rest of configuration
}

# Access outputs:
output "key_vault_ids" {
  value = { for k, v in module.key_vault : k => v.key_vault_id }
}
```

## Terraform State Migration

⚠️ **Important**: Changing from the legacy module to modern module does not require recreating resources. Your existing resources will continue to work.

### Recommended Approach

1. **Test in a non-production environment first**
2. **Review the Terraform plan carefully**:
   ```bash
   terraform plan
   ```
3. **Verify no resources are being destroyed/recreated**
4. **Apply the changes**:
   ```bash
   terraform apply
   ```

### What to Expect

The plan should show:
- ✅ No resource changes (just module configuration updates)
- ✅ Resources remain in-place
- ✅ Only provider references are updated

If Terraform wants to recreate resources, **STOP** and review the configuration carefully.

## Troubleshooting

### Error: "Module does not support depends_on"

**Cause**: You're still using the legacy module with internal providers.

**Solution**: Complete the migration steps above. Ensure `providers.tf` is deleted from the module directory.

### Error: "Missing required provider configuration"

**Cause**: You didn't pass all required providers to the module.

**Solution**: Ensure you pass all three providers:
```hcl
providers = {
  azurerm           = azurerm
  azurerm.primary       = azurerm.primary
  azurerm.secondary = azurerm.secondary
}
```

### Error: "No configuration files"

**Cause**: The `providers.tf` file was deleted but you forgot to configure providers in root module.

**Solution**: Add provider configurations to your root module as shown in Step 1.

## Rollback Plan

If you need to rollback to the legacy version:

1. Restore the `providers.tf` file from git:
   ```bash
   git checkout HEAD~1 providers.tf
   ```

2. Restore the subscription variables in `variables.tf`:
   ```bash
   git checkout HEAD~1 variables.tf
   ```

3. Update your module calls to remove `providers` blocks and add back subscription IDs

4. Run `terraform init` and `terraform plan` to verify

## Support

If you encounter issues during migration:

1. Check the error message carefully
2. Verify all provider configurations are correct
3. Ensure subscription IDs are in the right places (provider configs, not module variables)
4. Review the examples in this guide
5. Open an issue in the repository with details

## Version Compatibility

- **Legacy Version**: Terraform >= 1.5.0, but did not support `count`, `for_each`, `depends_on`
- **Modern Version**: Terraform >= 1.5.0, full support for `count`, `for_each`, `depends_on`

Both versions require `azurerm` provider >= 3.70.0.
