# VPC
resource "aws_vpc" "python-challenge-vpc" {
  cidr_block = var.vpc_cidr

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name                                           = "python-challenge-vpc",
    "kubernetes.io/cluster/python-challenge-cluster" = "shared"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count = var.availability_zones_count

  vpc_id            = aws_vpc.python-challenge-vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name                                           = "python-challenge-public-sg"
    "kubernetes.io/cluster/python-challenge-cluster" = "shared"
    "kubernetes.io/role/elb"                       = 1
  }

  map_public_ip_on_launch = true
}

# Private Subnets
resource "aws_subnet" "private" {
  count = var.availability_zones_count

  vpc_id            = aws_vpc.python-challenge-vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, count.index + var.availability_zones_count)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name                                           = "python-challenge-private-sg"
    "kubernetes.io/cluster/python-challenge-cluster" = "shared"
    "kubernetes.io/role/internal-elb"              = 1
  }
}

# Internet Gateway
resource "aws_internet_gateway" "python-challenge-igw" {
  vpc_id = aws_vpc.python-challenge-vpc.id

  tags = {
    "Name" = "python-challenge-igw"
  }

  depends_on = [aws_vpc.python-challenge-vpc]
}

# Route Table(s)
# Route the public subnet traffic through the IGW
resource "aws_route_table" "python-challenge-rt" {
  vpc_id = aws_vpc.python-challenge-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.python-challenge-igw.id
  }

  tags = {
    Name = "python-challenge-rt"
  }
}

# Route table and subnet associations
resource "aws_route_table_association" "python-challenge-rta" {
  count = var.availability_zones_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.python-challenge-rt.id
}

# NAT Elastic IP
resource "aws_eip" "python-challenge-ngw-eip" {
  vpc = true

  tags = {
    Name = "python-challenge-ngw-eip"
  }
}

# NAT Gateway
resource "aws_nat_gateway" "python-challenge-ngw" {
  allocation_id = aws_eip.python-challenge-ngw-eip.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "python-challenge-ngw"
  }
}

# Add route to route table
resource "aws_route" "python-challenge-route" {
  route_table_id         = aws_vpc.python-challenge-vpc.default_route_table_id
  nat_gateway_id         = aws_nat_gateway.python-challenge-ngw.id
  destination_cidr_block = "0.0.0.0/0"
}

# Security group for public subnet
resource "aws_security_group" "python-challenge-public-sg" {
  name   = "python-challenge-public-sg"
  vpc_id = aws_vpc.python-challenge-vpc.id

  tags = {
    Name = "python-challenge-public-sg"
  }
}

# Security group traffic rules
resource "aws_security_group_rule" "sg-ingress-public-443" {
  security_group_id = aws_security_group.python-challenge-public-sg.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "sg-ingress-public-80" {
  security_group_id = aws_security_group.python-challenge-public-sg.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "sg-egress-public" {
  security_group_id = aws_security_group.python-challenge-public-sg.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# Security group for data plane
resource "aws_security_group" "python-challenge-dataplane-sg" {
  name   = "python-challenge-dataplane-sg"
  vpc_id = aws_vpc.python-challenge-vpc.id

  tags = {
    Name = "python-challenge-dataplane-sg"
  }
}

# Security group traffic rules
resource "aws_security_group_rule" "nodes" {
  description       = "Allow nodes to communicate with each other"
  security_group_id = aws_security_group.python-challenge-dataplane-sg.id
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = flatten([cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 0), cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 1), cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 2), cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 3)])
}

resource "aws_security_group_rule" "nodes_inbound" {
  description       = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  security_group_id = aws_security_group.python-challenge-dataplane-sg.id
  type              = "ingress"
  from_port         = 1025
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = flatten([cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 2), cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 3)])
}

resource "aws_security_group_rule" "node_outbound" {
  security_group_id = aws_security_group.python-challenge-dataplane-sg.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# Security group for control plane
resource "aws_security_group" "python-challenge-controlplane-sg" {
  name   = "python-challenge-controlplane-sg"
  vpc_id = aws_vpc.python-challenge-vpc.id

  tags = {
    Name = "python-challenge-controlplane-sg"
  }
}

# Security group traffic rules
resource "aws_security_group_rule" "control_plane_inbound" {
  security_group_id = aws_security_group.python-challenge-controlplane-sg.id
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = flatten([cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 0), cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 1), cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 2), cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 3)])
}

resource "aws_security_group_rule" "control_plane_outbound" {
  security_group_id = aws_security_group.python-challenge-controlplane-sg.id
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}