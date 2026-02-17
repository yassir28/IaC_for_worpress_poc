# WordPress POC - HA on Azure

## Prerequisites

### 1. Terraform State Backend

Create these before `terraform init`:

1. **Resource Group** — Search "Resource groups" → Create → Name: `tfstate-rg`, Region: West Europe
2. **Storage Account** — Search "Storage accounts" → Create → RG: `tfstate-rg`, Name: `wordpresstfstate`, Redundancy: LRS
3. **Blob Container** — Open storage account → Containers → + Container → Name: `tfstate`, Private access

> **CLI alternative:**
> ```bash
> az group create -n tfstate-rg -l westeurope
> az storage account create -n wordpresstfstate -g tfstate-rg -l westeurope --sku Standard_LRS
> az storage container create -n tfstate --account-name wordpresstfstate
> ```

### 2. Service Principal (for Azure DevOps Pipeline)

1. **Azure Portal** → Search "App registrations" → New registration → Name: `wordpress-poc-pipeline` → Register
2. **Create secret** — Open the app → Certificates & secrets → New client secret → Copy the **Value** (shown only once)
3. **Assign role** — Go to Subscriptions → your subscription → Access control (IAM) → Add role assignment → Role: `Contributor` → Members: select `wordpress-poc-pipeline` → Assign

> **CLI alternative:**
> ```bash
> az ad sp create-for-rbac --name "wordpress-poc-pipeline" --role Contributor \
>   --scopes /subscriptions/<YOUR_SUBSCRIPTION_ID>
> ```

Note these values:

| Pipeline Variable | Where to find it |
|---|---|
| `ARM_CLIENT_ID` | App registrations → `wordpress-poc-pipeline` → Application (client) ID |
| `ARM_CLIENT_SECRET` | The secret value from step 2 |
| `ARM_TENANT_ID` | App registrations → `wordpress-poc-pipeline` → Directory (tenant) ID |
| `ARM_SUBSCRIPTION_ID` | Subscriptions → your subscription → Subscription ID |

### 3. Azure DevOps Pipeline Variables

Pipelines → your pipeline → Edit → Variables → add the 4 variables above. Mark `ARM_CLIENT_SECRET` as secret.

### 4. SSH Key

Generate if not present (Cloud Shell or local):

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
```

### subscription show:
az account show --query id -o tsv
ca451ff4-00e8-4f56-a468-24239e24d62e
