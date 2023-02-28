output "cluster-name" {
  value = aws_eks_cluster.python-challenge-cluster.name
}

output "cluster-endpoint" {
  value = aws_eks_cluster.python-challenge-cluster.endpoint
}

output "cluster-ca-certificate" {
  value = aws_eks_cluster.python-challenge-cluster.certificate_authority[0].data
}