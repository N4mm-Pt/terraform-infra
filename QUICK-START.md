# Quick Start Deployment Guide

## Option 1: Automated Deployment (Recommended)

### Prerequisites
1. Ensure AWS CLI is configured with proper credentials
2. Have Docker, Terraform, and kubectl installed

### Execute Automated Deployment
```powershell
# Navigate to the AWS-Infra directory
cd d:\AblyPocApp\AWS-Infra

# Run the complete deployment (all phases)
.\terraform-infra\deploy.ps1 -Phase "all" -BackendAppPath "PATH_TO_YOUR_BACKEND_APP" -FrontendAppPath "PATH_TO_YOUR_FRONTEND_APP"

# Or run individual phases:
.\terraform-infra\deploy.ps1 -Phase "bootstrap"
.\terraform-infra\deploy.ps1 -Phase "infrastructure"
.\terraform-infra\deploy.ps1 -Phase "backend" -BackendAppPath "PATH_TO_YOUR_BACKEND_APP"
.\terraform-infra\deploy.ps1 -Phase "frontend" -FrontendAppPath "PATH_TO_YOUR_FRONTEND_APP"
.\terraform-infra\deploy.ps1 -Phase "test"
```

## Option 2: Manual Step-by-Step Deployment

### Phase 1: Bootstrap (Remote State)
```powershell
cd d:\AblyPocApp\AWS-Infra\terraform-bootstrap
terraform init
terraform apply -auto-approve
```

### Phase 2: Core Infrastructure
```powershell
cd d:\AblyPocApp\AWS-Infra\terraform-infra
terraform init
terraform apply -auto-approve
aws eks update-kubeconfig --region us-east-1 --name ryan-cluster
```

### Phase 3: Backend Deployment
```powershell
# Build and push Docker image (replace with your backend app path)
cd YOUR_BACKEND_APP_PATH
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 098150418900.dkr.ecr.us-east-1.amazonaws.com
docker build -t backend-api .
docker tag backend-api:latest 098150418900.dkr.ecr.us-east-1.amazonaws.com/backend-api:latest
docker push 098150418900.dkr.ecr.us-east-1.amazonaws.com/backend-api:latest

# Deploy EKS add-ons
cd d:\AblyPocApp\AWS-Infra\eks-infra
terraform init
terraform apply -auto-approve

# Deploy Kubernetes resources
cd d:\AblyPocApp\AWS-Infra\k8s
kubectl create namespace my-app
kubectl apply -f cluster-secret-store.yaml
kubectl apply -f external-secret.yaml
kubectl apply -f deployment.yaml
kubectl apply -f backend-service.yaml
kubectl apply -f backend-loadbalancer.yaml
```

### Phase 4: Frontend Deployment
```powershell
# Build and deploy frontend (replace with your frontend app path)
cd YOUR_FRONTEND_APP_PATH
npm install
npm run build
aws s3 sync dist/ s3://ryan-fe-bucket444 --delete

# Get CloudFront distribution ID and invalidate cache
cd d:\AblyPocApp\AWS-Infra\terraform-infra
terraform output cloudfront_distribution_id
aws cloudfront create-invalidation --distribution-id YOUR_DISTRIBUTION_ID --paths "/*"
```

### Phase 5: Verify Deployment
```powershell
cd d:\AblyPocApp\AWS-Infra\terraform-infra
terraform output cloudfront_url

kubectl get pods -n my-app
kubectl get services -n my-app
```

## Important URLs After Deployment

After successful deployment, you'll have:
1. **Frontend**: Available at CloudFront URL (get from `terraform output`)
2. **Backend**: Available through LoadBalancer (get from `kubectl get services`)
3. **API through CloudFront**: `https://YOUR_CLOUDFRONT_DOMAIN/api/*`

## Quick Verification Commands

```powershell
# Check infrastructure
terraform output

# Check Kubernetes
kubectl get all -n my-app

# Check secrets
kubectl get externalsecrets -n my-app
kubectl get secrets -n my-app

# Check logs if needed
kubectl logs -n my-app deployment/ably-backend
```

## Cleanup
```powershell
# Quick cleanup (destroys everything)
kubectl delete namespace my-app
cd d:\AblyPocApp\AWS-Infra\eks-infra && terraform destroy -auto-approve
cd d:\AblyPocApp\AWS-Infra\terraform-infra && terraform destroy -auto-approve
cd d:\AblyPocApp\AWS-Infra\terraform-bootstrap && terraform destroy -auto-approve
```
