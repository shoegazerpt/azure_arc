#!/bin/bash

sudo apt-get update

# Injecting environment variables
echo '#!/bin/bash' >> vars.sh
echo $adminUsername:$1 | awk '{print substr($1,2); }' >> vars.sh
echo $adminPasswordOrKey:$2 | awk '{print substr($1,2); }' >> vars.sh
echo $appId:$3 | awk '{print substr($1,2); }' >> vars.sh
echo $password:$4 | awk '{print substr($1,2); }' >> vars.sh
echo $tenantId:$5 | awk '{print substr($1,2); }' >> vars.sh
sed -i '2s/^/export adminUsername=/' vars.sh
sed -i '3s/^/export adminPasswordOrKey=/' vars.sh
sed -i '4s/^/export appId=/' vars.sh
sed -i '5s/^/export password=/' vars.sh
sed -i '6s/^/export tenantId=/' vars.sh

chmod +x vars.sh 
. ./vars.sh

publicIp=$(curl icanhazip.com)

# Installing Microk8s
sudo -u $adminUsername mkdir /home/${adminUsername}/.kube
sudo snap install microk8s --classic
sudo microk8s status --wait-ready
sudo microk8s enable dashboard dns istio storage helm3
sudo microk8s kubectl get all --all-namespaces

# For further logins
sudo usermod -a -G microk8s $adminUsername
sudo chown -f -R $adminUsername ~/.kube

# Installing Helm 3
sudo snap install helm --classic

# Installing Azure CLI & Azure Arc Extensions
sudo apt-get update
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

sudo -u $adminUsername az extension add --name connectedk8s
sudo -u $adminUsername az extension add --name k8sconfiguration

sudo -u $adminUsername az login --service-principal --username ${appId} --password ${password} --tenant ${tenantId}

# Install kubectl and config file to be used by az connectedk8s
sudo snap install kubectl --classic
sudo microk8s config | sed -e 's/certificate-authority-data\:\s.*$/insecure-skip-tls-verify: true/g' > ~/.kube/config

# Creating "hello-world" Kubernetes yaml
sudo cat <<EOT >> hello-kubernetes.yaml
# hello-kubernetes.yaml
apiVersion: v1
kind: Service
metadata:
  name: hello-kubernetes
spec:
  type: NodePort
  ports:
  - port: 80
    nodePort: 30557
    targetPort: 8080
  selector:
    app: hello-kubernetes
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-kubernetes
spec:
  replicas: 3
  selector:
    matchLabels:
      app: hello-kubernetes
  template:
    metadata:
      labels:
        app: hello-kubernetes
    spec:
      containers:
      - name: hello-kubernetes
        image: paulbouwer/hello-kubernetes:1.8
        ports:
        - containerPort: 8080
EOT

sudo cp hello-kubernetes.yaml /home/${adminUsername}/hello-kubernetes.yaml