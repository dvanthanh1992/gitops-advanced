#!/bin/bash

load_env() {
    if [ -f "../../local.env" ]; then
        while IFS= read -r line; do
            if [[ ! "$line" =~ ^# && "$line" =~ = ]]; then
                export "$line"
            fi
        done < "../../local.env"
        echo "✅ Loaded environment variables. K8S_PROJECT_NAME=$K8S_PROJECT_NAME"
    else
        echo "⚠️  local.env file not found. Skipping environment loading."
    fi
}

install_all() {
    echo "${K8S_PROJECT_NAME}"
    echo "-----------------------------------------------"

    echo "🔹 Installing ArgoCD Application Project..."
    envsubst < 0_argo_appproj.yml | kubectl apply -f -

    echo "🔹 Applying Backend ApplicationSet..."
    envsubst < 0_argo_be.yml | kubectl apply -f -

    echo "🔹 Applying Frontend ApplicationSet..."
    envsubst < 0_argo_fe.yml | kubectl apply -f -

    echo "🔹 Installing Kargo Application..."
    envsubst < 1_kargo_appproj.yml | kubectl apply -f -
    envsubst < 1_kargo_be.yml | kubectl apply -f -
    envsubst < 1_kargo_fe.yml | kubectl apply -f -

    echo "✅ Installation completed!"
    echo "-----------------------------------------------"
}

delete_all() {

    echo "🗑️  Deleting Kargo Applications..."
    echo "-----------------------------------------------"
    envsubst < 1_kargo_appproj.yml | kubectl delete -f -
    envsubst < 1_kargo_be.yml | kubectl delete -f -
    envsubst < 1_kargo_fe.yml | kubectl delete -f -

    echo "🗑️  Deleting ArgoCD Applications..."
    echo "-----------------------------------------------"

    echo "🔹 Deleting Frontend ApplicationSet..."
    envsubst < 0_argo_fe.yml | kubectl delete -f -

    echo "🔹 Deleting Backend ApplicationSet..."
    envsubst < 0_argo_be.yml | kubectl delete -f -

    echo "🔹 Deleting ArgoCD Application Project..."
    envsubst < 0_argo_appproj.yml | kubectl delete -f -

    echo "🔹 Deleting all ArgoCD Applications related to ${K8S_PROJECT_NAME}..."
    kubectl delete applicationset  --all -n argocd --force --grace-period=0
    kubectl delete applications    --all -n argocd --force --grace-period=0
    kubectl delete appprojects     --all -n argocd --force --grace-period=0

    echo "✅ Deletion completed!"
    echo "-----------------------------------------------"
}

usage() {
    echo "Usage: $0 {install|delete}"
    exit 1
}

main() {
    if [ "$#" -ne 1 ]; then
        usage
    fi

    ACTION=$1
    load_env

    case "$ACTION" in
        install)
            install_all
            ;;
        delete)
            delete_all
            ;;
        *)
            echo "❌ Invalid action: $ACTION"
            usage
            ;;
    esac
}

main "$@"
