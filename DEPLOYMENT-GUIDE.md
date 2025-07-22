# AWS Infrastructure Deployment Guide

## Overview
This guide provides step-by-step instructions to deploy your complete AWS infrastructure including:
- Terraform Bootstrap (S3 + DynamoDB for remote state)
- Core Infrastructure (VPC, EKS, ECR, S3, CloudFront, Secrets Manager)
- Backend Application to EKS
- Frontend Application to S3 + CloudFront

## Prerequisites

### Required Tools
- AWS CLI v2 (configured with appropriate permissions)
- Terraform v1.0+
- Docker
- kubectl
- git

### AWS Permissions Required
Your AWS user/role needs permissions for:
- S3, DynamoDB, IAM, VPC, EKS, ECR, CloudFront, Secrets Manager, EC2

### Verify Prerequisites
```powershell
# Check AWS CLI
aws --version
aws sts get-caller-identity

# Check Terraform
terraform --version

# Check Docker
docker --version

# Check kubectl
kubectl version --client
```

## Phase 1: Bootstrap Infrastructure

### Step 1: Deploy Bootstrap Infrastructure
The bootstrap creates the S3 bucket and DynamoDB table for Terraform remote state.

```powershell
# Navigate to bootstrap directory
cd d:\AblyPocApp\AWS-Infra\terraform-bootstrap

# Review and update terraform.tfvars if needed
# Current values:
# bucket_name = "ryan-tfstate-bucket444"
# environment = "prod"  
# lock_table_name = "ryan-tf-locks444"

# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the bootstrap infrastructure
terraform apply -auto-approve
```

**Expected Output:**
- S3 bucket: `ryan-tfstate-bucket444`
- DynamoDB table: `ryan-tf-locks444`

### Step 2: Verify Bootstrap
```powershell
# Verify S3 bucket
aws s3 ls s3://ryan-tfstate-bucket444

# Verify DynamoDB table
aws dynamodb describe-table --table-name ryan-tf-locks444
```

## Phase 2: Core Infrastructure Deployment

### Step 3: Deploy Core Infrastructure
```powershell
# Navigate to main infrastructure directory
cd d:\AblyPocApp\AWS-Infra\terraform-infra

# Review and update terraform.tfvars if needed
# Current values:
# aws_region = "us-east-1"
# cluster_name = "ryan-cluster"
# bucket_name = "ryan-fe-bucket444"
# secret_name = "ably-api-key"
# secret_value = { ... }

# Initialize Terraform (this will configure remote state)
terraform init

# Plan the deployment
terraform plan

# Apply the infrastructure
terraform apply -auto-approve
```

**Expected Resources Created:**
- VPC with public/private subnets
- EKS Cluster: `ryan-cluster`
- ECR Repository: `backend-api`
- S3 Bucket: `ryan-fe-bucket444`
- CloudFront Distribution
- Secrets Manager secret: `ably-api-key`

### Step 4: Configure kubectl
```powershell
# Update kubeconfig to connect to EKS cluster
aws eks update-kubeconfig --region us-east-1 --name ryan-cluster

# Verify connection
kubectl get nodes
kubectl get namespaces
```

### Step 5: Get Infrastructure Outputs
```powershell
# Get important outputs
terraform output

# Save these values for later steps:
# - ecr_repo_url
# - eks_cluster_endpoint  
# - cloudfront_url
```

## Phase 3: Backend Application Deployment

### Step 6: Build and Push Backend Image
```powershell
# Navigate to your backend application directory
cd d:\AblyPocApp\[YOUR_BACKEND_APP_DIRECTORY]

# Get ECR login token
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin[YOUR_ECR_URL]

# Build the Docker image
docker build -t backend-api .

# Tag the image for ECR
docker tag backend-api:latest[YOUR_ECR_URL]:latest

# Push to ECR
docker push [YOUR_ECR_URL]:latest
```

### Step 7: Deploy External Secrets Operator
```powershell
# Navigate to EKS infrastructure directory
cd d:\AblyPocApp\AWS-Infra\eks-infra

# Initialize and apply EKS add-ons
terraform init
terraform apply -auto-approve
```

### Step 8: Deploy Kubernetes Resources
```powershell
# Navigate to k8s directory
cd d:\AblyPocApp\AWS-Infra\k8s

# Create namespace
kubectl create namespace my-app

# Apply Kubernetes resources in order
kubectl apply -f cluster-secret-store.yaml
kubectl apply -f external-secret.yaml
kubectl apply -f deployment.yaml
kubectl apply -f backend-service.yaml
kubectl apply -f backend-loadbalancer.yaml

# Optional: Apply other services
kubectl apply -f ably-backend.yaml
kubectl apply -f nginx-proxy.yaml
kubectl apply -f backend-ingress.yaml
```

### Step 9: Verify Backend Deployment
```powershell
# Check if pods are running
kubectl get pods -n my-app

# Check services
kubectl get services -n my-app

# Check external secrets
kubectl get externalsecrets -n my-app
kubectl get secrets -n my-app

# Get LoadBalancer URL
kubectl get service ably-backend-lb -n my-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### Step 10: Update CloudFront with LoadBalancer URL
Once you have the LoadBalancer URL, update the CloudFront configuration:

```powershell
# Navigate back to terraform-infra
cd d:\AblyPocApp\AWS-Infra\terraform-infra

# Update main.tf with the actual LoadBalancer URL
# Replace the api_domain_name in the frontend module
```

Update the `main.tf` file:
```terraform
module "frontend" {
  source          = "./modules/s3-cloudfront"
  bucket_name     = var.bucket_name
  api_domain_name = "YOUR_ACTUAL_LOADBALANCER_URL"  # Replace with actual LB URL
}
```

```powershell
# Apply the updated configuration
terraform apply -auto-approve
```

## Phase 4: Frontend Deployment

### Step 11: Build and Deploy Frontend
```powershell
# Navigate to your frontend application directory
cd d:\AblyPocApp\[YOUR_FRONTEND_APP_DIRECTORY]

# Install dependencies (if not already done)
npm install

# Update environment configuration
# Create or update .env file with CloudFront URL
echo "VITE_API_BASE_URL=https://YOUR_CLOUDFRONT_DOMAIN/api" > .env

# Build the application
npm run build

# Deploy to S3
aws s3 sync dist/ s3://ryan-fe-bucket444 --delete

# Invalidate CloudFront cache
aws cloudfront create-invalidation --distribution-id YOUR_DISTRIBUTION_ID --paths "/*"
```

## Phase 5: Verification and Testing

### Step 12: Test the Complete Application
```powershell
# Get CloudFront URL
terraform output cloudfront_url

# Test frontend access
# Open browser to CloudFront URL

# Test API through CloudFront
curl https://YOUR_CLOUDFRONT_DOMAIN/api/health

# Test backend directly (if needed)
kubectl port-forward -n my-app service/ably-backend 8080:80
curl http://localhost:8080/health
```

### Step 13: Monitor and Troubleshoot
```powershell
# Check pod logs
kubectl logs -n my-app deployment/ably-backend

# Check service endpoints
kubectl get endpoints -n my-app

# Check external secrets status
kubectl describe externalsecret -n my-app

# Check CloudFront distribution status
aws cloudfront get-distribution --id YOUR_DISTRIBUTION_ID
```

## Cleanup Instructions

### Complete Infrastructure Cleanup
```powershell
# Delete Kubernetes resources
kubectl delete namespace my-app

# Destroy EKS add-ons
cd d:\AblyPocApp\AWS-Infra\eks-infra
terraform destroy -auto-approve

# Destroy main infrastructure
cd d:\AblyPocApp\AWS-Infra\terraform-infra
terraform destroy -auto-approve

# Destroy bootstrap (if desired)
cd d:\AblyPocApp\AWS-Infra\terraform-bootstrap
terraform destroy -auto-approve
```

## Troubleshooting Common Issues

### ECR Push Issues
```powershell
# Re-authenticate with ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 098150418900.dkr.ecr.us-east-1.amazonaws.com
```

### EKS Connection Issues
```powershell
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name ryan-cluster --force

# Check AWS credentials
aws sts get-caller-identity
```

### Pod Issues
```powershell
# Check pod status
kubectl describe pod -n my-app POD_NAME

# Check logs
kubectl logs -n my-app POD_NAME

# Check secrets
kubectl get secret -n my-app ably-api-secret -o yaml
```

### CloudFront Issues
```powershell
# Check distribution status
aws cloudfront get-distribution --id YOUR_DISTRIBUTION_ID

# Invalidate cache
aws cloudfront create-invalidation --distribution-id YOUR_DISTRIBUTION_ID --paths "/*"
```

## Important Notes

1. **Security**: The Ably API key is stored in AWS Secrets Manager and accessed via External Secrets Operator
2. **Scaling**: The backend deployment is configured for 2 replicas
3. **Monitoring**: Consider adding CloudWatch logging and monitoring
4. **SSL/TLS**: CloudFront provides SSL termination for the frontend
5. **Backup**: Terraform state is stored in S3 with DynamoDB locking

## Next Steps for Production

1. **CI/CD Pipeline**: Set up automated deployments
2. **Monitoring**: Add CloudWatch, Prometheus, or similar
3. **Security**: Implement WAF, security groups refinement
4. **Performance**: Configure auto-scaling
5. **Backup**: Set up automated backups
6. **DNS**: Configure Route 53 for custom domain

## Configuration Files Reference

### Key Files and Their Purpose:
- `terraform-bootstrap/`: Creates S3 and DynamoDB for Terraform state
- `terraform-infra/`: Main infrastructure (VPC, EKS, ECR, S3, CloudFront)
- `eks-infra/`: EKS add-ons (External Secrets Operator)
- `k8s/`: Kubernetes manifests for application deployment

### Environment-Specific Values:
All environment-specific values are in the respective `terraform.tfvars` files. Update these for different environments (dev, staging, prod).
