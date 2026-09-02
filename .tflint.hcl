# TFLint configuration.
# The azurerm plugin adds Azure-provider-specific lint rules on top of the
# core Terraform rules.

config {
  # Lint called modules too (our webserver module).
  call_module_type = "all"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "azurerm" {
  enabled = true
  version = "0.28.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}
