#!/bin/bash
# A script (to be run as root with sudo) on Debian 13 to remove the setup handled by the debian_setup.sh script.

set -e

SCRIPT_DIR="$( cd "$( dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" >/dev/null 2>&1 && pwd )"
source "${SCRIPT_DIR}/env.sh"

echo "=== Stopping Kubernetes workloads (best effort) ==="

if command -v kube_do kubectl >/dev/null 2>&1 && [ -f /etc/kubernetes/admin.conf ]; then
  kube_do kubectl --kubeconfig=/etc/kubernetes/admin.conf delete --all ns || true
fi

echo "=== Resetting kubeadm ==="

if command -v kubeadm >/dev/null 2>&1; then
  kubeadm reset -f || true
fi

echo "=== Stopping and disabling services ==="

systemctl disable --now kubelet
systemctl disable --now containerd

echo "=== Removing Kubernetes and container runtime packages ==="

apt-mark unhold kubeadm kubelet kubectl helm containerd.io

apt purge -y \
  kubeadm \
  kubelet \
  kubectl \
  helm \
  containerd.io

echo "=== Removing Kubernetes configuration and state directories ==="

rm -rf \
  /etc/kubernetes \
  /var/lib/kubelet \
  /var/lib/etcd \
  /var/lib/cni \
  /etc/cni \
  /opt/cni \
  /run/kubernetes \
  /run/containerd \
  /var/lib/containerd \
  /var/run/containerd

echo "=== Removing Cilium leftovers (if any) ==="

ip link delete cilium_host 2>/dev/null || true
ip link delete cilium_net 2>/dev/null || true
ip link delete cilium_vxlan 2>/dev/null || true

iptables-save | grep -q CILIUM && iptables -F || true
ip6tables-save | grep -q CILIUM && ip6tables -F || true

echo "=== Removing sysctl configuration ==="

rm -f /etc/sysctl.d/k8s.conf
sysctl --system

echo "=== Removing apt sources and keyrings ==="

rm -f \
  /etc/apt/sources.list.d/kubernetes.list \
  /etc/apt/sources.list.d/docker.list \
  /etc/apt/sources.list.d/helm-stable-debian.list \
  /etc/apt/keyrings/kubernetes-apt-keyring.gpg \
  /etc/apt/keyrings/docker.gpg \
  /usr/share/keyrings/helm.gpg \
  /etc/apt/apt.conf.d/90containerd

apt update

echo "=== Removing kube user and home directory ==="

if id "${KUBE_USER}" &>/dev/null; then
  userdel -r "${KUBE_USER}"
fi

echo "=== Kubernetes teardown complete ==="
echo "A reboot is recommended to fully clear networking state."
