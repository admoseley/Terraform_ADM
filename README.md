# Moseley Development — Azure Multi-Region Webserver (Terraform)

Infrastructure-as-Code for a small, budget-conscious, **multi-region web platform** on
Azure. Two identical Debian + nginx virtual machines run in **Central US** and
**East US**, each in its own resource group and `/24` network, fronted by an
**Azure Traffic Manager** profile that round-robins traffic between them. Both VMs
power themselves **on at 8:00 AM and off at 10:00 PM Central Time** to keep costs
low, with a native auto-shutdown safety net.

> **Budget guardrail:** this environment is designed to stay well within a
> **$150/month** Azure credit. Current estimated run cost is **~$21/month**.

---

## Architecture

```
                         Client
                           │  DNS lookup
                           ▼
          moseley-dev-web.trafficmanager.net      (Traffic Manager — round robin)
                           │  returns one region's public IP
             ┌─────────────┴─────────────┐
             ▼                           ▼
   ┌───────────────────┐        ┌───────────────────┐
   │     CENTRAL US    │        │      EAST US      │
   │ RG: Moseley_      │        │ RG: Moseley_      │
   │     Development   │        │     Development_  │
   │                   │        │     East          │
   │ VNet 10.10.10.0/24│        │ VNet 10.20.20.0/24│
   │  └ subnet         │        │  └ subnet         │
   │     └ NSG (80/443 │        │     └ NSG (80/443 │
   │        /22)       │        │        /22)       │
   │ Public IP (static)│        │ Public IP (static)│
   │  └ NIC └ VM       │        │  └ NIC └ VM       │
   │     (Debian 12,   │        │     (Debian 12,   │
   │      B1s, nginx)  │        │      B1s, nginx)  │
   │                   │        │                   │
   │ Automation:       │        │ Automation:       │
   │  8AM up / 10PM down│       │  8AM up / 10PM down│
   │  + 10:30PM safety │        │  + 10:30PM safety │
   └───────────────────┘        └───────────────────┘
```

Traffic Manager is **DNS-based**: it does not proxy traffic. It answers each DNS
lookup with the public IP of a healthy region (round-robin via equal endpoint
weights), and the client then connects **directly** to that VM. This is why each
VM has its own public IP.

---

## Repository layout

```
.
├── versions.tf                 # Terraform + azurerm provider version pins
├── variables.tf                # Shared input variables (defaults live here)
├── main.tf                     # Calls the webserver module twice (central + east)
├── trafficmanager.tf           # Global round-robin load balancing
├── outputs.tf                  # URLs, public IPs, SSH commands
├── cloud-init.yaml             # First-boot provisioning (installs nginx)
├── terraform.tfvars.example    # Copy to terraform.tfvars and customise
└── modules/
    └── webserver/              # One reusable "region stack"
        ├── main.tf             # RG, network, NSG, VM, power schedules, safety net
        ├── variables.tf        # Module inputs
        └── outputs.tf          # Module outputs
```

The **`webserver` module** encapsulates one complete regional stack (resource
group, `/24` network, NSG, public IP, Debian VM, and the Automation-based power
schedule). `main.tf` instantiates it twice, so the two regions stay identical —
change the module once and both regions update.

---

## What gets created

**Global (4 resources):** a resource group, a Traffic Manager profile
(weighted/round-robin, HTTP:80 health probe), and one endpoint per region.

**Per region (16 resources each):** resource group, virtual network (`/24`),
subnet, network security group + association, static public IP, network
interface, Debian 12 VM (nginx via cloud-init), Automation account with a managed
identity, a `Virtual Machine Contributor` role assignment, a start/stop runbook,
two schedules (start + stop), two job-schedule links, and a native auto-shutdown
safety net.

**Total: 36 resources.**

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.5
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) (`az`)
- An Azure subscription
- An SSH key pair. Create one if needed:
  ```bash
  ssh-keygen -t ed25519 -f ~/.ssh/id_rsa
  ```

---

## Usage

```bash
# 1. Authenticate to Azure
az login

# 2. (Optional) Copy and edit variable overrides
cp terraform.tfvars.example terraform.tfvars
#    At minimum, set allowed_ssh_source to your public IP.

# 3. Initialise providers and modules
terraform init

# 4. Review the plan
terraform plan

# 5. Apply
terraform apply
```

After apply, Terraform prints the Traffic Manager URL and each region's public IP,
web URL, and SSH command via the outputs.

### Tear down

```bash
terraform destroy
```

---

## Configuration reference

All variables have working defaults in [`variables.tf`](variables.tf); override any
of them in `terraform.tfvars`.

| Variable | Default | Purpose |
|---|---|---|
| `vm_size` | `Standard_B1s` | VM size (small, free-tier-eligible for one VM) |
| `admin_username` | `azureadmin` | Admin user created on both VMs |
| `ssh_public_key_path` | `~/.ssh/id_rsa.pub` | Public key placed on the VMs |
| `allowed_ssh_source` | `*` | CIDR allowed to reach SSH — **restrict this** |
| `startup_time` | `08:00` | Daily power-up (Central Time) |
| `shutdown_time` | `22:00` | Daily deallocate (Central Time) |
| `safety_shutdown_time` | `2230` | Native auto-shutdown safety net (HHmm) |
| `schedule_utc_offset` | `-05:00` | Anchors the first scheduled run |
| `traffic_manager_dns_name` | `moseley-dev-web` | Global-unique Traffic Manager label |
| `tags` | dev/Moseley/terraform | Tags applied to all resources |

---

## Cost

| Item | Approx. monthly |
|---|---|
| 2× `B1s` VM (deallocated ~10 hrs/night) | ~$9 |
| 2× OS disk (30 GB Standard HDD) | ~$3 |
| 2× static public IP (Standard) | ~$7 |
| Traffic Manager (2 endpoints + DNS queries) | ~$1–2 |
| Automation, VNet, NSG | $0 |
| **Total** | **~$21/month** |

Deallocating the VMs nightly (not just shutting them down inside the OS) is what
stops compute billing. On an Azure free account, one `B1s` is free for 12 months,
lowering the total further.

---

## Operational notes

- **Round-robin is per DNS lookup, not per HTTP request.** Clients cache the DNS
  answer for the profile TTL (30s), so a single client sticks to one region until
  it re-resolves. Distribution evens out across many clients/lookups.
- **Overnight both regions are down** (10 PM–8 AM CT), so the site is dark during
  that window. To stay reachable 24/7, stagger the two regions' schedules so at
  least one is always up.
- **Health probes** (HTTP:80) automatically remove a region from rotation when its
  VM is deallocated, so users are never sent to a down endpoint.
- **DST** is handled automatically by the `America/Chicago` timezone on the
  Automation schedules; `schedule_utc_offset` only anchors the very first run.

---

## Security

- **Restrict SSH.** `allowed_ssh_source` defaults to `*` (open to the internet).
  Set it to your public IP (`curl -s ifconfig.me` → `x.x.x.x/32`) before applying.
- VMs use **SSH key authentication only** (no passwords).
- The Automation identity is scoped to **`Virtual Machine Contributor` on its own
  resource group** — least privilege for start/stop.
- **Never commit `terraform.tfvars` or state files** — both are git-ignored, as
  state can contain secrets. Use a remote backend for team use.
