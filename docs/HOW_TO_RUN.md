# How to Run — Fortress VNet

## Before You Start

Make sure you have these installed:

```bash
terraform --version   # >= 1.5.0 required
az --version          # Azure CLI
kubectl version       # Kubernetes CLI
docker --version      # Docker (for local image builds)
ls ~/.ssh/id_rsa.pub  # SSH key
```

No SSH key? Run this:
```bash
ssh-keygen -t rsa -b 4096
```
Just hit Enter for all prompts.

---

## Step 1 — Login to Azure

```bash
az login
```

A browser window opens. Sign in, then return to the terminal. Confirm the right subscription is active:

```bash
az account show --query "{name:name, id:id}" -o table
# If wrong, switch:
az account set --subscription "<your-subscription-id>"
```

---

## Step 2 — One-Time Resource Group & Permissions Setup

> **Skip this step** if `Fortress-RG` already exists in your subscription.

The project uses a **static resource group** (`Fortress-RG`) that persists across every deployment run. This avoids the `PublicIPCountLimitReached` quota error caused by randomised resource group names creating new IPs on every run.

```bash
# Create the stable resource group
az group create --name "Fortress-RG" --location "centralindia"

# Grant your Service Principal Owner rights on it (one-time)
az role assignment create \
    --assignee "<your-sp-client-id>" \
    --role "Owner" \
    --scope "/subscriptions/<your-subscription-id>/resourceGroups/Fortress-RG"
```

---

## Step 3 — Deploy the Infrastructure

```bash
cd networking
terraform init
terraform plan -out=tfplan
terraform apply -auto-approve tfplan
```

Terraform will:
1. Reuse the existing `Fortress-RG` resource group (creates it if absent).
2. Create the VNet, AKS cluster, Application Gateway, Bastion, ACR, Redis, and PostgreSQL inside it.
3. Build and push the dashboard image to ACR automatically.
4. Deploy the application to AKS via Kubernetes manifests.

⏱ **Expected time: 10–15 minutes** (AKS + Application Gateway provisioning).

> **Note:** Because the resource group is static, `terraform plan` will report **no changes** on subsequent runs if the infrastructure is already up — this is expected and correct.

---

## Step 4 — Read the Outputs

When `apply` completes you'll see:

```
aks_cluster_name      = "Fortress-VNet-aks"
app_gateway_public_ip = "<public-ip>"
acr_login_server      = "fortressvnetacr<suffix>.azurecr.io"
resource_group_name   = "Fortress-RG"
```

> It may take **5 additional minutes** for the Application Gateway backend to become healthy.

---

## Step 5 — Access the Dashboard

```
http://<app_gateway_public_ip>
```

Verify pods are running:

```bash
az aks get-credentials --resource-group Fortress-RG --name Fortress-VNet-aks --overwrite-existing
kubectl get pods -n default
kubectl get ingress -n default
```

---

## Step 6 — Authenticate to ACR (for manual pushes)

```bash
az acr login --name <acr_name>
# Example:
az acr login --name $(terraform -chdir=networking output -raw acr_login_server | cut -d. -f1)
```

---

## Step 7 — Connect to the Database

From inside the VNet (via Bastion or an app pod):

```bash
psql -h <db_server_fqdn> -U adminuser -d fortressdb
```

---

## Step 8 — Verify Real-Time WebSocket Updates

Once the dashboard is live, verify the real-time pod monitoring:

1. Open `http://<app_gateway_public_ip>` → go to the **Cluster Nodes** tab.
2. Watch the **Pod Counter** card on the Overview tab.
3. Trigger autoscaling with ApacheBench:

```bash
ab -n 20000 -c 200 http://<APP_GATEWAY_IP>/
```

**Expected behaviour:**

| Phase | Pod Counter | Tag | Terminal Log |
|-------|-------------|-----|--------------|
| Before load | 2 | `STABLE` | — |
| During load | 2 → 4 → 8+ | `SCALING UP` (pulsing) | `HPA Triggered: Scaling from 2 → 8 pods` |
| After load | Scales back down | `SCALING DOWN` | `Workload decreased: Scaling down to 2 pods` |

The dashboard updates every **2 seconds** via WebSocket — no page refresh needed.

---

## Windows Users 🪟

This project uses bash-style commands which do not run natively in CMD or PowerShell.

**Recommended options:**
1. **WSL (Windows Subsystem for Linux)** — Install Ubuntu via WSL. Most reliable.
2. **Git Bash** — Works for `terraform` and `az` commands. `Makefile` targets may require `make` for Windows.
3. **PowerShell** — Run Terraform manually; replace `$(...)` with `$()` PowerShell syntax.

---

## Teardown — Delete Everything

```bash
cd networking
terraform destroy -auto-approve
```

> This **does not** delete the `Fortress-RG` resource group itself (since it predates Terraform state). To fully clean up:
> ```bash
> az group delete --name Fortress-RG --yes --no-wait
> ```

---

## Common Issues

| Problem | Fix |
|---------|-----|
| `No subscription found` | Run `az login` and re-set subscription with `az account set` |
| `ssh-key not found` | Run `ssh-keygen -t rsa -b 4096` |
| `PublicIPCountLimitReached` | Old resource groups are consuming your 3 IP quota. Run `az group delete --name <old-rg> --yes` to clean up stale deployments |
| Gateway error 502/404 | Normal during initial provisioning; wait up to 10 minutes |
| `kubectl` not connecting | Run `az aks get-credentials --resource-group Fortress-RG --name Fortress-VNet-aks --overwrite-existing` |
| `Backend config changed` | Run `rm -rf .terraform` then `terraform init` again |
| `Invalid format` in GitHub Actions | Ensure `terraform_wrapper: false` is set in the Setup Terraform step |
| `plan_status` always empty | Use `set +e` / `EXIT_CODE=$?` / `set -e` pattern — not `\|\| export EXIT_CODE=$?` |
| `409 Conflict` on role assignments | Transient AAD replication delay; re-run the workflow or wait 60 seconds |

---

## Setting Up CI/CD (GitHub Actions)

The workflow at `.github/workflows/deploy.yml` runs automatically on every push to `main`.

### One-Time Setup

**1. Create an Azure Service Principal:**
```bash
az ad sp create-for-rbac \
  --name "fortress-vnet-github" \
  --role "Contributor" \
  --scopes /subscriptions/<your-subscription-id> \
  --sdk-auth
```

Grant it `Owner` on `Fortress-RG` so it can manage role assignments:
```bash
az role assignment create \
  --assignee "<client-id-from-above>" \
  --role "Owner" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/Fortress-RG"
```

**2. Add these secrets to GitHub** → Settings → Secrets and variables → Actions:

| Secret | Value |
|--------|-------|
| `AZURE_CREDENTIALS` | Full JSON output from `create-for-rbac --sdk-auth` |
| `AZURE_CLIENT_ID` | `clientId` from the JSON |
| `AZURE_CLIENT_SECRET` | `clientSecret` from the JSON |
| `AZURE_SUBSCRIPTION_ID` | Your subscription ID |
| `AZURE_TENANT_ID` | `tenantId` from the JSON |

**3. Add these repository variables** → Settings → Secrets and variables → Variables:

| Variable | Value |
|----------|-------|
| `TF_STATE_RG` | Resource group holding the Terraform state storage account |
| `TF_STATE_ACCOUNT` | Name of the Azure Storage Account for Terraform state |

**4. How the workflow works:**

```
push to main
  → terraform init       (connects to Azure backend)
  → terraform plan       (exit 0 = no changes, exit 2 = changes)
  → terraform apply      (runs ONLY if exit code was 2)
  → docker build & push  (always runs with github.sha tag)
  → kubectl rollout       (deploys new image to AKS)
```

**5. Push to `main`** — the workflow runs automatically on every merge.
