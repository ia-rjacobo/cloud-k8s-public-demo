terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}


terraform {
  backend "s3" {
    bucket         = "tf-bucket-029356ec7e69"
    key            = "env/prod/terraform.tfstate"
    region         = "us-west-2"
    use_lockfile   = true  # Enables S3-managed locking
  }
}
