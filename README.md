# VNet-Using-Terraform (Azure)

Production-grade 3-Tier VNet architecture on Azure using Terraform. 

## Architecture
This project implements a secure, highly-available 3-tier architecture:

1.  **Tier 1: Web (Public)**
    *   Standard Public Load Balancer
    *   Bastion Host (VM with Public IP) for SSH access
2.  **Tier 2: App (Private)**
    *   Virtual Machine Scale Set (VMSS) with Ubuntu Server 22.04 LTS
    *   Instances are isolated from direct inbound internet access
    *   Egress traffic via NAT Gateway
3.  **Tier 3: DB (Isolated)**
    *   Azure Database for PostgreSQL Flexible Server
    *   Delegated subnets with no public access
    *   Private DNS Zone integration

### Security
- **Network Security Groups (NSGs)**: Stateful firewalls restricting traffic between tiers.
- **NAT Gateway**: Controlled egress for private instances.
- **Remote State**: AzureRM backend (configurable in `networking/provider.tf`).

## Prerequisites
- Terraform >= 1.0
- Azure CLI configured and authenticated (`az login`)
- Existing local SSH Key (`~/.ssh/id_rsa.pub`) - required for VM authentication.

## Setup

### Step 1: Bootstrap Azure Backend
This creates the Azure Resource Group, Storage Account, and Container to hold the Terraform state for the infrastructure.

1. Navigate to the `backend-init/` directory:
   ```bash
   cd backend-init
   ```
2. Initialize and deploy the backend:
   ```bash
   terraform init
   terraform apply
   ```
3. Take note of the `storage_account_name` value output by Terraform. You will need to plug this into the provider config in Step 2.

### Step 2: Deploy Fortress VNet
This deploys the actual Azure infrastructure (VNet, Subnets, VMSS, PostgreSQL) using the remote state bucket created in Step 1.

1. Navigate to the `networking/` directory:
   ```bash
   cd ../networking
   ```
2. Open `provider.tf` and replace `<YOUR_AZURE_STORAGE_ACCOUNT_NAME>` with the output from Step 1.
3. Open `terraform.tfvars` to customize locations or resource names if desired.
4. Run Terraform to deploy the infrastructure:
   ```bash
   terraform init
   terraform apply
   ```
