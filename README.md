# Automated RKE2 Kubernetes Cluster Deployment (Terraform + Ansible + AWS)

This project automates the **provisioning and configuration of a high-availability RKE2 Kubernetes cluster** on AWS using **Infrastructure-as-Code** principles.  
The deployment integrates **Terraform** for infrastructure provisioning and **Ansible** for cluster setup and configuration.

---

## 🚀 Project Overview

The goal of this project is to create a fully automated, reproducible Kubernetes environment:
- **Terraform** provisions all AWS infrastructure (VPC, subnets, EC2 instances, networking, security groups).
- **Ansible** bootstraps the RKE2 Kubernetes cluster, including:
  - HAProxy-based load balancer (public entrypoint)
  - Highly-available control plane (3 masters)
  - Multiple worker nodes
  - Automated token distribution and cluster join
- End result: a fully functional, scalable, and HA RKE2 cluster ready for workloads.

---

## 🧩 Architecture

```text
                ┌───────────────────────────┐
                │        Developer PC       │
                │  Terraform + Ansible CLI  │
                └──────────────┬────────────┘
                               │ SSH
                               ▼
                    ┌─────────────────────┐
                    │     HAProxy Node    │
                    │ (Public EC2, Jump)  │
                    │  - Load Balancer    │
                    │  - ProxyCommand SSH │
                    └──────────┬──────────┘
                               │
          ┌────────────────────┴────────────────────┐
          │                    │                    │
┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
│   Master-1      │   │   Master-2      │   │   Master-3      │
│  RKE2 Server    │   │  RKE2 Server    │   │  RKE2 Server    │
└─────────────────┘   └─────────────────┘   └─────────────────┘
          │                    │                    │
          └────────────────────┬────────────────────┘
                               │
                    ┌───────────────────────┐
                    │     Worker  Nodes     │
                    │     (RKE2 Agents)     │
                    └───────────────────────┘
```

## 🛠️ Tech Stack
| Tool                                   | Purpose                                             |
| -------------------------------------- | --------------------------------------------------- |
| **Terraform**                          | Infrastructure provisioning (VPC, EC2, networking)  |
| **Ansible**                            | Configuration management and cluster setup          |
| **RKE2 (Rancher Kubernetes Engine 2)** | Lightweight Kubernetes distribution                 |
| **HAProxy**                            | Load balancing for Kubernetes API and control plane |
| **AWS EC2**                            | Compute infrastructure                              |
| **Ubuntu 24.04 LTS**                   | Base OS for all nodes                               |

---

## ⚙️ Deployment Flow
#### 1. Configuration
##### terraform/variables.tf
```
### You can change "eu-central-1" to your region
variable "region" {
  description = "The AWS region where resources will be created."
  default     = "eu-central-1"
}
### "ami-0a116fa7c861dd5f9" is Ubuntu Server 24.04 LTS image for eu-central-1, if you changed your region you need to get new ami_id from AWS website
variable "ami_id" {
  description = "AMI ID used for EC2 instances."
  default     = "ami-0a116fa7c861dd5f9"
}
### You can add additional workers or masters, by default this is the maximum number allowed on AWS Free Tier (16 vCPU)
variable "cluster_nodes" {
  description = "Definition of the cluster nodes (name and role)."
  type = map(object({
    role = string # Expected values: 'master', 'worker', or 'haproxy'
  }))
  default = {
    "master-1" = { role = "master" },
    "master-2" = { role = "master" },
    "master-3" = { role = "master" },
    "worker-1" = { role = "worker" },
    "worker-2" = { role = "worker" },
    "worker-3" = { role = "worker" },
    "worker-4" = { role = "worker" },
    "haproxy"  = { role = "haproxy" }, # Don't add additional haproxy instances
  }
}
### You can change your instance types here for example "m7i-flex.large" to "c7i-flex.large"
variable "instance_types" {
  description = "Instance types for each node role."
  type = object({
    master  = string
    worker  = string
    haproxy = string
  })
  default = {
    master  = "m7i-flex.large"
    worker  = "m7i-flex.large"
    haproxy = "t3.small"
  }
}
### If you change region you need to change availability zone too
variable "availability_zone" {
  description = "AWS availability zone to deploy the instances."
  default     = "eu-central-1a"
}
```
#### 2. Provision infrastructure
```
cd terraform
terraform init
terraform apply
```
#### This will create:
- VPC with public/private subnets
- EC2 instances for HAProxy, masters, and workers
- Automatically generate Ansible inventory.ini

#### 3. Configure the cluster
```
cd ../ansible
ansible-playbook playbooks/setup-cluster.yaml
```
#### 4. This playbook will:
- Configure base packages on all nodes
- Install and start RKE2 server on masters
- Join other masters and workers automatically
- Set up HAProxy as external load balancer
- Verify and show cluster status
---
## 📦 Repository Structure
```
terraform-ansible-rke2-cluster/
├── terraform/
│   ├── main.tf
│   ├── network.tf
│   ├── outputs.tf
│   └── variables.tf  ##(configuration)
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/
│   │   └── inventory.ini  ##(auto-generated by terraform)
│   ├── roles/
│   │   ├── common/
│   │   │   └── tasks/
│   │   │       └── main.yaml
│   │   ├── master/
│   │   │   └── tasks/
│   │   │       └── main.yaml
│   │   ├── worker/
│   │   │   └── tasks/
│   │   │       └── main.yaml
│   │   └── haproxy/
│   │       ├── tasks/
│   │       │   └── main.yaml
│   │       └── templates/
│   │           └── haproxy.cfg.j2
│   └── playbooks/
│       └── setup-cluster.yaml
└── README.md
```
---
## 🌐 Networking Overview
| Component   | Subnet  | Notes                                     |
| ----------- | ------- | ----------------------------------------- |
| HAProxy     | Public  | Public IP for external access             |
| Masters     | Private | Internal RKE2 control plane               |
| Workers     | Private | Internal RKE2 agents                      |
| NAT Gateway | Public  | Enables internet access for private nodes |
---
## 🧠 Key Features
- ✅ Fully automated cluster bootstrap (no manual SSH)
- ✅ Secure SSH jump host via HAProxy
- ✅ High-availability RKE2 control plane
- ✅ Dynamic Ansible inventory generation from Terraform
- ✅ Built-in retry logic for resilient setup
- ✅ Modular design (independent Terraform / Ansible stages)
---
## 📸 Example Output
```
$ kubectl get nodes -o wide
NAME         STATUS   ROLES                       AGE   VERSION           INTERNAL-IP
master-1     Ready    control-plane,etcd,master   10m   v1.33.5+rke2r1    10.0.2.63
master-2     Ready    control-plane,etcd,master   10m   v1.33.5+rke2r1    10.0.2.183
master-3     Ready    control-plane,etcd,master   9m    v1.33.5+rke2r1    10.0.2.239
worker-1     Ready    <none>                      7m    v1.33.5+rke2r1    10.0.2.170
worker-2     Ready    <none>                      7m    v1.33.5+rke2r1    10.0.2.98
```
---
## 📚 Future Improvements
- Add monitoring stack (Prometheus + Grafana)
- Add GitLab CI/CD integration for auto-deploy
- Include Helm chart bootstrapping (ArgoCD, metrics-server)
- Migrate to dynamic Ansible role-based tagging in Terraform outputs
---
## 🧑‍💻 Author
- Jakub Jasiński
- Cloud & DevOps Engineer
- 🌐 github.com/KoJotPG