# Fortress VNet — How It All Works
When you run `terraform apply`, it creates this on Azure:

```
Internet
   ↓
Load Balancer  ←  Bastion Host (for SSH)
   ↓
App VMs (2x Ubuntu + Nginx webpage)
   ↓
PostgreSQL Database (private, no internet access)
```

Everything lives inside a Virtual Network (VNet) — a private isolated network on Azure.

---

## Folder Structure

```
backend-init/        → Step 1: creates storage for Terraform state
networking/          → Step 2: the actual infrastructure
  main.tf            → calls the 3 modules below
  variables.tf       → all the config options
  terraform.tfvars   → your actual values (gitignored)
  outputs.tf         → prints IPs after deploy
  modules/
    networking/      → VNet, subnets, firewalls, NAT
    compute/         → Load Balancer, VMs, Bastion, webpage
    database/        → PostgreSQL server
.github/workflows/   → automatic deploy on GitHub push
```

---

## backend-init/

Before deploying, Terraform needs somewhere to save its state file. This folder creates an Azure Storage Account (like an S3 bucket) for that.

Run this once before anything else.

---

## networking/main.tf

The entry point. It calls 3 modules and passes data between them:

```
main.tf
  calls → module "networking" → creates VNet and subnets
  calls → module "compute"   → gets subnet IDs from networking
  calls → module "database"  → gets VNet ID from networking
```

Without this file nothing gets deployed.

---

## networking/variables.tf + terraform.tfvars

`variables.tf` declares what settings exist.
`terraform.tfvars` is where you put the actual values.

Key settings:
- `location` — which Azure region (default: Central India)
- `project_name` — prefix for all resource names (default: Fortress-VNet)
- `db_password` — your database password (required, no default)
- `vnet_address_space` — IP range for the network (default: 10.0.0.0/16)

---

## Module: networking

Creates the network foundation.

**vpc.tf** — makes the VNet and 6 subnets:
- 2 public subnets (for Load Balancer and Bastion)
- 2 app subnets (for VMs — private, no direct internet)
- 2 DB subnets (for database — fully isolated)

**security.tf** — firewall rules (NSGs) per tier:
- Public: allow HTTP/HTTPS from internet
- App: only allow traffic from inside the network
- DB: only allow PostgreSQL port 5432 from app VMs

**routes.tf** — NAT Gateway so app VMs can reach the internet outbound (for updates etc.) without being reachable inbound.

**variables.tf** — what this module needs as input.
**outputs.tf** — exports subnet IDs and VNet ID for other modules to use.

---

## Module: compute

Creates all the servers.

**compute.tf** has 3 parts:
1. **Load Balancer** — receives all web traffic on port 80 and splits it across VMs. Health checks VMs every 5 seconds.
2. **VMSS (Virtual Machine Scale Set)** — 2 Ubuntu VMs that run the webpage. Auto-registered with the Load Balancer.
3. **Bastion Host** — a small cheap VM with a public IP. The only way to SSH into private VMs.

**init.sh** — runs automatically on every VM when it first boots. Installs Nginx and writes the Fortress VNet dashboard webpage to the VM. This is how the webpage gets deployed without any manual steps.

**variables.tf** — inputs: subnet IDs, location, VM sizes etc.
**outputs.tf** — exports: Load Balancer public IP, Bastion public IP.

---

## Module: database

Creates the PostgreSQL database — fully private.

**database.tf** does 5 things:
1. Creates a dedicated subnet just for PostgreSQL (it needs its own)
2. Creates a Private DNS Zone — so the DB hostname only resolves inside your VNet
3. Links the DNS Zone to the VNet
4. Creates the PostgreSQL Flexible Server v15 (1 vCore, 2GB RAM, 32GB storage, 7-day backups)
5. Creates the actual database inside the server

Nobody outside your VNet can reach this database. No public IP, no public DNS record.

**variables.tf** — inputs: subnet IDs, VNet ID, DB password.
**outputs.tf** — exports: the DB hostname (FQDN).

---

## .github/workflows/deploy.yml

Automates deployment via GitHub Actions.

- **On Pull Request** → runs `terraform plan` and posts the result as a PR comment
- **On merge to main** → runs `terraform apply` automatically

Needs 5 GitHub Secrets to work: 4 Azure credentials + your DB password.

---

## Why variables.tf and outputs.tf in every module?

Modules are isolated — they can't read from or write to each other directly.

- **variables.tf** = the inputs a module accepts (like function parameters)
- **outputs.tf** = the values a module exports (like a function's return value)
- **main.tf** = connects them by passing outputs of one module as inputs to another

---

## Azure Terms — Plain English

| Term | What it means |
|------|--------------|
| VNet | Your private network on Azure. Like your home Wi-Fi. |
| Subnet | A section of the VNet. Each tier gets its own. |
| NSG | A firewall. Controls what traffic is allowed. |
| Load Balancer | Splits web traffic evenly across your VMs. |
| VMSS | A group of VMs running the same config. |
| NAT Gateway | Lets private VMs access the internet outbound only. |
| Bastion Host | A jump server. SSH here first, then hop to private VMs. |
| Private DNS Zone | Internal-only DNS. DB hostname only works inside the VNet. |
| Remote Backend | Terraform state stored in Azure instead of locally. |
