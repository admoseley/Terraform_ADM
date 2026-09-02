variable "name" {
  description = "Short identifier used in resource names (e.g. central, east)."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group for this stack."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "vnet_address_space" {
  description = "The /24 address space for the virtual network."
  type        = string
}

variable "subnet_address_prefix" {
  description = "Address prefix for the web subnet."
  type        = string
}

variable "vm_size" {
  description = "VM size."
  type        = string
}

variable "admin_username" {
  description = "Admin username for the Debian VM."
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key used for VM login."
  type        = string
}

variable "allowed_ssh_source" {
  description = "CIDR allowed to reach SSH (port 22). Empty string means SSH is disabled (no rule created)."
  type        = string

  validation {
    condition     = var.allowed_ssh_source != "*"
    error_message = "allowed_ssh_source must not be \"*\" (open to the internet). Use a specific CIDR like 203.0.113.4/32, or \"\" to disable SSH."
  }
}

variable "server_label" {
  description = "Human-friendly server identity shown on the welcome page (e.g. \"Server A\")."
  type        = string
}

variable "server_accent_color" {
  description = "CSS background color for the welcome page, to visually distinguish servers."
  type        = string
  default     = "#1e6fd9"
}

variable "schedule_utc_offset" {
  description = "UTC offset anchoring the first scheduled run."
  type        = string
}

variable "startup_time" {
  description = "Daily power-up time (24h HH:MM), Central Time."
  type        = string
}

variable "shutdown_time" {
  description = "Daily power-down time (24h HH:MM), Central Time."
  type        = string
}

variable "safety_shutdown_time" {
  description = "Native auto-shutdown safety-net time (24h HHmm), Central Time."
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
}
