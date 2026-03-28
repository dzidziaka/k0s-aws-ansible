# Kubernetes k0s on AWS — Ansible + GitLab CI/CD

Provisions **3 EC2 instances** (1 control-plane + 2 workers) and bootstraps a production-ready Kubernetes cluster using kubeadm and Calico CNI.

## Architecture1

```
AWS Region (eu-west-1)
└── VPC  10.0.0.0/16
    └── Public Subnet  10.0.1.0/24
        ├── k8s-cluster-master   (t3.medium)  – control plane
        ├── k8s-cluster-worker1  (t3.medium)  – worker
        └── k8s-cluster-worker2  (t3.medium)  – worker
```

## File Structure

```
.
|── .gitea/workflows/k0s-gitea-deploy.yml # Gitea actions 
├── .gitlab-ci.yml                        # GitLab pipeline (5 stages)
├── .yamllint.yml                         # Linting rules
├── ansible.cfg                           # Ansible settings
├── requirements.yml                      # Collection dependencies
├── group_vars/
│   └── all.yml                           # Shared variables (versions, sizing, tags)
├── inventory/
│   └── aws_ec2.yml                       # Dynamic EC2 inventory (amazon.aws plugin)
├── playbooks/
│   ├── provision.yml                     # Create VPC + 3 EC2 instances
│   ├── k8s-install.yml                   # Install containerd + kubeadm on all nodes
│   ├── k8s-join.yml                      # Join workers to the cluster
│   ├── verify.yml                        # Health checks
│   └── destroy.yml                       # Tear down everything
└── roles/
    ├── k8s_common/                       # Applied to all nodes (kernel, swap, containerd, pkgs)
    ├── k8s_master/                       # kubeadm init, Calico CNI, kubeconfig
    └── k8s_worker/                       # kubeadm join
```

## Prerequisites

| Tool | Version |
|------|---------|
| Ansible | >= 2.14 |
| Python boto3/botocore | latest |
| AWS IAM user | EC2 + VPC full access |
| EC2 Key Pair | pre-created in target region |

## Quick Start (local)

```bash
# Install dependencies
pip install ansible boto3 botocore
ansible-galaxy collection install -r requirements.yml

# Export AWS credentials
export AWS_ACCESS_KEY_ID=AKIA...
export AWS_SECRET_ACCESS_KEY=...
export AWS_DEFAULT_REGION=eu-west-1
export AWS_KEY_PAIR_NAME=my-keypair

# Stage 1 – provision EC2
ansible-playbook playbooks/provision.yml

# Stage 2 – install Kubernetes on all nodes
ansible-playbook -i inventory/aws_ec2.yml playbooks/k8s-install.yml

# Stage 3 – join workers
ansible-playbook -i inventory/aws_ec2.yml playbooks/k8s-join.yml

# Stage 4 – verify
ansible-playbook -i inventory/aws_ec2.yml playbooks/verify.yml

# Use the cluster
export KUBECONFIG=./kubeconfig
kubectl get nodes
```

## GitLab CI/CD Setup

### Required CI/CD Variables

| Variable | Type | Notes |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | Variable (masked) | IAM key |
| `AWS_SECRET_ACCESS_KEY` | Variable (masked, protected) | IAM secret |
| `AWS_DEFAULT_REGION` | Variable | e.g. `eu-west-1` |
| `AWS_KEY_PAIR_NAME` | Variable | Pre-existing EC2 key pair name |
| `SSH_PRIVATE_KEY` | **File** (protected) | Private key matching key pair |
| `ANSIBLE_VAULT_PASSWORD` | Variable (masked, protected) | Vault decryption |

### Pipeline Stages

```
validate  →  provision  →  deploy  →  verify  →  destroy (manual)
```

- **validate** – YAML lint + Ansible syntax check (runs on MRs too)
- **provision** – creates VPC, subnet, IGW, security group, 3 EC2 instances
- **deploy** – installs containerd + Kubernetes, bootstraps master, joins workers
- **verify** – asserts all nodes Ready, system pods healthy
- **destroy** – manual trigger only; tears down all AWS resources

### Customizing

Edit `group_vars/all.yml` to change:
- `ec2_instance_type` – instance size
- `ec2_ami_id` – Ubuntu AMI per region
- `kubernetes_version` – target K8s version
- `vpc_cidr` / `subnet_cidr` – network ranges

## Destroy

```bash
# Local
ansible-playbook playbooks/destroy.yml -e auto_approve=true

# GitLab: trigger the "destroy-infrastructure" manual job in the pipeline
```
