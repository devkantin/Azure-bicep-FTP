#!/usr/bin/env bash
# Manual deployment script — run this BEFORE setting up the Bicep/CI-CD pipeline.
# Purpose: verify the infrastructure works in Azure before codifying it.
# Prerequisites: az cli logged in, Bicep CLI installed (az bicep install)

set -euo pipefail

ENVIRONMENT="${1:-dev}"
LOCATION="eastus"
RESOURCE_GROUP="rg-eft-${ENVIRONMENT}"
ADMIN_USERNAME="eftadmin"

echo "==> Deploying EFT infrastructure to environment: ${ENVIRONMENT}"
echo "==> Resource group: ${RESOURCE_GROUP} | Location: ${LOCATION}"
echo ""

# ─── Step 1: Resource Group ──────────────────────────────────────────────────
echo "[1/4] Creating resource group..."
az group create \
  --name "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --tags environment="${ENVIRONMENT}" project="globalscape-eft" managedBy="manual"
echo "      Done."

# ─── Step 2: Prompt for password ─────────────────────────────────────────────
echo ""
echo "[2/4] Enter the VM admin password (min 12 chars, upper+lower+number+symbol):"
read -rs ADMIN_PASSWORD
echo ""

# ─── Step 3: Deploy Bicep ────────────────────────────────────────────────────
echo "[3/4] Deploying Bicep template (this takes ~15-20 minutes for VMs)..."
PARAM_FILE="bicep/parameters/${ENVIRONMENT}.bicepparam"

DEPLOY_OUTPUT=$(az deployment group create \
  --resource-group "${RESOURCE_GROUP}" \
  --template-file bicep/main.bicep \
  --parameters "${PARAM_FILE}" \
  --parameters adminUsername="${ADMIN_USERNAME}" adminPassword="${ADMIN_PASSWORD}" \
  --name "eft-manual-deploy-$(date +%Y%m%d%H%M%S)" \
  --output json)

VM01_NAME=$(echo "${DEPLOY_OUTPUT}" | jq -r '.properties.outputs.vm01Name.value')
VM02_NAME=$(echo "${DEPLOY_OUTPUT}" | jq -r '.properties.outputs.vm02Name.value')
LB_IP=$(echo "${DEPLOY_OUTPUT}"     | jq -r '.properties.outputs.lbPrivateIp.value')
SA_NAME=$(echo "${DEPLOY_OUTPUT}"   | jq -r '.properties.outputs.storageAccountName.value')

echo "      Done."

# ─── Step 4: Summary ─────────────────────────────────────────────────────────
echo ""
echo "[4/4] Deployment complete. Resource summary:"
echo ""
echo "  Resource Group : ${RESOURCE_GROUP}"
echo "  Active VM      : ${VM01_NAME}  (10.x.1.10)"
echo "  Passive VM     : ${VM02_NAME}  (10.x.1.11)"
echo "  LB Frontend IP : ${LB_IP}  ← clients connect here"
echo "  Witness SA     : ${SA_NAME}"
echo ""
echo "Next steps:"
echo "  1. RDP into EFT-VM-01 via Azure Bastion or VPN"
echo "  2. Initialize the shared disk (Disk Management → Initialize → Format as E:\\)"
echo "  3. Install Windows Server Failover Clustering feature on both VMs"
echo "  4. Create the cluster using IP ${LB_IP} as the cluster IP"
echo "  5. Set Cloud Witness using storage account: ${SA_NAME}"
echo "  6. Install Globalscape EFT on both nodes pointing data to E:\\"
echo ""
echo "Run Pester tests to validate infrastructure:"
echo "  pwsh -Command \""
echo "    \$c = New-PesterContainer -Path tests/infrastructure.tests.ps1 -Data @{ ResourceGroupName='${RESOURCE_GROUP}'; SubscriptionId=\$(az account show --query id -o tsv) }"
echo "    Invoke-Pester -Container \$c -Output Detailed"
echo "  \""
