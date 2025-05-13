# cloud-k8s-demo
K8S manifests for Ignition Public Demo

## Configure Account
* Setup CF Role
* Deploy CF One Time
* Setup OIDC
* Create ROLE (EC2, RDS, Route53, S3, CertificateManager, IAM, SecretsManager access)

## Setup Github Actions
* https://github.com/ia-rjacobo/cloud-k8s-public-demo/blob/main/.github/workflows/tf-apply.yml

## Deploy

## One Time Setup on Server01
* Copy to server01 and run (https://github.com/ia-rjacobo/cloud-k8s-public-demo/blob/main/resources/server-install.sh)

## Login to ArgoCD
* Setup Repository: https://github.com/ia-rjacobo/cloud-k8s-public-demo/blob/main/reference/argo-repository.png
* Setup Ignition repo: https://github.com/ia-rjacobo/cloud-k8s-public-demo/blob/main/reference/argo-ignition-configuration.png
