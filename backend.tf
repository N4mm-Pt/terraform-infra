terraform {
  backend "s3" {
    bucket = "ryan-tfstate-bucket444"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "ryan-tf-locks444"
  }
}