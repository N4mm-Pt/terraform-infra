terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}


module "vpc" {
  source = "./modules/vpc"
}

module "eks" {
  source             = "./modules/eks-cluster"
  cluster_name       = var.cluster_name
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids
}

module "ecr" {
  source = "./modules/ecr"
}

module "frontend" {
  source          = "./modules/s3-cloudfront"
  bucket_name     = var.bucket_name
  api_domain_name = "aa4f78ca926874866a720de6b21d908f-1005770988.us-east-1.elb.amazonaws.com"
}

module "secrets-manager" {
  source       = "./modules/secrets-manager"
  secret_name  = var.secret_name
  secret_value = var.secret_value
}



