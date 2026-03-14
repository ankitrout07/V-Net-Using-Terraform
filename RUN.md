# How to Run the Fortress-VNet Architecture

This guide provides step-by-step instructions for deploying a 3-Tier Virtual Network (VNet) architecture on Azure, using Azure Storage as the remote backend for Terraform state.

## Prerequisites Ensure

Before starting, ensure you have the following installed and configured on your machine:
1. **Terraform**: [Install Terraform](https://developer.hashicorp.com/terraform/downloads) (>= 1.0)
2. **Azure CLI**: [Install Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli). Run `az login` to authenticate.
3. **SSH Key Pair**: Ensure you have an RSA SSH key located at `~/.ssh/id_rsa.pub`. Terraform uses this to configure VM access.

---

## Step 1: Initialize the Azure Remote Backend
We must first deploy a Storage Account in Azure to hold our Terraform state files securely.

1. Navigate to the `backend-init` directory:
   ```bash
   cd backend-init
   ```
2. Initialize Terraform to download the Azure provider:
   ```bash
   terraform init
   ```
3. Preview the resources to be created:
   ```bash
   terraform plan
   ```
4. Deploy the backend components:
   ```bash
   terraform apply
   ```
   *Type `yes` when prompted.*

5. **CRITICAL:** Once the deployment is complete, take note of the `storage_account_name` value output to your console. You will need this for Step 2.

---

## Step 2: Deploy the Azure VNet Infrastructure
With the remote backend established, we can deploy the actual Azure infrastructure.

1. Navigate to the `networking` directory:
   ```bash
   cd ../networking
   ```
2. Open `networking/provider.tf` in your editor. Replace `<YOUR_AZURE_STORAGE_ACCOUNT_NAME>` with the exact storage account name output from Step 1.
3. Open `networking/terraform.tfvars`. Ensure the variables are configured to your liking. (Do not commit sensitive passwords to source control).
4. Remove any `.terraform` or `.terraform.lock.hcl` files from previous runs to ensure a clean provider slate:
   ```bash
   rm -rf .terraform .terraform.lock.hcl
   ```
5. Initialize Terraform. This step will configure the remote connection to your Azure Storage Account:
   ```bash
   terraform init
   ```
6. Preview the Azure infrastructure changes:
   ```bash
   terraform plan
   ```
7. Deploy the Azure infrastructure:
   ```bash
   terraform apply
   ```
   *Type `yes` when prompted.*

---

## Step 3: Accessing the Infrastructure

After a successful deployment, Terraform will output several important values:
- **`lb_public_ip`**: The public IP for accessing the web tier load balancer (Tier 1). You can paste this into your browser.
- **`bastion_public_ip`**: The IP address of the Bastion host used for SSH access to the private App Tier instances.
- **`db_server_fqdn`**: The internal endpoint for the isolated PostgreSQL database.

### Connecting to the Bastion Host
To SSH into your private instances, you must first connect to the Bastion host in the public subnet:

```bash
ssh <admin_username>@<bastion_public_ip>
```
*(Note: Replace `<admin_username>` with your configured admin username - default is `adminuser`).*

---

## Teardown (Clean Up)
When you are finished experimenting, it is important to destroy the infrastructure to avoid incurring unnecessary cloud costs.

1. **Destroy the Infrastructure:**
   ```bash
   cd networking
   terraform destroy
   ```
   *Type `yes` when prompted.*

2. **Destroy the Azure Backend:**
   ```bash
   cd ../backend-init
   terraform destroy
   ```
   *Type `yes` when prompted. Warning: This deletes the Terraform state file completely.*
