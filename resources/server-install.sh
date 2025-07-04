ECR_REPO=590183919098.dkr.ecr.us-west-2.amazonaws.com
SECRETS_REGION=us-west-2
S3_WEB_BUCKET=demo-support-web-dev-bb041aafc60a


mkdir -p /root/scripts
mkdir -p /root/deploy
mkdir -p /root/tg

# Install Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Install Argo CD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
sleep 10
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml


# Install Argo CD CLI
VERSION=$(curl --silent "https://api.github.com/repos/argoproj/argo-cd/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/$VERSION/argocd-linux-amd64
chmod +x /usr/local/bin/argocd
echo "argocd admin initial-password -n argocd |sed 's/ .*//'" > /root/getArgoPass.sh

# Install K9S
wget https://github.com/derailed/k9s/releases/download/v0.40.10/k9s_linux_amd64.deb
dpkg -i k9s_linux_amd64.deb

sudo snap install aws-cli --classic
sudo snap install powershell --classic

# Install Doppler Operator
kubectl apply -f https://github.com/DopplerHQ/kubernetes-operator/releases/latest/download/recommended.yaml
# Create Doppler Secrets
kubectl create secret generic doppler-token-secret-fe --namespace doppler-operator-system --from-literal=serviceToken=$(aws secretsmanager get-secret-value --secret-id doppler-poc --region us-west-2 | jq --raw-output '.SecretString' | jq -r .doppler_token_secret_fe)
kubectl create secret generic doppler-token-secret-be --namespace doppler-operator-system --from-literal=serviceToken=$(aws secretsmanager get-secret-value --secret-id doppler-poc --region us-west-2 | jq --raw-output '.SecretString' | jq -r .doppler_token_secret_be)
kubectl create secret generic doppler-token-secret-tg --namespace doppler-operator-system --from-literal=serviceToken=$(aws secretsmanager get-secret-value --secret-id doppler-poc --region us-west-2 | jq --raw-output '.SecretString' | jq -r .doppler_token_secret_tg)
kubectl create secret generic doppler-token-secret-tg --namespace doppler-operator-system --from-literal=serviceToken=$(aws secretsmanager get-secret-value --secret-id doppler-poc --region us-west-2 | jq --raw-output '.SecretString' | jq -r .doppler_token_secret_tg_k8s_operator_api_key)

# Create and maintain repo secret via iam role ecr permission
cat << INNER1EOF > /root/scripts/secretsCron.sh 

if [ -z $(aws ecr get-login-password --region $SECRETS_REGION) ]; then
    echo "Cannot get AWS password"
    exit
else
   echo "Got AWS password, try prepare secret..."
    kubectl delete secret aws-regcred
    kubectl create secret generic aws-regcred --type=kubernetes.io/dockerconfigjson --from-literal=.dockerconfigjson='{"auths":{"'$ECR_REPO'":{"username":"AWS","password":"'$(aws ecr get-login-password --region $SECRETS_REGION)'","email":"none"}}}'
fi
INNER1EOF

chmod +x /root/scripts/secretsCron.sh
/root/scripts/secretsCron.sh

crontab<<INNER2EOF
0 * * * * /root/scripts/secretsCron.sh
*/5 * * * * /snap/bin/pwsh /root/scripts/web-support.ps1
INNER2EOF

cat << INNER3EOF > /root/tg/values.yaml
twingateOperator:
  apiKey: "$(aws secretsmanager get-secret-value --secret-id doppler-poc --region us-west-2 | jq --raw-output '.SecretString' | jq -r .doppler_token_secret_tg_k8s_operator_api_key)"
  network: "$(aws secretsmanager get-secret-value --secret-id doppler-poc --region us-west-2 | jq --raw-output '.SecretString' | jq -r .doppler_token_secret_tg_k8s_operator_network)"
  remoteNetworkId: "$(aws secretsmanager get-secret-value --secret-id doppler-poc --region us-west-2 | jq --raw-output '.SecretString' | jq -r .doppler_token_secret_tg_k8s_operator_network_id)"
INNER3EOF
helm upgrade twop oci://ghcr.io/twingate/helmcharts/twingate-operator --install --wait -f /root/tg/values.yaml

cat << INNER4EOF > /root/tg/twingate.yaml
apiVersion: twingate.com/v1beta
kind: TwingateConnector
metadata:
  name: tg-connector
spec:
  imagePolicy:
    provider: dockerhub
    schedule: "0 0 * * *"

---

apiVersion: twingate.com/v1beta
kind: TwingateResource
metadata:
  name: devdemo
spec:
  name: devdemo
  address: 10.81.0.0/16
    #alias: devdemo.local

---

apiVersion: twingate.com/v1beta
kind: TwingateResourceAccess
metadata:
  name: devdemo-cloud-access
spec:
  resourceRef:
    name: devdemo
    namespace: default
  principalExternalRef:
    type: group
    name: Cloud Team
INNER4EOF


cat << INNER5EOF > /root/deploy/doppler.yaml
apiVersion: secrets.doppler.com/v1alpha1
kind: DopplerSecret
metadata:
  name: doppler-token-secret-fe
  namespace: doppler-operator-system
spec:
  tokenSecret:
    name: doppler-token-secret-fe
    namespace: doppler-operator-system
  project: public-demo-frontend
  config: dev
  resyncSeconds: 120
  managedSecret:
    name: doppler-token-secret-fe
    namespace: default
    type: Opaque

---

apiVersion: secrets.doppler.com/v1alpha1
kind: DopplerSecret
metadata:
  name: doppler-token-secret-be
  namespace: doppler-operator-system
spec:
  tokenSecret:
    name: doppler-token-secret-be
    namespace: doppler-operator-system
  project: public-demo-backend
  config: dev
  resyncSeconds: 120
  managedSecret:
    name: doppler-token-secret-be
    namespace: default
    type: Opaque

---

apiVersion: secrets.doppler.com/v1alpha1
kind: DopplerSecret
metadata:
  name: doppler-token-secret-tg
  namespace: doppler-operator-system
spec:
  tokenSecret:
    name: doppler-token-secret-tg
    namespace: doppler-operator-system
  project: public-demo-twingate
  config: dev
  resyncSeconds: 120
  managedSecret:
    name: doppler-token-secret-tg
    namespace: default
    type: Opaque

---

apiVersion: secrets.doppler.com/v1alpha1
kind: DopplerSecret
metadata:
  name: doppler-token-secret-tg
  namespace: doppler-operator-system
spec:
  tokenSecret:
    name: doppler_token_secret_tg_k8s_operator_api_key
    namespace: doppler-operator-system
  project: public-demo-twingate
  config: dev
  resyncSeconds: 120
  managedSecret:
    name: doppler_token_secret_tg_k8s_operator_api_key
    namespace: default
    type: Opaque
INNER5EOF

if [ $(hostname) == b-server01 ]; then 
cat << INNER6EOF > /root/deploy/argo.yaml
apiVersion: v1
kind: Service
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","kind":"Service","metadata":{"annotations":{},"labels":{"app.kubernetes.io/component":"server","app.kubernetes.io/name":"argocd-server","app.kubernetes.io/part-of":"argocd"},"name":"argocd-server","namespace":"argocd"},"spec":{"ports":[{"name":"http","port":80,"protocol":"TCP","targetPort":8080},{"name":"https","port":443,"protocol":"TCP","targetPort":8080}],"selector":{"app.kubernetes.io/name":"argocd-server"}}}
  finalizers:
  - service.kubernetes.io/load-balancer-cleanup
  labels:
    app.kubernetes.io/component: server
    app.kubernetes.io/name: argocd-server
    app.kubernetes.io/part-of: argocd
  name: argocd-server
  namespace: argocd
spec:
  allocateLoadBalancerNodePorts: true
  externalTrafficPolicy: Cluster
  internalTrafficPolicy: Cluster
  ipFamilies:
  - IPv4
  ipFamilyPolicy: SingleStack
  ports:
  - name: https
    nodePort: 32562
    port: 8443
    protocol: TCP
    targetPort: 8080
  selector:
    app.kubernetes.io/name: argocd-server
  sessionAffinity: None
  type: LoadBalancer
INNER6EOF
cat << INNER7EOF > /root/scripts/argo.sh
kubectl apply -f /root/deploy/argo.yaml
sleep 10
argocd login 127.0.0.1:8443 --insecure --username admin --password $(argocd admin initial-password -n argocd | sed 's/ .*//')
argocd account update-password --insecure --account admin --current-password $(argocd admin initial-password -n argocd | sed 's/ .*//') --new-password $(aws secretsmanager get-secret-value --secret-id argocd --region us-west-2 | jq --raw-output '.SecretString' | jq -r .password)
INNER7EOF
fi

if [ $(hostname) == g-server01 ]; then 
cat << INNER8EOF > /root/deploy/argo.yaml
apiVersion: v1
kind: Service
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","kind":"Service","metadata":{"annotations":{},"labels":{"app.kubernetes.io/component":"server","app.kubernetes.io/name":"argocd-server","app.kubernetes.io/part-of":"argocd"},"name":"argocd-server","namespace":"argocd"},"spec":{"ports":[{"name":"http","port":80,"protocol":"TCP","targetPort":8080},{"name":"https","port":443,"protocol":"TCP","targetPort":8080}],"selector":{"app.kubernetes.io/name":"argocd-server"}}}
  finalizers:
  - service.kubernetes.io/load-balancer-cleanup
  labels:
    app.kubernetes.io/component: server
    app.kubernetes.io/name: argocd-server
    app.kubernetes.io/part-of: argocd
  name: argocd-server
  namespace: argocd
spec:
  allocateLoadBalancerNodePorts: true
  externalTrafficPolicy: Cluster
  internalTrafficPolicy: Cluster
  ipFamilies:
  - IPv4
  ipFamilyPolicy: SingleStack
  ports:
  - name: https
    nodePort: 32562
    port: 8444
    protocol: TCP
    targetPort: 8080
  selector:
    app.kubernetes.io/name: argocd-server
  sessionAffinity: None
  type: LoadBalancer
INNER8EOF
cat << INNER9EOF > /root/scripts/argo.sh
kubectl apply -f /root/deploy/argo.yaml
sleep 10
argocd login 127.0.0.1:8444 --insecure --username admin --password \$(argocd admin initial-password -n argocd | sed 's/ .*//')
argocd account update-password --insecure --account admin --current-password \$(argocd admin initial-password -n argocd | sed 's/ .*//') --new-password $(aws secretsmanager get-secret-value --secret-id argocd --region us-west-2 | jq --raw-output '.SecretString' | jq -r .password)
INNER9EOF
fi

cat << INNER10EOF > /root/scripts/web-support.ps1
\$Header = @"
<style>
TABLE {border-width: 1px; border-style: solid; border-color: black; border-collapse: collapse;}
TH {border-width: 1px; padding: 3px; border-style: solid; border-color: black; background-color: #6495ED;}
TD {border-width: 1px; padding: 3px; border-style: solid; border-color: black;}
</style>
"@
(kubectl get pods -o wide -o json | ConvertFrom-Json).items | Select @{n="Created";e={\$_.metadata.creationTimeStamp}}, @{n="Status";e={\$_.status.phase}}, @{n="Node";e={\$_.spec.nodeName}}, @{n="Pod Name";e={\$_.metadata.Name}}, @{n="Pod Ip";e={\$_.status.podIP}}, @{n="Date";e={Get-Date -f 'yyyy/MM/dd hh:mm:ss' -AsUTC}}  | Where "Pod Name" -like "ignition-*" | Sort-Object Name | ConvertTo-Html -Head \$Header -Title "Pod Info" | Out-File /tmp/index.html
aws s3 cp /tmp/index.html s3://$S3_WEB_BUCKET
INNER10EOF


chmod +x /root/scripts/web-support.sh
/snap/bin/pwsh /root/scripts/web-support.ps1

kubectl apply -f /root/deploy/doppler.yaml
kubectl apply -f /root/tg/twingate.yaml

sleep 60
chmod +x /root/scripts/argo.sh
/root/scripts/argo.sh
