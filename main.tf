# cloud-init is shared by both stacks.
locals {
  custom_data_b64 = base64encode(file("${path.module}/cloud-init.yaml"))
}

# ---------------------------------------------------------------------------
# Central US stack
# ---------------------------------------------------------------------------
module "central" {
  source = "./modules/webserver"

  name                = "central"
  resource_group_name = "Moseley_Development"
  location            = "centralus"

  vnet_address_space    = "10.10.10.0/24"
  subnet_address_prefix = "10.10.10.0/24"

  vm_size             = var.vm_size
  admin_username      = var.admin_username
  ssh_public_key_path = var.ssh_public_key_path
  allowed_ssh_source  = var.allowed_ssh_source
  custom_data_b64     = local.custom_data_b64

  schedule_utc_offset  = var.schedule_utc_offset
  startup_time         = var.startup_time
  shutdown_time        = var.shutdown_time
  safety_shutdown_time = var.safety_shutdown_time

  tags = var.tags
}

# ---------------------------------------------------------------------------
# East US stack (the pair) — separate resource group and non-overlapping /24
# ---------------------------------------------------------------------------
module "east" {
  source = "./modules/webserver"

  name                = "east"
  resource_group_name = "Moseley_Development_East"
  location            = "eastus"

  vnet_address_space    = "10.20.20.0/24"
  subnet_address_prefix = "10.20.20.0/24"

  vm_size             = var.vm_size
  admin_username      = var.admin_username
  ssh_public_key_path = var.ssh_public_key_path
  allowed_ssh_source  = var.allowed_ssh_source
  custom_data_b64     = local.custom_data_b64

  schedule_utc_offset  = var.schedule_utc_offset
  startup_time         = var.startup_time
  shutdown_time        = var.shutdown_time
  safety_shutdown_time = var.safety_shutdown_time

  tags = var.tags
}
