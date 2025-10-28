############################################
# Provider Configuration
############################################
provider "aws" {
  region = var.region
}

############################################
# SSH Key Pair Creation
############################################

# Generate a new SSH key pair locally
resource "tls_private_key" "generated" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Register the public key in AWS
resource "aws_key_pair" "generated" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.generated.public_key_openssh

  tags = merge(
    var.common_tags,
    { Name = "${var.project_name}-key" }
  )
}

# Save the private key locally (useful for testing / SSH access)
resource "local_file" "private_key_pem" {
  content          = tls_private_key.generated.private_key_pem
  filename         = "${path.module}/${var.project_name}-key.pem"
  file_permission  = "0600"
}

############################################
# EC2 Instance Configuration
############################################
resource "aws_instance" "nodes" {
  for_each = var.cluster_nodes

  ami           = var.ami_id
  instance_type = lookup(var.instance_types, each.value.role, "t3.small")
  key_name      = aws_key_pair.generated.key_name

  subnet_id = each.value.role == "haproxy" ? aws_subnet.public.id : aws_subnet.private.id

  vpc_security_group_ids = [
    each.value.role == "haproxy"
      ? aws_security_group.haproxy_sg.id
      : aws_security_group.cluster_sg.id
  ]

  associate_public_ip_address = each.value.role == "haproxy" ? true : false

  root_block_device {
    volume_size = lookup(var.disk_sizes, each.value.role, 50)
    volume_type = "standard"
  }

  tags = merge(
    var.common_tags,
    {
      Name    = each.key
      Role    = each.value.role
      Project = var.project_name
    }
  )
}

############################################
# Generate Ansible inventory automatically
############################################

locals {
  haproxy_public_ip  = try(aws_instance.nodes["haproxy"].public_ip,  "")
  haproxy_private_ip = try(aws_instance.nodes["haproxy"].private_ip, "")

  masters_block = join("\n", [
    for name, inst in aws_instance.nodes :
    format(
      "%s ansible_host=%s ansible_user=ubuntu ansible_ssh_private_key_file=../terraform/kubernetes-cluster-key.pem",
      name,
      inst.private_ip
    )
    if var.cluster_nodes[name].role == "master"
  ])

  workers_block = join("\n", [
    for name, inst in aws_instance.nodes :
    format(
      "%s ansible_host=%s ansible_user=ubuntu ansible_ssh_private_key_file=../terraform/kubernetes-cluster-key.pem",
      name,
      inst.private_ip
    )
    if var.cluster_nodes[name].role == "worker"
  ])

  ansible_inventory = <<EOT
[haproxy]
haproxy-1 ansible_host=${local.haproxy_public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=../terraform/kubernetes-cluster-key.pem private_ip=${local.haproxy_private_ip}

[master]
${local.masters_block}

[worker]
${local.workers_block}
EOT
}

resource "local_file" "ansible_inventory" {
  content    = trimspace(local.ansible_inventory)
  filename   = "../ansible/inventory/inventory.ini"
  depends_on = [aws_instance.nodes]
}
