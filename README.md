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
3. **Assign role** — Subscriptions → your subscription → Access control (IAM) → Add role assignment → Role: `Contributor` → Members: select `wordpress-poc-pipeline` → Assign

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
