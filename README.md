# Introduction

## GitOps Folder Structure
```console
.
├── app
│   ├── backend
│   │   ├── Dockerfile
│   │   └── main.py
│   └── frontend
│       ├── Dockerfile
│       └── main.py
├── argo
│   ├── argo_appproj.yml
│   ├── argo_be.yml
│   ├── argo_fe.yml
├── kargo
│   ├── kargo_appproj.yml
│   ├── kargo_be.yml
│   ├── kargo_fe.yml
├── cluster
│   ├── cluster-01
│   │   ├── dev
│   │   │   ├── values-backend.yml
│   │   │   └── values-frontend.yml
│   │   └── staging
│   │       ├── values-backend.yml
│   │       └── values-frontend.yml
│   ├── cluster-02
│   │   ├── prod-hcm
│   │   │   ├── values-backend.yml
│   │   │   └── values-frontend.yml
│   │   └── prod-hni
│   │       ├── values-backend.yml
│   │       └── values-frontend.yml
│   └── install_k8s_components.sh
└── terraform-vcenter
    ├── files
    │   ├── microk8s.sh
    │   ├── pull_images.sh
    │   └── vcenter_ssh_key
    ├── main.tf
    ├── terraform.auto.tfvars
    └── variables.tf
```

## Acknowledgements

- [Christian Hernandez leads developer experience at Codefresh ](https://github.com/christianh814)

- [Codefresh - Best practices for promotion between clusters](https://github.com/argoproj/argo-cd/discussions/5667)

- [Codefresh - Stop Using Branches for Deploying to Different GitOps Environments](https://codefresh.io/blog/stop-using-branches-deploying-different-gitops-environments/)

- [Codefresh - How to Model Your GitOps Environments and Promote Releases between Them](https://codefresh.io/blog/how-to-model-your-gitops-environments-and-promote-releases-between-them/)

- [I'd like to thank Andrew Pitt who has led the way on lot of the GitOps stuff](https://github.com/gnunn-gitops/standards/blob/master/folders.md#acknowledgements)


## Examples

Here are a couple of repositories where you can see this standard in action:

* [Product Catalog](https://github.com/gnunn-gitops/product-catalog). This is a three tier application (front-end, back-end and database) deployed using GitOps with ArgoCD (or ACM) and kustomize. It deploys three separate environments (dev, test and prod) along wth Tekton pipelines to build the front-end and back-end applications. It also deploys a grafana instance for application monitoring that ties into OpenShift's [user defined monitoring](https://docs.openshift.com/container-platform/4.6/monitoring/enabling-monitoring-for-user-defined-projects.html).

* [Cluster Configuration](https://github.com/gnunn-gitops/cluster-config). This repo shows how I configure my OpenShift clusters using GitOps with ArgoCD. It configures a number of things including certificates, authentication, default operators, console customizations, storage and more.

I also highly recommend checking out the [Red Hat Canada GitOps](https://github.com/redhat-canada-gitops) organization as well. These repos include a default installation of the excellent [ArgoCD](https://github.com/redhat-canada-gitops/argocd) operator as well as a [catalog](https://github.com/redhat-canada-gitops/catalog) of tools and applications deployed with kustomize.
