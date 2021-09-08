#!/bin/bash
# set -o errexit

currContext=$(kubectl config current-context)
clusterName=$(kubectl config view --raw -o jsonpath="{.contexts[?(@.name == \"$currContext\")].name}")
# some black magic to have the ca certificate in one line with \n at each new line
ca=$(kubectl config view --raw -o jsonpath="{.clusters[?(@.name == \"$clusterName\")].cluster.certificate-authority-data}" | base64 -d | awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' | sed '$ s/\\n$//')
jwt=$(kubectl get secret vault-auth -n vault-auth -o jsonpath={.data.token} | base64 --decode)
rootToken="root"
kubeAuthName="kubernetes"

# Kubernetes Auth
curl \
    --request PUT \
    --data "{\"type\": \"kubernetes\", \"description\": \"auth for k8s\" }" \
    -H "Content-Type: application/json" \
    -H "X-Vault-Token: $rootToken" \
    http://127.0.0.1:8200/v1/sys/auth/$kubeAuthName


curl \
    --request PUT \
    --data "{\"kubernetes_host\": \"https://kubernetes.default:443\", \"kubernetes_ca_cert\": \"${ca}\", \"token_reviewer_jwt\": \"$jwt\" }" \
    -H "Content-Type: application/json" \
    -H "X-Vault-Token: $rootToken" \
    http://127.0.0.1:8200/v1/auth/$kubeAuthName/config


# Policies
curl \
    --request PUT \
    -H "Content-Type: application/json" \
    -H "X-Vault-Token: $rootToken" \
    --data '{"policy":"path \"apps/pbn1\" {capabilities=[\"read\"]} "}' \
    http://127.0.0.1:8200/v1/sys/policy/app_ro_pbn1


# Role
curl \
    --request PUT \
    -H "Content-Type: application/json" \
    -H "X-Vault-Token: $rootToken" \
    --data "{\"bound_service_account_names\": [\"pbn1\"], \"bound_service_account_namespaces\": [\"default\"], \"policies\": [\"app_ro_pbn1\"],\"token_ttl\": \"10m\"}" \
    http://127.0.0.1:8200/v1/auth/$kubeAuthName/role/pbn1-role

# Mounts
curl \
    --request PUT \
    --data "{\"type\": \"kv\", \"options\": { \"version\": \"1\"}}" \
    -H "Content-Type: application/json" \
    -H "X-Vault-Token: $rootToken" \
    http://127.0.0.1:8200/v1/sys/mounts/apps