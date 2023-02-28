# EKS Node Groups
resource "aws_eks_node_group" "python-challenge-nodegroup" {
  cluster_name    = aws_eks_cluster.python-challenge-cluster.name
  node_group_name = "python-challenge-nodegroup"
  node_role_arn   = aws_iam_role.python-challenge-node-role.arn
  subnet_ids      = aws_subnet.private[*].id

  scaling_config {
    desired_size = 2
    max_size     = 5
    min_size     = 1
  }

  ami_type       = "AL2_x86_64" # AL2_x86_64, AL2_x86_64_GPU, AL2_ARM_64, CUSTOM
  capacity_type  = "ON_DEMAND"  # ON_DEMAND, SPOT
  disk_size      = 20
  instance_types = ["t3.micro"]

  tags = merge(
    var.tags
  )

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
  ]
}


# EKS Node IAM Role
resource "aws_iam_role" "python-challenge-node-role" {
  name = "python-challenge-node-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.python-challenge-node-role.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.python-challenge-node-role.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.python-challenge-node-role.name
}


# EKS Node Security Group
resource "aws_security_group" "python-challenge-nodegroup-sg" {
  name        = "python-challenge-nodegroup-sg"
  description = "Security group for all nodes in the cluster"
  vpc_id      = aws_vpc.python-challenge-vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name                                             = "python-challenge-nodegroup-sg"
    "kubernetes.io/cluster/python-challenge-cluster" = "owned"
  }
}

resource "aws_security_group_rule" "python-challenge-nodegroup-internal-rule" {
  description              = "Allow nodes to communicate with each other"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  security_group_id        = aws_security_group.python-challenge-nodegroup-sg.id
  source_security_group_id = aws_security_group.python-challenge-nodegroup-sg.id
  type                     = "ingress"
}

resource "aws_security_group_rule" "python-challenge-nodegroup-inbound-rule" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.python-challenge-nodegroup-sg.id
  source_security_group_id = aws_security_group.python-challenge-cluster-sg.id
  type                     = "ingress"
}
