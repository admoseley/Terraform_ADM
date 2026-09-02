# Shared inputs applied to both webserver stacks.

variable "vm_size" {
  description = "VM size. B1s is a small, low-cost burstable size well suited to a light webserver."
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Admin username for the Debian VMs."
  type        = string
  default     = "azureadmin"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key used for VM login."
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "allowed_ssh_source" {
  description = "CIDR allowed to reach SSH (port 22). Set to your public IP for safety, e.g. 203.0.113.4/32."
  type        = string
  default     = "*"
}

variable "schedule_utc_offset" {
  description = "UTC offset anchoring the first scheduled run. Chicago is -05:00 during CDT and -06:00 during CST; the America/Chicago timezone handles ongoing DST."
  type        = string
  default     = "-05:00"
}

variable "startup_time" {
  description = "Daily power-up time (24h HH:MM), Central Time."
  type        = string
  default     = "08:00"
}

variable "shutdown_time" {
  description = "Daily power-down time (24h HH:MM), Central Time."
  type        = string
  default     = "22:00"
}

variable "safety_shutdown_time" {
  description = "Native auto-shutdown safety-net time (24h HHmm), Central Time."
  type        = string
  default     = "2230"
}

variable "traffic_manager_dns_name" {
  description = "Global-unique DNS label for the Traffic Manager profile. Resolves to <name>.trafficmanager.net. Must be unique across all of Azure."
  type        = string
  default     = "moseley-dev-web"
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default = {
    environment = "development"
    owner       = "Moseley"
    managed_by  = "terraform"
  }
}
