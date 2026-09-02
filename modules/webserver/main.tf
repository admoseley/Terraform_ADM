# ===========================================================================
# webserver module: one resource group with a /24 network and a small
# Debian nginx VM, plus scheduled power on/off and an auto-shutdown safety net.
# ===========================================================================

locals {
  # Anchor schedules to tomorrow so the first run is always in the future.
  schedule_anchor_date = formatdate("YYYY-MM-DD", timeadd(timestamp(), "24h"))
  startup_start_time   = "${local.schedule_anchor_date}T${var.startup_time}:00${var.schedule_utc_offset}"
  shutdown_start_time  = "${local.schedule_anchor_date}T${var.shutdown_time}:00${var.schedule_utc_offset}"
}

# ---------------------------------------------------------------------------
# Resource Group
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ---------------------------------------------------------------------------
# Networking: /24 virtual network + subnet
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.vnet_address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "web" {
  name                 = "snet-${var.name}-web"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.subnet_address_prefix]
}

# ---------------------------------------------------------------------------
# Network Security Group: allow HTTP, HTTPS, and (restricted) SSH
# ---------------------------------------------------------------------------
resource "azurerm_network_security_group" "web" {
  name                = "nsg-${var.name}-web"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # SSH is CLOSED by default. A rule is created only when allowed_ssh_source is
  # set to a real CIDR (e.g. your admin IP). Leaving it empty means no inbound
  # SSH rule exists at all — the most restrictive posture, and it keeps
  # Checkov CKV_AZURE_10 (no SSH from the internet) green.
  dynamic "security_rule" {
    for_each = var.allowed_ssh_source == "" ? [] : [1]
    content {
      name                       = "AllowSSH"
      priority                   = 120
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = var.allowed_ssh_source
      destination_address_prefix = "*"
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web.id
}

# ---------------------------------------------------------------------------
# Public IP + NIC
# ---------------------------------------------------------------------------
resource "azurerm_public_ip" "web" {
  name                = "pip-${var.name}-web"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_interface" "web" {
  name                = "nic-${var.name}-web"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.web.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.web.id
  }
}

# ---------------------------------------------------------------------------
# Debian Linux VM (small footprint webserver)
# ---------------------------------------------------------------------------
resource "azurerm_linux_virtual_machine" "web" {
  name                  = "vm-${var.name}-debian"
  location              = azurerm_resource_group.this.location
  resource_group_name   = azurerm_resource_group.this.name
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.web.id]
  tags                  = var.tags

  # Hardening (Checkov CKV_AZURE_50): we provision via cloud-init (custom_data),
  # not Azure VM extensions, so disable extension operations to reduce the
  # attack surface.
  allow_extension_operations = false

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  # Debian 12 (Bookworm), Gen2
  source_image_reference {
    publisher = "Debian"
    offer     = "debian-12"
    sku       = "12-gen2"
    version   = "latest"
  }

  custom_data = var.custom_data_b64
}

# ---------------------------------------------------------------------------
# Scheduled power on/off via Azure Automation
# ---------------------------------------------------------------------------
resource "azurerm_automation_account" "this" {
  name                = "aa-${var.name}-moseley"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = "Basic"
  tags                = var.tags

  # Hardening (Checkov CKV2_AZURE_24): our scheduled cloud runbooks start/stop
  # the VM via the managed identity calling Azure Resource Manager (outbound),
  # so no inbound public access to the automation account is needed.
  public_network_access_enabled = false

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "automation_vm" {
  scope                = azurerm_resource_group.this.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_automation_account.this.identity[0].principal_id
}

resource "azurerm_automation_runbook" "power" {
  name                    = "Set-VMPowerState"
  location                = azurerm_resource_group.this.location
  resource_group_name     = azurerm_resource_group.this.name
  automation_account_name = azurerm_automation_account.this.name
  log_verbose             = false
  log_progress            = false
  runbook_type            = "PowerShell72"
  description             = "Starts or stops (deallocates) the web VM on a schedule."
  tags                    = var.tags

  content = <<-CONTENT
    param(
      [Parameter(Mandatory = $true)][string]$ResourceGroupName,
      [Parameter(Mandatory = $true)][string]$VMName,
      [Parameter(Mandatory = $true)][ValidateSet("Start", "Stop")][string]$Action
    )

    $ErrorActionPreference = "Stop"
    Disable-AzContextAutosave -Scope Process | Out-Null
    Connect-AzAccount -Identity | Out-Null

    if ($Action -eq "Start") {
      Write-Output "Starting $VMName in $ResourceGroupName"
      Start-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName
    }
    else {
      Write-Output "Deallocating $VMName in $ResourceGroupName"
      Stop-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Force
    }
  CONTENT
}

resource "azurerm_automation_schedule" "startup" {
  name                    = "daily-startup"
  resource_group_name     = azurerm_resource_group.this.name
  automation_account_name = azurerm_automation_account.this.name
  frequency               = "Day"
  interval                = 1
  timezone                = "America/Chicago"
  start_time              = local.startup_start_time
  description             = "Power up the web VM daily."

  lifecycle {
    ignore_changes = [start_time]
  }
}

resource "azurerm_automation_schedule" "shutdown" {
  name                    = "daily-shutdown"
  resource_group_name     = azurerm_resource_group.this.name
  automation_account_name = azurerm_automation_account.this.name
  frequency               = "Day"
  interval                = 1
  timezone                = "America/Chicago"
  start_time              = local.shutdown_start_time
  description             = "Power down (deallocate) the web VM daily."

  lifecycle {
    ignore_changes = [start_time]
  }
}

resource "azurerm_automation_job_schedule" "startup" {
  resource_group_name     = azurerm_resource_group.this.name
  automation_account_name = azurerm_automation_account.this.name
  runbook_name            = azurerm_automation_runbook.power.name
  schedule_name           = azurerm_automation_schedule.startup.name

  parameters = {
    resourcegroupname = azurerm_resource_group.this.name
    vmname            = azurerm_linux_virtual_machine.web.name
    action            = "Start"
  }
}

resource "azurerm_automation_job_schedule" "shutdown" {
  resource_group_name     = azurerm_resource_group.this.name
  automation_account_name = azurerm_automation_account.this.name
  runbook_name            = azurerm_automation_runbook.power.name
  schedule_name           = azurerm_automation_schedule.shutdown.name

  parameters = {
    resourcegroupname = azurerm_resource_group.this.name
    vmname            = azurerm_linux_virtual_machine.web.name
    action            = "Stop"
  }
}

# ---------------------------------------------------------------------------
# Native auto-shutdown safety net (free)
# ---------------------------------------------------------------------------
resource "azurerm_dev_test_global_vm_shutdown_schedule" "safety" {
  virtual_machine_id = azurerm_linux_virtual_machine.web.id
  location           = azurerm_resource_group.this.location
  enabled            = true

  daily_recurrence_time = var.safety_shutdown_time
  timezone              = "Central Standard Time"

  notification_settings {
    enabled = false
  }

  tags = var.tags
}
