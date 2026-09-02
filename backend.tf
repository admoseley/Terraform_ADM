# ---------------------------------------------------------------------------
# Remote state backend (Azure Storage).
#
# State is stored in a dedicated storage account (created out-of-band by
# scripts/bootstrap-state.sh — see README). The azurerm backend provides state
# locking automatically via a blob lease, so concurrent applies can't corrupt
# state.
#
# Note: backend blocks cannot use variables/interpolation — these values are
# static by design. The storage account NAME is not a secret; the access key is,
# and it is never stored here (Terraform fetches it at runtime using your Azure
# CLI / OIDC credentials).
# ---------------------------------------------------------------------------
terraform {
  backend "azurerm" {
    resource_group_name  = "Moseley_Terraform_State"
    storage_account_name = "moseleytfstate3d4427"
    container_name       = "tfstate"
    key                  = "moseley-dev.terraform.tfstate"
  }
}
