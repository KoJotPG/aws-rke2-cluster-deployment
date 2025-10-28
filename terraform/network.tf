############################################
# VPC & Network Configuration
############################################

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    var.common_tags,
    { Name = "${var.project_name}-vpc" }
  )
}

############################################
# Subnets
############################################

# Public Subnet - for haproxy / bastion
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = var.availability_zone

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-public-subnet"
      Tier = "public"
    }
  )
}

# Private Subnet - for masters & workers
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.availability_zone

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-private-subnet"
      Tier = "private"
    }
  )
}

############################################
# Internet Gateway & Public Routing
############################################

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    { Name = "${var.project_name}-igw" }
  )
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = merge(
    var.common_tags,
    { Name = "${var.project_name}-public-rt" }
  )
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

############################################
# NAT Gateway for Private Subnet
############################################

# Allocate Elastic IP for NAT
resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.gw]

  tags = merge(
    var.common_tags,
    { Name = "${var.project_name}-nat-eip" }
  )
}

# Create NAT Gateway in Public Subnet
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  depends_on    = [aws_internet_gateway.gw]

  tags = merge(
    var.common_tags,
    { Name = "${var.project_name}-nat" }
  )
}

# Private Route Table (use NAT for outbound)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = merge(
    var.common_tags,
    { Name = "${var.project_name}-private-rt" }
  )
}

# Associate Private Subnet with Private Route Table
resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

############################################
# Security Groups
############################################

# Allow K8s API + RKE2 + SSH + HTTP(S) for haproxy (public)
resource "aws_security_group" "haproxy_sg" {
  vpc_id = aws_vpc.main.id
  name   = "${var.project_name}-haproxy-sg"

  ingress {
    description = "K8s API via HAProxy"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "RKE2 supervisor via HAProxy"
    from_port   = 9345
    to_port     = 9345
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  ingress {
    description = "HTTP access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    { Name = "${var.project_name}-haproxy-sg" }
  )
}

# Internal communication for cluster nodes (private)
resource "aws_security_group" "cluster_sg" {
  vpc_id = aws_vpc.main.id
  name   = "${var.project_name}-cluster-sg"

  ingress {
    description = "Allow all internal traffic within VPC"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.common_tags,
    { Name = "${var.project_name}-cluster-sg" }
  )
}

