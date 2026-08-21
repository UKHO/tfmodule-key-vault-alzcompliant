# Azure Key Vault Terraform Module

This Terraform module creates an Azure Key Vault using the Azure Verified Module (AVM) with secure configurations including support for multiple private endpoints across different Azure subscriptions.

## Features

- ✅ Uses Azure Verified Module (AVM) for Key Vault
- ✅ **Multi-subscription support** - Hub-and-spoke architecture ready
- ✅ **Dual private endpoints** - Support for primary and secondary private endpoints
- ✅ **Flexible networking** - Connect to same or different subnets
- ✅ **Multiple DNS zones** - Support for private DNS zones in different subscriptions
- ✅ **RBAC role assignments** - Built-in support for Key Vault Secrets Officer and Secrets User roles
- ✅ Private endpoint with existing private DNS zone integration
- ✅ Public network access disabled
- ✅ Purge protection enabled
- ✅ Soft delete with 7-day retention
- ✅ Telemetry disabled
- ✅ Network ACLs with deny-by-default policy
- ✅ Automatic tenant ID detection

## Architecture

This module supports flexible hub-and-spoke architectures:

```
┌─────────────────────────────────────────────────────────────┐
│  Spoke Subscription (Key Vault Lives Here)                  │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Key Vault                                           │   │
│  │  ├─ Private Endpoint 1 (Primary)   ────────┐       │   │
│  │  └─ Private Endpoint 2 (Secondary) ────┐   │       │   │
│  └────────────────────────────────────│───│───┘       │   │
│                                        │   │           │   │
│  ┌─────────────────────────────────┐  │   │           │   │
│  │  VNet (Spoke)                    │  │   │           │   │
│  │  └─ Subnet (Private Endpoints)───┼──┘   │           │   │
│  └──────────────────────────────────┘       │           │   │
└─────────────────────────────────────────────┼───────────┘   │
                                              │               │
┌─────────────────────────────────────────────┼───────────┐   │
│  Hub Subscription (Shared Networking)       │           │   │
│  ┌──────────────────────────────────────────┘           │   │
│  │  Private DNS Zone (Primary)                          │   │
│  │  privatelink.vaultcore.azure.net                     │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                                              │
┌─────────────────────────────────────────────┼───────────┐
│  Secondary Subscription (Optional)          │           │
│  ┌──────────────────────────────────────────┘           │
│  │  Private DNS Zone (Secondary)                        │
│  │  privatelink.vaultcore.azure.net                     │
│  └──────────────────────────────────────────────────────┘
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

Before using this module, ensure you have:

1. **Spoke Subscription**: Where the Key Vault will be created
   - Existing Azure Resource Group
   - Existing Virtual Network and Subnet (for private endpoints)

2. **Hub Subscription**: For shared networking resources
   - Existing Private DNS Zone (`privatelink.vaultcore.azure.net`)

3. **Secondary Subscription** (Optional): For additional DNS resolution
   - Existing Private DNS Zone (if you want a second private endpoint)

4. Appropriate permissions to create resources in all subscriptions

## Provider Configuration

This module requires provider configurations to be passed from the caller. The module expects:

- **Default `azurerm` provider**: For the spoke subscription (where Key Vault resources are created)
- **`azurerm.primary` provider**: For the hub subscription (where primary DNS zone resides)
- **`azurerm.secondary` provider**: For the secondary subscription (optional, for secondary DNS zone)

**Important**: Configure these providers in your root module before calling this module. Example:

```hcl
# Root module provider configuration
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
```

Then pass these providers to the module using the `providers` argument (see usage examples below).

## Usage

### Scenario 1: Single Private Endpoint (Basic)

Single private endpoint with DNS in hub subscription:

```hcl
module "key_vault" {
  source = "./tfmodule-keyvault"

  # Provider configurations (REQUIRED)
  providers = {
    azurerm           = azurerm           # Spoke subscription
    azurerm.primary       = azurerm.primary       # Hub subscription
    azurerm.secondary = azurerm.secondary # Secondary subscription (required even if not used)
  }

  # Required variables
  resource_group_name = "rg-myapp-prod"
  environment         = "prod"

  # Networking (shared by both endpoints)
  virtual_network_name                = "vnet-spoke-prod"
  subnet_name                         = "subnet-privateendpoints"
  virtual_network_resource_group_name = "rg-network-prod"

  # DNS Configuration (in hub)
  private_dns_zone_name                = "privatelink.vaultcore.azure.net"
  private_dns_zone_resource_group_name = "rg-dns-hub"

  # Private Endpoint Configuration
  enable_primary_private_endpoint   = true
  enable_secondary_private_endpoint = false

  # Optional: Custom Key Vault name
  key_vault_name = "kv-myapp-prod-001"

  tags = {
    Environment = "production"
    Application = "myapp"
  }
}
```

### Scenario 2: Dual Private Endpoints (Same Subnet, Different DNS Zones)

Both private endpoints in the same subnet, but with DNS zones in different subscriptions:

```hcl
module "key_vault" {
  source = "./tfmodule-keyvault"

  # Provider configurations (REQUIRED)
  providers = {
    azurerm           = azurerm           # Spoke subscription
    azurerm.primary       = azurerm.primary       # Hub subscription
    azurerm.secondary = azurerm.secondary # Secondary subscription
  }

  # Required variables
  resource_group_name = "rg-myapp-prod"
  environment         = "prod"

  # Shared Networking (both endpoints use this)
  virtual_network_name                = "vnet-spoke-prod"
  subnet_name                         = "subnet-privateendpoints"
  virtual_network_resource_group_name = "rg-network-prod"

  # Primary DNS Configuration (in hub subscription)
  private_dns_zone_name                = "privatelink.vaultcore.azure.net"
  private_dns_zone_resource_group_name = "rg-dns-hub"

  # Enable both private endpoints
  enable_primary_private_endpoint   = true
  enable_secondary_private_endpoint = true

  # Secondary DNS Configuration (in secondary subscription)

  # Note: secondary_private_dns_zone_name defaults to "privatelink.vaultcore.azure.net"

  secondary_private_dns_zone_resource_group_name = "rg-dns-secondary"

  key_vault_name = "kv-myapp-prod-001"

  tags = {
    Environment = "production"
  }
}
```

### Scenario 3: Dual Private Endpoints (Different Subnets)

Private endpoints in different subnets (e.g., different regions or networks):

```hcl
module "key_vault" {
  source = "./tfmodule-keyvault"

  # Provider configurations (REQUIRED)
  providers = {
    azurerm           = azurerm           # Spoke subscription
    azurerm.primary       = azurerm.primary       # Hub subscription
    azurerm.secondary = azurerm.secondary # Secondary subscription
  }

  resource_group_name = "rg-myapp-prod"
  environment         = "prod"


  # Shared defaults (used by primary)
  virtual_network_name                = "vnet-spoke-uksouth"
  subnet_name                         = "subnet-pe-uksouth"
  virtual_network_resource_group_name = "rg-network-uksouth"

  private_dns_zone_name                = "privatelink.vaultcore.azure.net"
  private_dns_zone_resource_group_name = "rg-dns-hub"

  # Enable both endpoints
  enable_primary_private_endpoint   = true
  enable_secondary_private_endpoint = true

  # Override networking for secondary endpoint
  secondary_virtual_network_name                 = "vnet-spoke-ukwest"
  secondary_subnet_name                          = "subnet-pe-ukwest"
  secondary_virtual_network_resource_group_name  = "rg-network-ukwest"
  
  # Secondary DNS zone (uses default name)

  secondary_private_dns_zone_resource_group_name = "rg-dns-secondary"

  key_vault_name = "kv-myapp-prod-001"
}
```

### Scenario 4: Toggle Private Endpoints On/Off

Enable or disable endpoints independently:

```hcl
# Deploy with only secondary endpoint
enable_primary_private_endpoint   = false
enable_secondary_private_endpoint = true

# Or deploy with both
enable_primary_private_endpoint   = true
enable_secondary_private_endpoint = true

# Or deploy with neither (for testing public access scenarios)
enable_primary_private_endpoint   = false
enable_secondary_private_endpoint = false
```

### Scenario 6: Using with `count` (Multiple Key Vaults)

Create multiple Key Vaults conditionally:

```hcl
module "key_vault" {
  source = "./tfmodule-keyvault"
  count  = var.create_key_vault ? 1 : 0

  providers = {
    azurerm           = azurerm
    azurerm.primary       = azurerm.primary
    azurerm.secondary = azurerm.secondary
  }

  resource_group_name = "rg-myapp-prod"
  environment         = "prod"
  
  virtual_network_name = "vnet-spoke-prod"
  subnet_name          = "subnet-privateendpoints"
  
  enable_primary_private_endpoint = true
}
```

### Scenario 7: Using with `for_each` (Multiple Environments)

Create Key Vaults for multiple environments:

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
  
  virtual_network_name = "vnet-spoke-${each.key}"
  subnet_name          = "subnet-privateendpoints"
  
  enable_primary_private_endpoint = true

  tags = {
    Environment = each.key
  }
}
```

### Scenario 8: Using with `depends_on` (Resource Dependencies)

Ensure Key Vault is created after specific resources:

```hcl
resource "azurerm_resource_group" "main" {
  name     = "rg-myapp-prod"
  location = "UK South"
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-spoke-prod"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = ["10.0.0.0/16"]
}

module "key_vault" {
  source = "./tfmodule-keyvault"

  providers = {
    azurerm           = azurerm
    azurerm.primary       = azurerm.primary
    azurerm.secondary = azurerm.secondary
  }

  # Ensure network is fully configured before creating Key Vault
  depends_on = [
    azurerm_virtual_network.main,
    azurerm_subnet.main,
    azurerm_private_dns_zone_virtual_network_link.hub
  ]

  resource_group_name  = azurerm_resource_group.main.name
  environment          = "prod"
  virtual_network_name = azurerm_virtual_network.main.name
  subnet_name          = "subnet-privateendpoints"
  
  enable_primary_private_endpoint = true
}
```

### Scenario 9: RBAC Role Assignments


Grant service principals or managed identities access to manage or read secrets:

```hcl
module "key_vault" {
  source = "./tfmodule-keyvault"

  # Provider configurations (REQUIRED)
  providers = {
    azurerm           = azurerm
    azurerm.primary       = azurerm.primary
    azurerm.secondary = azurerm.secondary
  }

  # ... other configuration ...

  # Grant full secret management permissions (create, read, update, delete)
  secret_officers = [
    "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",  # DevOps Service Principal
    "ffffffff-gggg-hhhh-iiii-jjjjjjjjjjjj"   # Admin Managed Identity
  ]

  # Grant read-only secret access
  secret_users = [
    "11111111-2222-3333-4444-555555555555",  # Application Managed Identity
    "66666666-7777-8888-9999-000000000000",  # Web App Managed Identity
    "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"   # Function App Managed Identity
  ]

  tags = {
    Environment = "production"
  }
}
```

**Important Notes:**
- Use **principal IDs** (Object IDs), not Application IDs
- For Service Principals: Find in Azure AD → Enterprise Applications → Object ID
- For Managed Identities: Find in the managed identity resource → Properties → Principal ID
- Secrets should **not** be managed in Terraform to avoid state file exposure

## Module Features

✅ **Modern Terraform Module** - No internal provider configurations, fully compatible with:
- `depends_on` - Control module dependencies
- `count` - Create multiple instances conditionally
- `for_each` - Create multiple instances from a map or set

✅ **Multi-Provider Support** - Accepts provider configurations from caller for flexible multi-subscription deployments

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| azurerm | >= 3.70.0 |
| random | >= 3.4.0 |

## Providers

This module expects the following providers to be configured by the caller:

| Provider Alias | Purpose |
|----------------|---------|
| `azurerm` (default) | Spoke subscription - Where Key Vault and its resources are created |
| `azurerm.primary` | Hub subscription - For primary private DNS zone lookups |
| `azurerm.secondary` | Secondary subscription - For secondary private DNS zone (optional but must be configured) |
| `random` | Generates unique suffixes for resource naming |

## Inputs

### Required Variables

| Name | Description | Type | Required |
|------|-------------|------|:--------:|
| resource_group_name | Name of the existing resource group where the Key Vault will be created | `string` | yes |
| environment | Environment name (e.g., dev, test, prod) | `string` | yes |
| virtual_network_name | Name of the existing virtual network (used by both private endpoints unless overridden) | `string` | yes |
| subnet_name | Name of the existing subnet for private endpoints (used by both unless overridden) | `string` | yes |

### Private Endpoint Control

| Name | Description | Type | Default |
|------|-------------|------|---------|
| enable_primary_private_endpoint | Enable or disable the primary private endpoint | `bool` | `true` |
| enable_secondary_private_endpoint | Enable or disable the secondary private endpoint | `bool` | `false` |

### Primary Private Endpoint Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| primary_virtual_network_name | Override VNet for primary endpoint | `string` | Uses `virtual_network_name` |
| primary_subnet_name | Override subnet for primary endpoint | `string` | Uses `subnet_name` |
| primary_virtual_network_resource_group_name | Override VNet RG for primary endpoint | `string` | Uses `virtual_network_resource_group_name` |
| primary_private_endpoint_name | Custom name for primary private endpoint | `string` | `{key_vault_name}-pe-primary` |
| primary_network_interface_name | Custom name for primary NIC | `string` | `{key_vault_name}-pe-primary-nic` |
| primary_private_service_connection_name | Custom name for primary PSC | `string` | `psc-{key_vault_name}-primary` |

### Secondary Private Endpoint Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| secondary_virtual_network_name | Override VNet for secondary endpoint | `string` | Uses `virtual_network_name` |
| secondary_subnet_name | Override subnet for secondary endpoint | `string` | Uses `subnet_name` |
| secondary_virtual_network_resource_group_name | Override VNet RG for secondary endpoint | `string` | Uses `virtual_network_resource_group_name` |
| secondary_private_dns_zone_name | Name of private DNS zone for secondary endpoint | `string` | `privatelink.vaultcore.azure.net` |
| secondary_private_dns_zone_resource_group_name | Resource group of secondary DNS zone | `string` | `null` |
| create_secondary_dns_zone_vnet_links | Create virtual network links for secondary DNS zone | `bool` | `true` |
| secondary_private_endpoint_name | Custom name for secondary private endpoint | `string` | `{key_vault_name}-pe-secondary` |
| secondary_network_interface_name | Custom name for secondary NIC | `string` | `{key_vault_name}-pe-secondary-nic` |
| secondary_private_service_connection_name | Custom name for secondary PSC | `string` | `psc-{key_vault_name}-secondary` |

### Optional Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| key_vault_name | Custom name for the Key Vault | `string` | `{environment}-{random}-kv` |
| sku_name | Key Vault SKU (standard or premium) | `string` | `standard` |
| virtual_network_resource_group_name | Resource group of VNet (if different) | `string` | `resource_group_name` |
| private_dns_zone_name | Primary DNS zone name | `string` | `privatelink.vaultcore.azure.net` |
| private_dns_zone_resource_group_name | Primary DNS zone resource group | `string` | `resource_group_name` |
| allowed_ip_ranges | IP ranges allowed to access Key Vault | `list(string)` | `[]` |
| additional_subnet_ids | Additional subnet IDs allowed to access | `list(string)` | `[]` |
| secret_officers | Principal IDs to grant Key Vault Secrets Officer role | `list(string)` | `[]` |
| secret_users | Principal IDs to grant Key Vault Secrets User role | `list(string)` | `[]` |
| tags | Tags to assign to resources | `map(string)` | `{}` |

## Outputs

### Key Vault Outputs

| Name | Description |
|------|-------------|
| key_vault_id | The ID of the Key Vault |
| key_vault_name | The name of the Key Vault |
| key_vault_uri | The URI of the Key Vault |
| key_vault_location | The location of the Key Vault |
| key_vault_resource_group_name | The resource group containing the Key Vault |
| key_vault_tenant_id | The tenant ID of the Key Vault |

### Private Endpoint Outputs

| Name | Description |
|------|-------------|
| private_endpoints | Information about all private endpoints |
| primary_private_endpoint_enabled | Whether primary endpoint is enabled |
| secondary_private_endpoint_enabled | Whether secondary endpoint is enabled |
| primary_virtual_network_id | Primary VNet ID |
| primary_subnet_id | Primary subnet ID |
| secondary_virtual_network_id | Secondary VNet ID (if enabled) |
| secondary_subnet_id | Secondary subnet ID (if enabled) |
| primary_dns_zone_id | Primary DNS zone ID |
| secondary_dns_zone_id | Secondary DNS zone ID (if configured) |
| secondary_dns_zone_vnet_link_id | Secondary DNS zone virtual network link ID (if created) |

### Other Outputs

| Name | Description |
|------|-------------|
| network_acls | Network ACL configuration |
| resource_group_location | Resource group location |
| current_tenant_id | Current tenant ID |
| current_client_id | Current client ID |
| secret_officers | Principal IDs granted Secrets Officer role |
| secret_users | Principal IDs granted Secrets User role |

## Private DNS Zone Virtual Network Links

### Automatic Link Creation

The module automatically creates virtual network links for the secondary private DNS zone when:

1. **Secondary private endpoint is enabled** (`enable_secondary_private_endpoint = true`)
2. **Secondary DNS zone is in a different subscription** (`secondary_private_dns_zone_resource_group_name` is specified)
3. **Link creation is enabled** (`create_secondary_dns_zone_vnet_links = true` - default)

### Scenarios Covered

| Scenario | Description | Link Created |
|----------|-------------|--------------|
| **Spoke networking** | Secondary endpoint uses spoke VNet, DNS zone in secondary subscription | ✅ Links secondary DNS zone → spoke VNet |
| **Secondary networking** | Secondary endpoint uses secondary VNet, DNS zone in secondary subscription | ✅ Links secondary DNS zone → secondary VNet |
| **Same subscription** | DNS zone in same subscription as VNet | ❌ Not needed - Azure handles this |
| **Primary DNS zone** | Primary DNS zone already has links | ❌ Not created - assumed to exist |

### Disabling Link Creation

If you manage DNS zone links externally:

```hcl
module "key_vault" {
  # ... other configuration ...
  
  create_secondary_dns_zone_vnet_links = false
}
```

## Security Configuration

This module implements several security best practices:

- **Private Endpoints**: All traffic routed through private endpoints
- **Multi-Subscription Support**: Isolate DNS zones and networking
- **Network ACLs**: Default deny policy with explicit allow rules
- **Public Access**: Disabled by default
- **Purge Protection**: Enabled to prevent accidental deletion
- **Soft Delete**: 7-day retention period for recovery
- **Flexible Access Control**: Support for multiple private endpoints
- **RBAC Role Assignments**: Built-in support for Key Vault Secrets Officer and Secrets User roles
- **No Secrets in State**: Module does not manage secrets to avoid state file exposure

## RBAC Roles

The module supports automatic assignment of the following Azure RBAC roles:

### Key Vault Secrets Officer
- **Purpose**: Full secret management capabilities
- **Permissions**: Create, read, update, delete, list secrets
- **Use Case**: DevOps pipelines, administrators, secret rotation services
- **Variable**: `secret_officers`

### Key Vault Secrets User
- **Purpose**: Read-only secret access
- **Permissions**: Read and list secrets
- **Use Case**: Applications, microservices, functions that only need to read secrets
- **Variable**: `secret_users`

### Finding Principal IDs

**For Service Principals:**
```bash
az ad sp show --id <application-id> --query id -o tsv
```

**For Managed Identities:**
```bash
az identity show --name <identity-name> --resource-group <rg-name> --query principalId -o tsv
```

**For User-Assigned Managed Identities attached to resources:**
```bash
# For VM
az vm identity show --name <vm-name> --resource-group <rg-name> --query principalId -o tsv

# For App Service
az webapp identity show --name <app-name> --resource-group <rg-name> --query principalId -o tsv
```

## Secret Management Best Practices

⚠️ **Important**: This module does **not** manage Key Vault secrets directly to avoid the following issues:

1. **State File Security**: Secrets stored in Terraform state are in plain text
2. **Drift Management**: External secret updates will be overwritten by Terraform
3. **Rotation Complexity**: Secret rotation is difficult when managed by infrastructure code

### Recommended Secret Management Approaches

**Option 1: Use RBAC + External Management**
```hcl
# Grant permissions in Terraform
secret_officers = ["service-principal-id"]

# Then manage secrets separately using:
# - Azure CLI: az keyvault secret set
# - Azure PowerShell: Set-AzKeyVaultSecret
# - Azure DevOps variable groups
# - GitHub Actions secrets
# - Application code with Azure SDK
```

**Option 2: Separate Secrets Module (for initial population only)**
Create a separate Terraform workspace/state for one-time secret population, then manage externally.

**Option 3: Azure DevOps/GitHub Pipelines**
Use pipeline tasks to populate secrets after Key Vault creation.

## File Structure

```
tfmodule-keyvault/
├── versions.tf          # Terraform and provider version requirements
├── providers.tf         # Provider configurations (spoke, hub, secondary)
├── data.tf             # All data sources (networking, DNS zones)
├── locals.tf           # Computed values and configurations
├── resources.tf        # Direct resource creation (random string)
├── keyvault.tf         # Key Vault module configuration
├── rbac.tf             # RBAC role assignments
├── variables.tf        # Input variable definitions
├── outputs.tf          # Output value definitions
├── terraform.tfvars    # Variable values (gitignore this!)
└── README.md          # This file
```

## Common Use Cases

### 1. Hub-and-Spoke with Single DNS Zone
Most common scenario - Key Vault in spoke, DNS in hub:
```hcl
enable_primary_private_endpoint   = true
enable_secondary_private_endpoint = false
```

### 2. Multi-Subscription DNS Resolution
Key Vault accessible from multiple subscriptions via different DNS zones:
```hcl
enable_primary_private_endpoint   = true
enable_secondary_private_endpoint = true
secondary_subscription_id         = "different-subscription-id"
```

### 3. Disaster Recovery Setup
Primary and secondary endpoints in different regions:
```hcl
enable_primary_private_endpoint   = true
enable_secondary_private_endpoint = true
secondary_virtual_network_name    = "vnet-dr-region"
secondary_subnet_name             = "subnet-pe-dr"
```

### 4. Grant Application Access
Managed identities for applications need secret access:
```hcl
secret_users = [
  "11111111-2222-3333-4444-555555555555"  # App Service Managed Identity
]
```

## Troubleshooting

### DNS Resolution Issues
If you can't resolve the Key Vault hostname:
1. Verify private DNS zone is linked to the VNet
2. Check the private endpoint is in "Approved" state
3. Ensure DNS zone resource group name is correct

### Multiple Subscriptions
When using multiple subscriptions:
1. Ensure you have appropriate RBAC permissions in all subscriptions
2. Verify provider configurations have correct subscription IDs
3. Check that networking resources exist in the specified subscriptions

### Private Endpoint Connection
If private endpoint fails to create:
1. Verify subnet has no network policies blocking private endpoints
2. Check subnet has available IP addresses
3. Ensure Key Vault resource provider is registered

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Update documentation
6. Submit a pull request

## License

This module is licensed under the MIT License. See LICENSE file for details.

## Support

For issues, questions, or contributions, please open an issue in the repository.