resource "aws_ecr_repository" "python-challenge-repo" {
  name                 = "python-challenge-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
