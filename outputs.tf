output "central" {
  description = "Central US stack details."
  value = {
    resource_group = module.central.resource_group_name
    location       = module.central.location
    network        = module.central.vnet_address_space
    public_ip      = module.central.public_ip_address
    web_url        = module.central.web_url
    ssh            = module.central.ssh_command
  }
}

output "load_balancer" {
  description = "Traffic Manager global endpoint (round-robin across both regions)."
  value = {
    fqdn = azurerm_traffic_manager_profile.web.fqdn
    url  = "http://${azurerm_traffic_manager_profile.web.fqdn}"
  }
}

output "east" {
  description = "East US stack details."
  value = {
    resource_group = module.east.resource_group_name
    location       = module.east.location
    network        = module.east.vnet_address_space
    public_ip      = module.east.public_ip_address
    web_url        = module.east.web_url
    ssh            = module.east.ssh_command
  }
}
