resource "aws_ecr_repository" "backend" {
  name = "backend-api"

  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

output "repository_url" {
  value = aws_ecr_repository.backend.repository_url
}
