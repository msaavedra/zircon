# Homelab Kubernetes GitOps Repository

This repository contains **all Kubernetes configuration for my homelab**, managed using a **GitOps-first workflow with Argo CD**.

It intentionally contains **no application source code**.  
Its sole purpose is to declaratively define **cluster infrastructure, platform services, and user-facing workloads**.

---

## High-level Architecture

This cluster follows a strict separation between **imperative bootstrap** and **declarative GitOps management**.

Host OS + kubeadm
↓
Cilium CNI (no kube-proxy)
↓
Argo CD
↓
GitOps-managed platform + services

Once Argo CD is installed, **all further changes are made by committing to this repository**.

---

## App of Apps Pattern

This repository uses the **App of Apps** pattern:

- `argocd/bootstrap.yaml` creates a single **root Argo CD Application**
- That root Application manages:
  - `platform/` (infrastructure)
  - `services/` (applications)

This provides:
- A single GitOps entry point
- Clear separation of concerns
- Independent lifecycle management for platform and services

---

## Bootstrap Process

Cluster bootstrap is performed **once**, imperatively, using a shell script:

1. Install container runtime and Kubernetes packages
2. Initialize the cluster with `kubeadm`
3. Install Cilium (replacing kube-proxy, ingress, and MetalLB)
4. Install Argo CD
5. Apply `argocd/bootstrap.yaml`

After this point:
- The bootstrap script is no longer used
- Argo CD becomes the source of truth

---

## Argo CD Management Model

- Argo CD is installed manually, then **self-managed via Git**
- All Argo CD `Application` resources live under `argocd/`
- Platform and services are managed as separate Argo Applications

Argo CD is configured to:
- Automatically sync
- Prune removed resources
- Self-heal drift

---

## Platform Components

The `platform/` directory contains **cluster-wide infrastructure**, such as:

- Networking add-ons
- Storage provisioners
- Certificate management
- Shared namespaces

Rule of thumb:

> If an application is deleted, platform components should continue running.

---

## Services

The `services/` directory contains **user-facing workloads**, such as:

- Media servers
- Home automation
- Supporting services (MQTT, databases, etc.)

Each service:
- Lives in its own directory
- Is typically deployed via Helm
- Is managed by its own Argo CD Application

---

## Design Goals

- Minimal imperative configuration
- Fully declarative cluster state
- Easy rebuilds and disaster recovery
- Clear ownership boundaries
- Simple mental model

---

## Non-goals

- Managing application source code
- Supporting cloud providers
- Fully automated bare-metal provisioning. This assumes an existing Debian 13 install.

---

## Notes

- Secrets management is intentionally excluded from the initial bootstrap
- All components are version-pinned where possible
- Changes should be made via pull requests whenever practical

---

## References

- Argo CD: https://argo-cd.readthedocs.io/
- Kubernetes: https://kubernetes.io/
- Cilium: https://cilium.io/