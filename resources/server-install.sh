ECR_REPO=590183919098.dkr.ecr.us-west-2.amazonaws.com
SECRETS_REGION=us-west-2

mkdir -p /root/scripts
mkdir -p /root/deploy

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
INNER2EOF


cat << INNER3EOF > /root/deploy/twingate.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: twingate-deployment
  labels:
    app: twingate
    type: proxy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: twingate
  template:
    metadata:
      labels:
        app: twingate
        type: proxy
    spec:
      containers:
      - name: twingate01
        image: twingate/connector:1.75.0
        envFrom:
          - secretRef:
              name: doppler-token-secret-tg # Kubernetes secret name
INNER3EOF


cat << INNER4EOF > /root/deploy/doppler.yaml
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
INNER4EOF

if [ $(hostname) == b-server01 ]; then 
cat << INNER5EOF > /root/deploy/argo.yaml
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
INNER5EOF
cat << INNER6EOF > /root/scripts/argo.sh
kubectl apply -f /root/deploy/argo.yaml
sleep 10
argocd login 127.0.0.1:8443 --insecure --username admin --password $(argocd admin initial-password -n argocd | sed 's/ .*//')
argocd account update-password --insecure --account admin --current-password $(argocd admin initial-password -n argocd | sed 's/ .*//') --new-password $(aws secretsmanager get-secret-value --secret-id argocd --region us-west-2 | jq --raw-output '.SecretString' | jq -r .password)
INNER6EOF
fi

if [ $(hostname) == g-server01 ]; then 
cat << INNER5EOF > /root/deploy/argo.yaml
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
INNER5EOF
cat << INNER6EOF > /root/scripts/argo.sh
kubectl apply -f /root/deploy/argo.yaml
sleep 10
argocd login 127.0.0.1:8444 --insecure --username admin --password $(argocd admin initial-password -n argocd | sed 's/ .*//')
argocd account update-password --insecure --account admin --current-password $(argocd admin initial-password -n argocd | sed 's/ .*//') --new-password $(aws secretsmanager get-secret-value --secret-id argocd --region us-west-2 | jq --raw-output '.SecretString' | jq -r .password)
INNER6EOF
fi

kubectl apply -f /root/deploy/doppler.yaml
kubectl apply -f /root/deploy/twingate.yaml

sleep 60
chmod +x /root/scripts/argo.sh
/root/scripts/argo.sh
