#!/bin/bash
set -o errexit

kubectl apply -f ./vault/setup.yaml
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install vault hashicorp/vault --values ./vault/values.yaml -n vault-auth --wait