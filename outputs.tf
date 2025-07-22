output "ecr_repo_url" {
  value = module.ecr.repository_url
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cloudfront_url" {
  value = module.frontend.cloudfront_url
}
