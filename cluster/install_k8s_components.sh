#!/bin/bash

set -euo pipefail

K8S_VERSION="1.29"
CERT_MANAGER_CHART_VERSION="1.16.1"
ARGO_CD_CHART_VERSION="7.7.3"          # APP VERSION v2.13.0
ARGO_ROLLOUTS_CHART_VERSION="2.38.2"   # APP VERSION v1.7.2
HARBOR_IP="192.168.145.112"
HARBOR_ADMIN_PASSWORD="admin"
HARBOR_PROJECT="kargo"
HARBOR_NAMESPACE="harbor"
REGISTRY_PREFIX="$HARBOR_IP/$HARBOR_PROJECT"
DOCKER_CONFIG="/etc/docker/daemon.json"

echo "🔧 Step 1: Installing Harbor via Helm..."
if ! helm repo add harbor https://helm.goharbor.io; then
    echo "❌ Failed to add Harbor Helm repository." >&2
    exit 1
fi

if ! helm repo update; then
    echo "❌ Failed to update Helm repository." >&2
    exit 1
fi

if ! helm install harbor harbor/harbor -n $HARBOR_NAMESPACE \
    --set expose.type=loadBalancer                          \
    --set expose.tls.enabled=false                          \
    --set expose.loadBalancer.IP="$HARBOR_IP"               \
    --set externalURL="http://$HARBOR_IP"                   \
    --set harborAdminPassword="$HARBOR_ADMIN_PASSWORD"      \
    --create-namespace                                      \
    --wait; then
    echo "❌ Harbor installation failed." >&2
    exit 1
fi

echo "✅ Harbor installed successfully!"
echo "--------------------------------------------------------------------------"

echo "🔧 Step 2: Configuring Docker to use insecure Harbor registry..."
echo "--------------------------------------------------------------------------"
echo "{\"insecure-registries\": [\"$HARBOR_IP\"]}" | sudo tee "$DOCKER_CONFIG"
echo "✅ Docker is now configured with insecure registry: $HARBOR_IP"

echo "🔧 Restarting Docker..."
systemctl daemon-reload && systemctl restart docker

echo "🔧 Step 3: Logging into Harbor registry..."
if ! docker login $HARBOR_IP -u admin -p "$HARBOR_ADMIN_PASSWORD"; then
    echo "❌ Docker login failed." >&2
    exit 1
fi

echo "✅ Docker login successful!"
echo "--------------------------------------------------------------------------"

echo "🔧 Step 4: Creating Harbor project '$HARBOR_PROJECT'..."

HARBOR_API="http://$HARBOR_IP/api/v2.0"
if curl -s -u admin:$HARBOR_ADMIN_PASSWORD "$HARBOR_API/projects/$HARBOR_PROJECT" | grep '"project_id"'; then
    echo "✅ Project '$HARBOR_PROJECT' already exists."
else
    curl -X POST -u admin:$HARBOR_ADMIN_PASSWORD "$HARBOR_API/projects" \
        -H "Content-Type: application/json" \
        -d "{\"project_name\": \"$HARBOR_PROJECT\", \"public\": true}"
    
    if [ $? -eq 0 ]; then
        echo "✅ Project '$HARBOR_PROJECT' created successfully!"
    else
        echo "❌ Failed to create project '$HARBOR_PROJECT'." >&2
        exit 1
    fi
fi

echo "🎉 Harbor setup is complete! You can now push images to $HARBOR_IP/$HARBOR_PROJECT"
echo "--------------------------------------------------------------------------"

echo "🔧 Step 5: Installing Cert-Manager..."
if ! helm install cert-manager cert-manager \
  --repo https://charts.jetstack.io \
  --version "$CERT_MANAGER_CHART_VERSION" \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true \
  --wait; then
    echo "❌ Cert-Manager installation failed." >&2
    exit 1
fi
echo "✅ Cert-Manager installed successfully!"
echo "----------------------------------------------"

echo "🔧 Step 6: Installing Argo CD..."
if ! helm install argocd argo-cd \
  --repo https://argoproj.github.io/argo-helm \
  --version "$ARGO_CD_CHART_VERSION" \
  --namespace argocd \
  --create-namespace \
  --set 'configs.secret.argocdServerAdminPassword=$2a$10$5vm8wXaSdbuff0m9l21JdevzXBzJFPCi8sy6OOnpZMAG.fOXL7jvO' \
  --set dex.enabled=false \
  --set notifications.enabled=false \
  --set server.service.type=LoadBalancer \
  --set server.extensions.enabled=true \
  --set 'server.extensions.contents[0].name=argo-rollouts' \
  --set 'server.extensions.contents[0].url=https://github.com/argoproj-labs/rollout-extension/releases/download/v0.3.3/extension.tar' \
  --wait; then
    echo "❌ Argo CD installation failed." >&2
    exit 1
fi
echo "✅ Argo CD installed successfully!"
echo "----------------------------------------------"

echo "🔧 Step 7: Installing Argo Rollouts..."
if ! helm install argo-rollouts argo-rollouts \
  --repo https://argoproj.github.io/argo-helm \
  --version "$ARGO_ROLLOUTS_CHART_VERSION" \
  --create-namespace \
  --namespace argo-rollouts \
  --wait; then
    echo "❌ Argo Rollouts installation failed." >&2
    exit 1
fi
echo "✅ Argo Rollouts installed successfully!"
echo "----------------------------------------------"

echo "🔧 Step 8: Installing Kargo..."
if ! helm install kargo \
  oci://ghcr.io/akuity/kargo-charts/kargo \
  --namespace kargo \
  --create-namespace \
  --set service.type=LoadBalancer \
  --set api.adminAccount.passwordHash='$2a$10$Zrhhie4vLz5ygtVSaif6o.qN36jgs6vjtMBdM6yrU1FOeiAAMMxOm' \
  --set api.adminAccount.tokenSigningKey="iwishtowashmyirishwristwatch" \
  --wait; then
    echo "❌ Kargo installation failed." >&2
    exit 1
fi

echo "🔄 Patching kargo-api service to LoadBalancer..."
if ! kubectl patch svc kargo-api -n kargo --type='merge' -p '{"spec":{"type":"LoadBalancer"}}'; then
    echo "❌ Failed to patch kargo-api service to LoadBalancer." >&2
    exit 1
fi

echo "✅ kargo-api service patched to LoadBalancer!"
echo "----------------------------------------------"
echo "✅ Kargo installed successfully!"
echo "----------------------------------------------"

echo "🔧 Step 9: Pushing local images to Harbor..."

# Define the registry prefix without IP (only namespace `kargo`)
NAMESPACE="/kargo/"
IMAGES=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "$NAMESPACE")

if [ -z "$IMAGES" ]; then
    echo "❌ No images found for namespace $NAMESPACE."
    exit 1
fi

echo "✅ Found images to push:"
echo "$IMAGES"
echo "--------------------------------------------------------------------------"

echo "$IMAGES" | while read -r IMAGE; do
    IMAGE_NAME=$(echo "$IMAGE" | sed -E "s|^.*/kargo/||")
    FULL_IMAGE="$HARBOR_IP/kargo/$IMAGE_NAME"

    echo "🚀 Pushing image: $FULL_IMAGE"
    
    docker tag "$IMAGE" "$FULL_IMAGE"
    docker push "$FULL_IMAGE"
    
    if [ $? -eq 0 ]; then
        echo "✅ Successfully pushed: $FULL_IMAGE"
    else
        echo "❌ Failed to push: $FULL_IMAGE"
    fi
    echo "--------------------------------------------------------------------------"
done

VM_LIST=("192.168.145.101" "192.168.145.102")
SSH_KEY="../terraform-vcenter/files/vcenter_ssh_key"
for VM in "${VM_LIST[@]}"; do
    echo "🔧 Connecting to $VM and executing script..."
    ssh -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -i "$SSH_KEY" \
        root@$VM "bash /root/pull_images.sh"
    if [ $? -eq 0 ]; then
        echo "✅ Successfully executed script on $VM"
    else
        echo "❌ Failed to execute script on $VM"
    fi
    echo "--------------------------------------------------"
done
echo "----------------------------------------------"
echo "🎉 All images pushed successfully!"
echo "----------------------------------------------"
