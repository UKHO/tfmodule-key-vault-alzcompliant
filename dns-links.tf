# Private DNS Zone Virtual Network Links
# These are required when private DNS zones are in different subscriptions than the VNets

# Secondary Private DNS Zone VNet Link (when secondary endpoint uses spoke networking)
# This links the secondary private DNS zone (in secondary subscription) to the spoke VNet
resource "azurerm_private_dns_zone_virtual_network_link" "secondary_to_spoke" {
  count = (
    var.enable_secondary_private_endpoint &&
    var.create_secondary_dns_zone_vnet_links &&
    local.secondary_uses_spoke_networking &&
    var.secondary_private_dns_zone_resource_group_name != null
  ) ? 1 : 0

  provider            = azurerm.secondary
  name                = "link-${var.key_vault_name != null ? var.key_vault_name : "${var.environment}-kv"}-secondary-to-spoke"
  resource_group_name = var.secondary_private_dns_zone_resource_group_name
  private_dns_zone_id = data.azurerm_private_dns_zone.keyvault_secondary[0].id
  virtual_network_id  = data.azurerm_virtual_network.secondary_spoke[0].id
  registration_enabled = false

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      Purpose     = "secondary-dns-zone-link"
      CreatedBy   = "Terraform"
    }
  )
}

# Secondary Private DNS Zone VNet Link (when secondary endpoint uses different networking)
# This links the secondary private DNS zone to the secondary VNet (both in secondary subscription)
resource "azurerm_private_dns_zone_virtual_network_link" "secondary_to_secondary" {
  count = (
    var.enable_secondary_private_endpoint &&
    var.create_secondary_dns_zone_vnet_links &&
    !local.secondary_uses_spoke_networking &&
    var.secondary_private_dns_zone_resource_group_name != null
  ) ? 1 : 0

  provider            = azurerm.secondary
  name                = "link-${var.key_vault_name != null ? var.key_vault_name : "${var.environment}-kv"}-secondary-to-secondary"
  resource_group_name = var.secondary_private_dns_zone_resource_group_name
  private_dns_zone_id = data.azurerm_private_dns_zone.keyvault_secondary[0].id
  virtual_network_id  = data.azurerm_virtual_network.secondary_override[0].id
  registration_enabled = false

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      Purpose     = "secondary-dns-zone-link"
      CreatedBy   = "Terraform"
    }
  )
}