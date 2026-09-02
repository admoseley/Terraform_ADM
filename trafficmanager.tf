# ===========================================================================
# Global round-robin load balancing across the two regional webservers
# using Azure Traffic Manager (DNS-based, weighted routing with equal weights).
# ===========================================================================

# Resource group to hold the global (region-agnostic) resource.
resource "azurerm_resource_group" "global" {
  name     = "Moseley_Development_Global"
  location = "centralus"
  tags     = var.tags
}

resource "azurerm_traffic_manager_profile" "web" {
  name                   = "tm-moseley-web"
  resource_group_name    = azurerm_resource_group.global.name
  traffic_routing_method = "Weighted" # equal weights on endpoints == round robin
  tags                   = var.tags

  dns_config {
    relative_name = var.traffic_manager_dns_name
    ttl           = 30 # low TTL so clients re-resolve (and re-balance) often
  }

  # Health probe: pull a region out automatically when its VM is down
  # (e.g. during the nightly 10pm-8am deallocation window).
  monitor_config {
    protocol                     = "HTTP"
    port                         = 80
    path                         = "/"
    interval_in_seconds          = 30
    timeout_in_seconds           = 10
    tolerated_number_of_failures = 3
  }
}

resource "azurerm_traffic_manager_external_endpoint" "central" {
  name       = "central"
  profile_id = azurerm_traffic_manager_profile.web.id
  target     = module.central.public_ip_address
  weight     = 1 # equal weight -> round robin
}

resource "azurerm_traffic_manager_external_endpoint" "east" {
  name       = "east"
  profile_id = azurerm_traffic_manager_profile.web.id
  target     = module.east.public_ip_address
  weight     = 1 # equal weight -> round robin
}
