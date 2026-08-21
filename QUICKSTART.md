# Quick Start: Modern Module Usage

## Minimal Working Example

```terraform
# 1. Configure providers in your root module
provider "azurerm" {
  features {}
  subscription_id = "YOUR-SPOKE-SUBSCRIPTION-ID"
}

provider "azurerm" {
  alias           = "hub"
  features {}
  subscription_id = "YOUR-HUB-SUBSCRIPTION-ID"
}

provider "azurerm" {
  alias           = "secondary"
  features {}
  subscription_id = "YOUR-HUB-SUBSCRIPTION-ID"  # Can reuse hub if no secondary needed
}

# 2. Call the module
module "key_vault" {
  source = "./tfmodule-key-vault-alzcompliant"

  # Pass providers (REQUIRED)
  providers = {
    azurerm           = azurerm
    azurerm.primary       = azurerm.primary
    azurerm.secondary = azurerm.secondary
  }

  # Required parameters
  resource_group_name  = "rg-myapp-prod"
  environment          = "prod"
  virtual_network_name = "vnet-spoke-prod"
  subnet_name          = "subnet-privateendpoints"

  # Optional: Enable private endpoint
  enable_primary_private_endpoint = true
}
```

## Now You Can Use:

### ✅ count
```terraform
module "key_vault" {
  source = "./tfmodule-key-vault-alzcompliant"
  count  = var.create_key_vault ? 1 : 0

  providers = {
    azurerm           = azurerm
    azurerm.primary       = azurerm.primary
    azurerm.secondary = azurerm.secondary
  }
  # ... rest of config
}
```

### ✅ for_each
```terraform
module "key_vault" {
  source   = "./tfmodule-key-vault-alzcompliant"
  for_each = toset(["dev", "test", "prod"])

  providers = {
    azurerm           = azurerm
    azurerm.primary       = azurerm.primary
    azurerm.secondary = azurerm.secondary
  }
  environment = each.key
  # ... rest of config
}
```

### ✅ depends_on
```terraform
module "key_vault" {
  source = "./tfmodule-key-vault-alzcompliant"

  depends_on = [
    azurerm_virtual_network.main,
    azurerm_subnet.main
  ]

  providers = {
    azurerm           = azurerm
    azurerm.primary       = azurerm.primary
    azurerm.secondary = azurerm.secondary
  }
  # ... rest of config
}
```

## Key Points

1. **Always pass providers** - The `providers` block is required
2. **No subscription variables** - Configure subscriptions in provider blocks, not module variables
3. **Three providers needed** - Even if you only use one subscription, configure all three aliases

## Common Mistake

❌ **Don't do this:**
```terraform
module "key_vault" {
  source = "./tfmodule-key-vault-alzcompliant"
  
  spoke_subscription_id = "xxx"  # ❌ This variable no longer exists
  hub_subscription_id   = "yyy"  # ❌ This variable no longer exists
}
```

✅ **Do this:**
```terraform
provider "azurerm" {
  subscription_id = "xxx"  # ✅ Configure in provider
}

module "key_vault" {
  source = "./tfmodule-key-vault-alzcompliant"
  
  providers = {              # ✅ Pass providers to module
    azurerm = azurerm
    azurerm.primary = azurerm.primary
    azurerm.secondary = azurerm.secondary
  }
}
```

## More Information

- See `README.md` for detailed documentation
- See `MIGRATION.md` for upgrade guide
- See `examples/complete.tf` for comprehensive examples
