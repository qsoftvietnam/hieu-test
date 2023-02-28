# EKS Cluster
resource "aws_eks_cluster" "python-challenge-cluster" {
  name     = "python-challenge-cluster"
  role_arn = aws_iam_role.python-challenge-cluster-role.arn
  version  = "1.25"

  vpc_config {
    subnet_ids              = flatten([aws_subnet.public[*].id, aws_subnet.private[*].id])
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags
  )

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy
  ]
}


# EKS Cluster IAM Role
resource "aws_iam_role" "python-challenge-cluster-role" {
  name = "python-challenge-cluster-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.python-challenge-cluster-role.name
}


# EKS Cluster Security Group
resource "aws_security_group" "python-challenge-cluster-sg" {
  name        = "python-challenge-cluster-sg"
  description = "Cluster communication with worker nodes"
  vpc_id      = aws_vpc.python-challenge-vpc.id

  tags = {
    Name = "python-challenge-cluster-sg"
  }
}

resource "aws_security_group_rule" "python-challenge-cluster-sg-inbound-rule" {
  description              = "Allow worker nodes to communicate with the cluster API Server"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.python-challenge-cluster-sg.id
  source_security_group_id = aws_security_group.python-challenge-nodegroup-sg.id
  type                     = "ingress"
}

resource "aws_security_group_rule" "python-challenge-cluster-sg-outbound-rule" {
  description              = "Allow cluster API Server to communicate with the worker nodes"
  from_port                = 1024
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.python-challenge-cluster-sg.id
  source_security_group_id = aws_security_group.python-challenge-nodegroup-sg.id
  type                     = "egress"
}
