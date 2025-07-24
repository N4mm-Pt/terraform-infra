module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.29"
  
  vpc_id     = var.vpc_id
  subnet_ids = var.public_subnet_ids
  
  # Allow cluster endpoint access from anywhere (for initial setup)
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  enable_cluster_creator_admin_permissions = true
  # Enable cluster logging
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.medium"]
      desired_size   = 2
      max_size       = 3
      min_size       = 1
      
      # Use private subnets for nodes (if available)
      subnet_ids = var.private_subnet_ids != null ? var.private_subnet_ids : var.public_subnet_ids
    }
  }
  tags = {
    Environment = "prod"
  }
}
