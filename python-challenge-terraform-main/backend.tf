terraform {
  backend "s3" {
    bucket         = "python-challenge-terraform"
    key            = "terraform.tfstate"
    region         = "ap-southeast-1"
    encrypt        = true
  }
}