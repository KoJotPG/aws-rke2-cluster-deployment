############################################
# General Configuration
############################################

variable "project_name" {
  description = "Base name for tagging and naming AWS resources."
  default     = "kubernetes-cluster"
}

variable "region" {
  description = "The AWS region where resources will be created."
  default     = "eu-central-1"
}

variable "ami_id" {
  description = "AMI ID used for EC2 instances."
  default     = "ami-0a116fa7c861dd5f9"
}

############################################
# Cluster Configuration
############################################

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
    "haproxy"  = { role = "haproxy" },
  }
}

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

variable "disk_sizes" {
  description = "Root volume sizes (GB) for each node role."
  type = object({
    master  = number
    worker  = number
    haproxy = number
  })
  default = {
    master  = 100
    worker  = 50
    haproxy = 30
  }
}

############################################
# Network Configuration
############################################

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet (for haproxy)."
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet (for masters and workers)."
  default     = "10.0.2.0/24"
}

variable "availability_zone" {
  description = "AWS availability zone to deploy the instances."
  default     = "eu-central-1a"
}

variable "ssh_allowed_cidr" {
  description = "CIDR range allowed to access SSH (e.g., your public IP)."
  default     = "0.0.0.0/0"
}

############################################
# Tagging
############################################

variable "common_tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default = {
    Project     = "Kubernetes-Cluster"
    Environment = "Demo"
    Owner       = "YourName"
  }
}

