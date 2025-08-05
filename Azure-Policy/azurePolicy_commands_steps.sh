# Prerequisites

az --version (should be 2.49.0 or higher)

# Step 1: Register the Microsoft.PolicyInsights Resource Provider: - Was already Present.

az provider show --namespace Microsoft.PolicyInsights --query "registrationState" # Check

az provider register --namespace Microsoft.PolicyInsights # Register

#Check if add on is enable 

az aks show \
    --resource-group "er-security-nonprod-rg" \
    --name "ernp-k8s-security-ci-1" \
    --query "addonProfiles.azurepolicy.enabled" \
    --output tsv

# Enable Add-on

RESOURCE_GROUP_NAME="myAKSResourceGroup" # Your existing resource group name
AKS_CLUSTER_NAME="myAKSCluster" # Your existing AKS cluster name

az aks enable-addons \
    --resource-group er-security-nonprod-rg \
    --name ernp-k8s-security-ci-1 \
    --addons azure-policy


# You can also check the Kubernetes pods in your cluster:

kubectl get pods -n kube-system | grep azure-policy
kubectl get pods -n gatekeeper-system

#You should see azure-policy and gatekeeper related pods running. It might take a few minutes for these pods to be fully deployed.

kubectl get constrainttemplate

kubectl get constraint

# Custom Message.
# Deployment failed! This cluster is configured to only allow container images from your private Azure Container Registry (ernpallregistry.azurecr.io). Please update your image to use a path like 'ernpallregistry.azurecr.io/<your-image>:<tag>'.

# Remove add ons - If required.

RESOURCE_GROUP_NAME="myAKSResourceGroup" # Your existing resource group name
AKS_CLUSTER_NAME="myAKSCluster" # Your existing AKS cluster name
az aks disable-addons \
--resource-group $RESOURCE_GROUP_NAME \
--name $AKS_CLUSTER_NAME \
--addons azure-policy

# Step 1: Create the Custom Policy Definition

# Create the policy definition at the subscription scope

az policy definition create \
    --name "AKSDenyPublicImages" \
    --display-name "Kubernetes cluster containers should only use allowed/private images" \
    --description "Enforces that AKS cluster containers only use images from ernpallregistry.azurecr.io. Custom policy." \
    --mode Microsoft.Kubernetes.Data \
    --rules "myPrivateImagePolicy.json" \ 
    --subscription "YOUR_SUBSCRIPTION_ID_OR_NAME"

# Step 2: Get the Resource ID of your Specific AKS Cluster
# Replace 'YOUR_RESOURCE_GROUP_NAME' and 'YOUR_AKS_CLUSTER_NAME'
az aks show \
    --resource-group "YOUR_RESOURCE_GROUP_NAME" \
    --name "YOUR_AKS_CLUSTER_NAME" \
    --query "id" \
    --output tsv

# Step 3: Assign the Policy to the Specific AKS Cluster
# Replace 'YOUR_AKS_CLUSTER_RESOURCE_ID' with the ID obtained from Step 2
# Replace 'YOUR_SUBSCRIPTION_ID_OR_NAME' with the subscription where the policy *definition* resides.
# Note: The 'policy' parameter refers to the NAME of your policy definition created in Step 1.

az policy assignment create \
    --name "AKSDenyPublicImagesAssignmentOnMyCluster" \
    --display-name "Restrict Public Images on MySpecificAKSCluster" \
    --policy "AKSDenyPublicImages" \
    --scope "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/YOUR_RESOURCE_GROUP_NAME/providers/Microsoft.ContainerService/managedClusters/YOUR_AKS_CLUSTER_NAME" \
    --params "{'allowedContainerImagesRegex': {'value': '^ernpallregistry\\.azurecr\\.io/.+$'}, 'source': {'value': 'Original'}, 'effect': {'value': 'Deny'}, 'excludedNamespaces': {'value': ['kube-system', 'gatekeeper-system', 'azure-arc', 'azure-extensions-usage-system', 'cert-manager', 'cnpg-system', 'default', 'kube-node-lease', 'kube-public']}, 'namespaces': {'value': []}, 'excludedContainers': {'value': []}}" \
    --subscription "YOUR_SUBSCRIPTION_ID_OR_NAME" # This is the subscription where the policy *definition* is.


# Azure Policy 
# https://learn.microsoft.com/en-us/azure/governance/policy/concepts/policy-for-kubernetes#install-azure-policy-add-on-for-aks

# Azure Policy Assignment 
# https://learn.microsoft.com/en-gb/azure/governance/policy/assign-policy-azurecli
