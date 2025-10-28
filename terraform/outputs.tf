############################################
# Network Outputs
############################################

output "vpc_id" {
  description = "ID of the created VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID of the public subnet (used by haproxy)."
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "ID of the private subnet (used by masters and workers)."
  value       = aws_subnet.private.id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway attached to the VPC."
  value       = aws_internet_gateway.gw.id
}

############################################
# Security Groups Outputs
############################################

output "haproxy_security_group_id" {
  description = "ID of the security group used by haproxy."
  value       = aws_security_group.haproxy_sg.id
}

output "cluster_security_group_id" {
  description = "ID of the internal cluster security group."
  value       = aws_security_group.cluster_sg.id
}

############################################
# Instance Outputs
############################################

output "instance_public_ips" {
  description = "Public IPs of instances that have one assigned (e.g., haproxy)."
  value       = { for name, inst in aws_instance.nodes : name => inst.public_ip if inst.public_ip != "" }
}

output "instance_private_ips" {
  description = "Private IPs of all cluster nodes."
  value       = { for name, inst in aws_instance.nodes : name => inst.private_ip }
}

output "haproxy_public_ip" {
  description = "Public IP of the haproxy node."
  value       = lookup({ for name, inst in aws_instance.nodes : name => inst.public_ip if inst.public_ip != "" }, "haproxy", null)
}

############################################
# Tagging and Metadata
############################################

output "project_tags" {
  description = "Common tags applied to all AWS resources."
  value       = var.common_tags
}

