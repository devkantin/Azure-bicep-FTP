# Azure EFT Infrastructure — Globalscape Active/Passive HA

Infrastructure-as-Code for deploying **Globalscape EFT (Enhanced File Transfer)** in an **Active/Passive high-availability** configuration on Azure, using Windows Server Failover Clustering (WSFC).

---

## Architecture

```
Internet / Clients (FTP, SFTP, FTPS, HTTPS)
              │
              ▼
  ┌─────────────────────────┐
  │  Azure Internal Load    │  ← Virtual IP: 10.x.1.100
  │  Balancer (Standard)    │    Floating IP enabled (WSFC)
  └────────────┬────────────┘
               │
       ┌───────┴────────┐
       ▼                ▼
  ┌─────────┐      ┌─────────┐
  │EFT-VM-01│◄────►│EFT-VM-02│  ← WSFC Heartbeat
  │ ACTIVE  │      │ PASSIVE │
  │10.x.1.10│      │10.x.1.11│
  └────┬────┘      └────┬────┘
       └───────┬─────────┘
               ▼
  ┌────────────────────────┐
  │  Azure Shared Disk     │  ← 256 GB Premium SSD
  │  EFT sites, config,    │     maxShares = 2
  │  SSL keys, logs        │
  └────────────────────────┘
               │
               ▼
  ┌────────────────────────┐
  │  Storage Account       │  ← WSFC Cloud Witness (quorum)
  └────────────────────────┘
```

**Failover flow:** When EFT-VM-01 becomes unhealthy, the ILB health probe fails, WSFC detects the loss of heartbeat, promotes EFT-VM-02 to active, and the cluster IP moves — clients reconnect to the same VIP without reconfiguration.

---

## Repository Structure

```
├── bicep/
│   ├── main.bicep                  # Orchestrator — wires all modules
│   ├── modules/
│   │   ├── nsg.bicep               # Network Security Group + rules
│   │   ├── network.bicep           # VNet + subnet
│   │   ├── availabilityset.bicep   # Availability Set (2 FD, 5 UD)
│   │   ├── shareddisk.bicep        # Shared Premium SSD (maxShares=2)
│   │   ├── loadbalancer.bicep      # Internal Standard LB + rules
│   │   ├── storageaccount.bicep    # Storage account for quorum witness
│   │   └── vm.bicep                # Windows Server 2022 VM (reusable)
│   └── parameters/
│       ├── dev.bicepparam          # Dev environment values
│       └── prod.bicepparam         # Prod environment values
├── .github/
│   └── workflows/
│       ├── validate.yml            # PR: lint → security scan → what-if
│       └── deploy.yml              # Push/manual: deploy → Pester tests
├── tests/
│   └── infrastructure.tests.ps1   # Pester 5 post-deployment validation
└── scripts/
    └── manual-deploy.sh            # One-shot manual deploy script
```

---

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| Azure CLI | ≥ 2.55 | [docs.microsoft.com](https://learn.microsoft.com/cli/azure/install-azure-cli) |
| Bicep CLI | ≥ 0.24 | `az bicep install` |
| PowerShell | ≥ 7.3 | [github.com/PowerShell](https://github.com/PowerShell/PowerShell/releases) |
| Pester | ≥ 5.5 | `Install-Module Pester -Force` |
| Az PowerShell | ≥ 11.0 | `Install-Module Az -Force` |

Azure permissions required: **Contributor** on the subscription (to create resource groups and all resources).

---

## Manual Deployment (First Time)

Run this to deploy and verify the infrastructure before the CI/CD pipeline takes over.

```bash
# 1. Login to Azure
az login
az account set --subscription "<your-subscription-id>"

# 2. Deploy to dev
bash scripts/manual-deploy.sh dev

# 3. Deploy to prod (when ready)
bash scripts/manual-deploy.sh prod
```

The script will:
- Create the resource group
- Prompt for the VM admin password
- Deploy all Bicep modules
- Print a summary with IPs and next steps

> **Estimated deploy time:** 15–20 minutes (VMs are the bottleneck)

---

## What Gets Deployed

| Resource | Name pattern | Notes |
|---|---|---|
| Resource Group | `rg-eft-{env}` | Tagged with `project`, `environment`, `managedBy` |
| Virtual Network | `vnet-eft-{env}` | `10.0.0.0/16` (dev) / `10.1.0.0/16` (prod) |
| Subnet | `snet-eft` | `/24` within VNet |
| NSG | `nsg-eft-{env}` | FTP/SFTP/FTPS/HTTPS inbound, RDP restricted to VNet |
| Availability Set | `avset-eft-{env}` | 2 fault domains, 5 update domains |
| Shared Disk | `disk-eft-{env}-shared` | 256 GB Premium SSD, maxShares=2 |
| Internal LB | `lb-eft-{env}` | Standard SKU, floating IP on all rules |
| VM (Active) | `EFT-VM-01` | Windows Server 2022 Gen2, static IP `.10` |
| VM (Passive) | `EFT-VM-02` | Windows Server 2022 Gen2, static IP `.11` |
| Storage Account | `steft{env}{unique}` | TLS 1.2+, HTTPS only, quorum witness |

**IP allocation (dev)**

| Resource | IP |
|---|---|
| EFT-VM-01 (Active) | `10.0.1.10` |
| EFT-VM-02 (Passive) | `10.0.1.11` |
| Load Balancer VIP | `10.0.1.100` ← clients connect here |

---

## CI/CD Pipeline

### Workflow: `validate.yml` — runs on every Pull Request

```
PR opened / updated
      │
      ├─► Bicep Lint          az bicep lint
      │
      ├─► Security Scan       Checkov → results in GitHub Security tab
      │
      └─► What-If Preview     az deployment group what-if
                              → posted as a PR comment
```

### Workflow: `deploy.yml` — runs on merge to `main` or manual trigger

```
Push to main (or workflow_dispatch)
      │
      ├─► Deploy Dev          az deployment group create
      │       └─► Pester Tests  validate all resources post-deploy
      │
      └─► Deploy Prod         requires GitHub environment approval
              └─► Pester Tests
```

The **Destroy** action is available via `workflow_dispatch` with `action: destroy` — deletes the entire resource group.

---

## GitHub Setup

### 1. Configure OIDC (recommended — no long-lived secrets)

```bash
# Create app registration
APP_ID=$(az ad app create --display-name "sp-eft-dev-github" --query appId -o tsv)
az ad sp create --id $APP_ID

# Assign contributor role
az role assignment create \
  --assignee $APP_ID \
  --role Contributor \
  --scope /subscriptions/<your-subscription-id>

# Add federated credential for GitHub Actions
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-eft-dev",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:devkantin/Azure-bicep-FTP:environment:dev",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

Repeat for `prod` using `environment:prod` as the subject.

### 2. Create GitHub Environments

Go to **Settings → Environments** and create:
- `dev` — no protection rules (auto-deploys on push to main)
- `prod` — add required reviewers for approval gate

### 3. Add GitHub Secrets

Add these secrets to each environment (**Settings → Environments → Secrets**):

| Secret | Environment | Description |
|---|---|---|
| `AZURE_TENANT_ID` | dev + prod | Azure AD tenant ID |
| `AZURE_CLIENT_ID` | dev | App registration client ID for dev |
| `AZURE_SUBSCRIPTION_ID` | dev | Dev Azure subscription ID |
| `AZURE_CLIENT_ID_PROD` | prod | App registration client ID for prod |
| `AZURE_SUBSCRIPTION_ID_PROD` | prod | Prod Azure subscription ID |
| `EFT_ADMIN_PASSWORD` | dev | VM admin password (dev) |
| `EFT_ADMIN_PASSWORD_PROD` | prod | VM admin password (prod) |

---

## Post-Deploy: Cluster Setup

After the infrastructure is deployed, complete the WSFC and EFT setup manually on the VMs:

```powershell
# Run on both VMs
Install-WindowsFeature -Name Failover-Clustering -IncludeManagementTools

# Run on EFT-VM-01 only
Test-Cluster -Node EFT-VM-01, EFT-VM-02
New-Cluster -Name EFT-CLUSTER -Node EFT-VM-01, EFT-VM-02 -StaticAddress 10.x.1.100 -NoStorage

# Configure Cloud Witness
Set-ClusterQuorum -CloudWitness -AccountName "<storage-account-name>" -AccessKey "<key>"

# Initialize shared disk (run in Disk Management or PowerShell)
Initialize-Disk -Number 2 -PartitionStyle GPT
New-Partition -DiskNumber 2 -UseMaximumSize -DriveLetter E
Format-Volume -DriveLetter E -FileSystem NTFS -NewFileSystemLabel "EFT-Shared"
Add-ClusterDisk -InputObject (Get-Disk -Number 2)
```

Then install Globalscape EFT on both nodes, pointing all data paths to `E:\EFT\`.

---

## Running Tests Locally

```powershell
# Install dependencies
Install-Module -Name Az, Pester -Force -Scope CurrentUser

# Connect to Azure
Connect-AzAccount
Set-AzContext -SubscriptionId "<your-subscription-id>"

# Run Pester tests
$container = New-PesterContainer -Path 'tests/infrastructure.tests.ps1' -Data @{
    ResourceGroupName = 'rg-eft-dev'
    SubscriptionId    = '<your-subscription-id>'
}
Invoke-Pester -Container $container -Output Detailed
```

Tests validate: resource group tags, VNet/subnet, NSG rules (FTP/SFTP/FTPS/HTTPS/RDP restriction), availability set fault domains, both VMs (OS image, static IPs, shared disk attachment), LB (floating IP, port rules, health probe), and storage account security settings.

---

## NSG Rules Summary

| Rule | Port | Source | Direction |
|---|---|---|---|
| Allow SFTP | 22 | Any | Inbound |
| Allow FTP | 21 | Any | Inbound |
| Allow FTPS | 990 | Any | Inbound |
| Allow HTTPS (admin) | 443 | Any | Inbound |
| Allow FTP passive | 50000–51000 | Any | Inbound |
| Allow RDP | 3389 | VirtualNetwork only | Inbound |
| Allow WSFC heartbeat | All | VirtualNetwork | Inbound |
| Allow LB health probes | All | AzureLoadBalancer | Inbound |

> Configure the matching passive port range (50000–51000) inside the Globalscape EFT admin console under **Site → Connections → Passive Ports**.

---

## Customizing Parameters

To change IPs, VM sizes, or disk size, edit the parameter files:

- [`bicep/parameters/dev.bicepparam`](bicep/parameters/dev.bicepparam)
- [`bicep/parameters/prod.bicepparam`](bicep/parameters/prod.bicepparam)

Or override at deploy time:
```bash
az deployment group create \
  --resource-group rg-eft-dev \
  --template-file bicep/main.bicep \
  --parameters bicep/parameters/dev.bicepparam \
  --parameters vmSize=Standard_D8s_v3 adminPassword="..."
```
