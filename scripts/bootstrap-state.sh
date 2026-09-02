#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# One-time bootstrap for the Terraform remote state backend.
#
# Creates a dedicated, hardened Azure Storage account + container to hold
# Terraform state. Run this ONCE before `terraform init`. It is intentionally
# out-of-band (not managed by Terraform) to avoid the chicken-and-egg problem
# of storing the state backend's own state.
#
# Requires: az CLI, logged in (`az login`) with rights to create resources.
# Idempotent-ish: re-running will error on existing resources; that's fine.
#
# After running, put the printed STORAGE_ACCOUNT_NAME into backend.tf.
# ---------------------------------------------------------------------------
set -euo pipefail

RG="${RG:-Moseley_Terraform_State}"
LOC="${LOC:-centralus}"
CONTAINER="${CONTAINER:-tfstate}"
# Storage account names are globally unique, 3-24 lowercase alphanumerics.
SA="${SA:-moseleytfstate$(openssl rand -hex 3)}"

echo "Creating: RG=$RG  SA=$SA  CONTAINER=$CONTAINER  LOC=$LOC"

az group create -n "$RG" -l "$LOC" -o none

# Hardened: TLS1.2 minimum, HTTPS only, no anonymous blob access.
az storage account create -n "$SA" -g "$RG" -l "$LOC" \
  --sku Standard_LRS --kind StorageV2 \
  --min-tls-version TLS1_2 --https-only true \
  --allow-blob-public-access false \
  -o none

# Blob versioning + soft delete so state can be recovered if corrupted/deleted.
az storage account blob-service-properties update \
  --account-name "$SA" -g "$RG" \
  --enable-versioning true \
  --enable-delete-retention true --delete-retention-days 30 \
  -o none

az storage container create -n "$CONTAINER" --account-name "$SA" --auth-mode key -o none

echo ""
echo "Done. Set this in backend.tf:"
echo "  storage_account_name = \"$SA\""
