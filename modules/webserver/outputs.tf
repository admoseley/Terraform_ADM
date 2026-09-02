output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "location" {
  value = azurerm_resource_group.this.location
}

output "vnet_address_space" {
  value = azurerm_virtual_network.this.address_space
}

output "public_ip_address" {
  value = azurerm_public_ip.web.ip_address
}

output "ssh_command" {
  value = "ssh ${var.admin_username}@${azurerm_public_ip.web.ip_address}"
}

output "web_url" {
  value = "http://${azurerm_public_ip.web.ip_address}"
}
