# Argo CD: GitOps from Zero to Production: course files

The runnable files for the book `argocd-zero-to-production.pdf` (Argo CD 3.6.1, Helm chart 10.18.0). The book shows these files
as they are here, so book and repository cannot drift apart.

Fork this repository first. Argo CD pulls from **your** fork: replace `AndriiZil` with your GitHub user name in the files under
`argocd/` that you apply (Lesson 3 shows how).

## What you need

Docker (about 5 GB of free memory), minikube, kubectl, Helm, the `argocd` CLI, a GitHub account. For Part 4 only: Terraform and,
if you want to build it for real, an AWS account. Versions are in the book's introduction.

## Quick start

```
minikube start --profile argocd-lab --cpus=4 --memory=5000
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd --version 10.18.0 --namespace argocd --create-namespace \
  --values setup/values-local.yaml --wait --timeout 6m
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Always check `kubectl config current-context` before you apply or delete anything.

## Where each lesson's files are

| Lesson | Files |
|---|---|
| 2 Argo CD on your laptop | `setup/values-local.yaml`, `argocd/guestbook.yaml` |
| 3 Your first GitOps loop | `apps/podinfo/base/`, `argocd/podinfo.yaml`, `argocd/podinfo-auto.yaml` |
| 4 Helm and Kustomize | `apps/podinfo/overlays/`, `apps/podinfo-helm/`, `argocd/podinfo-{dev,prod}.yaml`, `argocd/podinfo-helm-*.yaml` |
| 5 Controlling the sync | `apps/sync-demo/`, `argocd/sync-*.yaml` |
| 6 App of Apps and ApplicationSets | `argocd/root.yaml`, `argocd/apps/`, `argocd/appsets/`, `argocd/finalizer-demo.yaml` |
| 7 Secrets | `argocd/sealed-secrets.yaml`, `platform/sealed-secrets/`, `apps/podinfo-secret/`, `argocd/podinfo-secret.yaml` |
| 8 Shipping versions | `.github/workflows/release.yaml`, `apps/rollouts-demo/`, `argocd/rollouts*.yaml` |
| 9 Projects and RBAC | `argocd/security/`, `apps/security/` |
| 10 Notifications and troubleshooting | `argocd/notifications/`, `apps/broken/`, `argocd/broken-apps.yaml` |
| 11 to 13 AWS | `aws/terraform/`, `aws/argocd/`, `aws/platform/` |
| Appendix B | `reference/` |

## What was tested

- **Parts 1 to 3 (Lessons 1 to 10):** every command and output in the book was run for real on a minikube cluster (profile
  `argocd-lab`, Kubernetes v1.37.0, arm64) with Argo CD 3.6.1. Each lesson's capture script reset the lab before it ran. The
  lessons were captured one by one on the same cluster, not in one continuous run.
- **Things not run, and labelled so in the book:** SSO (Lesson 9), Slack (Lesson 10), Image Updater, the GitHub Actions workflow
  (it never runs in this repository), and everything in Part 4 that needs AWS.
- **Part 4 (AWS) was checked offline only.** `terraform fmt`, `init -backend=false` and `validate`, `helm template` plus
  `kubeconform`, and `kustomize build` pass. `terraform plan` and `apply` were never run, no AWS account was used, and the project has
  no remote state backend: add one before you use it.
- A `SealedSecret` only opens on the cluster that sealed it. Seal your own (Lesson 7); the one in this repository will not open on
  your cluster.
- All manifests pass `kubeconform`. There is no plain `Secret` in the repository.
