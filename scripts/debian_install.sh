#!/bin/bash
# A script (to be run as root with sudo) on Debian 13 to set up a fully-functional single-node kubernetes cluster with
# a combined control plane/worker. This installs all packages, initializes kubernetes and all the lowest-level
# infrastructure, then allows ArgoCD to deploy the rest.

set -e

# Adjust the config variables here as needed.
KUBE_USER="kube"
KUBE_UID=2000
KUBE_GID=2000
KUBE_HOME="/home/kube"
KUBE_CIDR="10.236.0.0/16"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Installing Kubernetes prerequisites ==="

cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system

apt update
apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg

# Set up kubernetes apt source
rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
chmod a+r /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /" > /etc/apt/sources.list.d/kubernetes.list

# Set up containerd apt source
rm -f /etc/apt/keyrings/docker.gpg
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian trixie stable" > /etc/apt/sources.list.d/docker.list

# Set up helm apt source
rm -f /usr/share/keyrings/helm.gpg
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor -o /usr/share/keyrings/helm.gpg
chmod a+r /usr/share/keyrings/helm.gpg
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" > /etc/apt/sources.list.d/helm-stable-debian.list

apt update
apt install -y \
    containerd.io \
    helm \
    kubeadm \
    kubelet \
    kubectl

sudo apt-mark hold containerd.io helm kubeadm kubelet kubectl

containerd config default > /etc/containerd/config.toml
sed -e 's/SystemdCgroup = false/SystemdCgroup = true/g' -i /etc/containerd/config.toml

echo "=== Initializing cluster ==="

systemctl enable --now containerd

systemctl enable --now kubelet

if [ ! -f /etc/kubernetes/admin.conf ]; then
  kubeadm init --skip-phases=addon/kube-proxy --pod-network-cidr="${KUBE_CIDR}"
fi

if ! id "${KUBE_USER}" &>/dev/null; then
  groupadd "${KUBE_GID}"
  useradd -u "${KUBE_UID}" -g "${KUBE_GID}" -m -d "${KUBE_HOME}" "${KUBE_USER}"
fi

kube_do() {
  sudo -u kube -i "${@}"
}

kube_do mkdir -p "${KUBE_HOME}/.kube"
kube_do cp -f /etc/kubernetes/admin.conf "${KUBE_HOME}/.kube/config"
chown -R ${KUBE_USER}:${KUBE_USER} "${KUBE_HOME}/.kube"

echo "=== Installing Cilium ==="

kube_do helm repo list | grep -q cilium || \
  kube_do helm repo add cilium https://helm.cilium.io
kube_do helm repo update
kube_do helm upgrade --install cilium cilium/cilium \
  --namespace kube-system \
  --version 1.18.5 \
  --values "${SCRIPT_DIR}/../platform/bootstrap/cilium/values.yaml"
kube_do kubectl -n kube-system rollout status ds/cilium
kube_do kubectl -n kube-system rollout status deploy/cilium-operator
kube_do kubectl apply -f lb-pool.yaml
kube_do kubectl apply -f l2-policy.yaml

echo "=== Installing Argo CD ==="

for ns in argocd platform services; do
  kube_do kubectl get ns $ns >/dev/null 2>&1 || \
    kube_do kubectl create ns $ns
done

kube_do kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.2.3/manifests/install.yaml
kube_do kubectl apply -f "${SCRIPT_DIR}/../argocd/bootstrap.yaml"
