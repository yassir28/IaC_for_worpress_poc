# WordPress POC - HA on Azure

## Setup

### 1. Terraform State Backend

Storage for Terraform state. Create in Azure Portal before first run.

1. **Resource Group** — "Resource groups" → Create → Name: `tfstate-rg`, Region: West Europe
2. **Storage Account** — "Storage accounts" → Create → RG: `tfstate-rg`, Name: `wordpresstfstate`, Redundancy: LRS
3. **Blob Container** — Open storage account → Containers → + Container → Name: `tfstate`, Private access

> **CLI alternative:**
> ```bash
> az group create -n tfstate-rg -l westeurope
> az storage account create -n wordpresstfstate -g tfstate-rg -l westeurope --sku Standard_LRS
> az storage container create -n tfstate --account-name wordpresstfstate
> ```

### 2. Service Principal

A "robot account" that gives the pipeline permission to create Azure resources. Terraform authenticates with it via 4 env vars — no special integration, just credentials passed through.

1. **Register** — Azure Portal → "App registrations" → New registration → Name: `wordpress-poc-pipeline` → Register
2. **Create secret** — Open the app → Certificates & secrets → New client secret → Copy the **Value** (shown only once)
3. **Assign role** — Subscriptions → your subscription → Access control (IAM) → Add role assignment:
   - Role: `Contributor` → Next
   - Members: "User, group, or service principal" → Select members → search `wordpress-poc-pipeline` → select → Review + assign

> **CLI alternative:**
> ```bash
> az ad sp create-for-rbac --name "wordpress-poc-pipeline" --role Contributor \
>   --scopes /subscriptions/$(az account show --query id -o tsv)
> ```

### 3. SSH Key

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
```

---

## CI/CD — Pick One

### Option A: Azure DevOps (`azure-pipelines.yml`)

#### Extra setup:
1. **Install Terraform extension** — Organization Settings → Extensions → Browse marketplace → search "Terraform" → install **"Terraform" by Microsoft DevLabs**
2. **Link repo** — Azure DevOps → Repos → get the clone URL, then locally:
   ```bash
   git remote set-url origin https://<USER>:<PAT>@dev.azure.com/<ORG>/<PROJECT>/_git/<REPO>
   git push -u origin main
   ```
3. **Create pipeline** — Pipelines → New pipeline → Azure Repos Git → Existing YAML → select `/azure-pipelines.yml`
4. **Add variables** — Pipelines → your pipeline → Edit → Variables:

   | Variable | Where to find it |
   |---|---|
   | `ARM_CLIENT_ID` | App registrations → Application (client) ID |
   | `ARM_CLIENT_SECRET` | The secret value (mark **secret**) |
   | `ARM_TENANT_ID` | App registrations → Directory (tenant) ID |
   | `ARM_SUBSCRIPTION_ID` | Subscriptions → Subscription ID |

5. **Save and Run**

> **Note:** New Azure DevOps orgs have no free hosted agent minutes. You must either pay ($40/mo) or set up a [self-hosted agent](https://learn.microsoft.com/en-us/azure/devops/pipelines/agents/linux-agent).

### Option B: GitHub Actions (`.github/workflows/deploy.yml`)

Free tier includes 2,000 minutes/month on hosted runners.

1. **Push repo to GitHub**
   ```bash
   git remote set-url origin https://github.com/<USER>/wordpress-poc.git
   git push -u origin main
   ```
2. **Add secrets** — GitHub repo → Settings → Secrets and variables → Actions → New repository secret:

   | Secret | Where to find it |
   |---|---|
   | `ARM_CLIENT_ID` | App registrations → Application (client) ID |
   | `ARM_CLIENT_SECRET` | The secret value from step 2 |
   | `ARM_TENANT_ID` | App registrations → Directory (tenant) ID |
   | `ARM_SUBSCRIPTION_ID` | Subscriptions → Subscription ID |

3. Pipeline triggers automatically on push to `main`, or manually via Actions → Run workflow

---

## How It All Connects

```
git push → triggers pipeline (Azure DevOps or GitHub Actions) →
  pipeline sets ARM_* env vars →
    Terraform authenticates as service principal →
      creates resources in your subscription →
        health check verifies WordPress is up
```

---

## SSH Access

Add these entries to `~/.ssh/config` on your local machine (update IPs if VMs are recreated):

```
Host wordpress-jump
    HostName <jumphost-public-ip>
    User azureuser
    IdentityFile ~/.ssh/id_rsa_azure
    ForwardAgent yes

Host wordpress-wp-1
    HostName 10.0.1.5
    User azureuser
    IdentityFile ~/.ssh/id_rsa_azure
    ProxyJump wordpress-jump

Host wordpress-wp-2
    HostName 10.0.1.4
    User azureuser
    IdentityFile ~/.ssh/id_rsa_azure
    ProxyJump wordpress-jump
```

Then connect with:
```bash
ssh wordpress-jump      # jumphost directly
ssh wordpress-wp-1      # wp-1 via jumphost (no manual proxy needed)
ssh wordpress-wp-2      # wp-2 via jumphost
```

> **Note:** Private IPs (10.0.1.x) are dynamic — update the config if VMs are recreated.
> Find current IPs in Portal → `wordpress-poc-rg` → VM → Networking.

---

## WordPress Setup

After a fresh deployment, visit `http://<lb-public-ip>` from a browser **outside Azure** to complete the WordPress installation wizard.

> **Azure LB hairpin limitation:** Curling the LB public IP from within the same VNet (e.g. from the jumphost) will hang — this is expected Azure behavior. Always test from an external machine.

To verify WordPress is serving from within the VNet, curl the VM directly:
```bash
# From jumphost
curl -s -o /dev/null -w "%{http_code}" http://10.0.1.4   # should return 302
```

---

## Load Balancing — POC vs Production

This POC uses an **Azure Standard Load Balancer (L4)**, not an Application Gateway (L7).

```
POC:        Internet → Standard LB (L4, TCP:80) → WP-1 / WP-2

Production: Internet → App Gateway (L7, WAF, HTTPS) → WP-1 / WP-2
```

**Why L7 is more secure than L4 (OSI layers):**
L4 (Transport layer) only sees IP addresses and ports — it forwards raw TCP packets without inspecting content. L7 (Application layer) understands HTTP: it can read headers, URLs, cookies, and request bodies. This means an L7 gateway can block malicious payloads (SQL injection, XSS, bad User-Agent strings) before they ever reach your app. An L4 balancer passes everything through blindly.

**What Azure Application Gateway adds over a Standard LB:**

| Feature | Standard LB (this POC) | Application Gateway |
|---|---|---|
| Layer | L4 (TCP/UDP) | L7 (HTTP/HTTPS) |
| SSL termination | No (HTTP only) | Yes (HTTPS at gateway) |
| WAF | No | Yes (OWASP top-10 rules) |
| Cookie-based session affinity | No | Yes (sticky sessions) |
| Path-based routing | No | Yes (`/api/*` → backend A) |
| Cost | ~$0 basic | ~$120+/mo minimum |

For a POC demonstrating HA, the Standard LB is sufficient. Application Gateway would be the next step before production.

---

## Takeaways

**Azure SKU availability is regional and subscription-dependent.** `Standard_B1s` and `Standard_B2s` had no capacity in West Europe, and `Standard_Bsv2` family had zero approved quota. Always verify with `az vm list-skus` and `az vm list-usage` before picking a size. `Standard_D2s_v3` (DSv3 family) was the first size with both quota and available capacity.

**`terraform.tfvars` overrides `variables.tf` defaults.** Changing a default in `variables.tf` has no effect if the same variable is set in `terraform.tfvars`. Both files must be updated together.

**Azure MySQL Flexible Server auto-assigns an availability zone.** If `zone` is not specified in Terraform, Azure picks one (e.g. `"1"`). On subsequent plans Terraform detects drift and tries to unset it, which Azure rejects. Pin `zone` explicitly to match what Azure assigned.

**Partial apply leaves state inconsistent.** When a `terraform apply` partially succeeds (e.g. MySQL created, VMs failed), re-running apply only attempts the remaining resources. No manual cleanup needed — Terraform reconciles from state.

**Health check timing matters.** VMs take 1–3 minutes after creation for cloud-init to finish installing WordPress. A health check run immediately after `apply` will see HTTP 000 (not listening) or HTTP 500 (still initializing). Add a longer initial wait or increase retry attempts for a reliable check.
