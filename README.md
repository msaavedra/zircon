# Homelab Kubernetes GitOps Repository

This repository contains all Kubernetes configuration for my homelab, managed using a GitOps-centric workflow with Argo CD.

It intentionally contains no application source code. The only imperative code is a bash script to initialize kubernetes with the cilium CNI, and install ArgoCD. Beyond that point, all cluster infrastructure, and platform infrastructure are defined declaratively.

---

## High-level Architecture

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

- `argocd/bootstrap.yaml` creates a single root Argo CD Application
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

---

## Services

The `services/` directory contains user-facing workloads, such as:

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

## Out of Scope Jobs Avoided Here

- Managing application source code
- Supporting cloud providers
- Fully automated bare-metal provisioning. This assumes an existing Debian 13 install.

---

## Notes

- Secrets management is intentionally excluded from the initial bootstrap
- All components are version-pinned where possible

---

## References

- Argo CD: https://argo-cd.readthedocs.io/
- Kubernetes: https://kubernetes.io/
- Cilium: https://cilium.io/