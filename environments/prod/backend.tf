terraform {
  backend "s3" {
    bucket         = "app-devops-michaelken30"
    key            = "prod/service/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile = true
  }
}