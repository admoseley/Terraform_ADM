# Provider requirements for the webserver module. Child modules should declare
# the providers they use (with version constraints) even though the provider
# itself is configured and passed down from the root module.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0"
    }
  }
}
