# AWS Infrastructure Quick Deployment Script
# Run this script in PowerShell from the AWS-Infra directory

param(
    [Parameter(Mandatory=$false)]
    [string]$Phase = "all",
    
    [Parameter(Mandatory=$false)]
    [string]$BackendAppPath = "",
    
    [Parameter(Mandatory=$false)]
    [string]$FrontendAppPath = ""
)

Write-Host "=== AWS Infrastructure Deployment Script ===" -ForegroundColor Green
Write-Host "Phase: $Phase" -ForegroundColor Yellow

# Set error action preference
$ErrorActionPreference = "Stop"

function Test-Prerequisites {
    Write-Host "Checking prerequisites..." -ForegroundColor Blue
    
    # Check AWS CLI
    try {
        aws --version
        aws sts get-caller-identity
    } catch {
        Write-Error "AWS CLI not configured properly"
        exit 1
    }
    
    # Check Terraform
    try {
        terraform --version
    } catch {
        Write-Error "Terraform not found"
        exit 1
    }
    
    # Check Docker
    try {
        docker --version
    } catch {
        Write-Error "Docker not found"
        exit 1
    }
    
    # Check kubectl
    try {
        kubectl version --client
    } catch {
        Write-Error "kubectl not found"
        exit 1
    }
    
    Write-Host "Prerequisites check passed!" -ForegroundColor Green
}

function Deploy-Bootstrap {
    Write-Host "=== Phase 1: Bootstrap Infrastructure ===" -ForegroundColor Green
    
    Set-Location "terraform-bootstrap"
    
    Write-Host "Initializing Terraform..." -ForegroundColor Blue
    terraform init
    
    Write-Host "Planning bootstrap deployment..." -ForegroundColor Blue
    terraform plan
    
    Write-Host "Applying bootstrap infrastructure..." -ForegroundColor Blue
    terraform apply -auto-approve
    
    Write-Host "Verifying bootstrap..." -ForegroundColor Blue
    aws s3 ls s3://ryan-tfstate-bucket444
    aws dynamodb describe-table --table-name ryan-tf-locks444
    
    Set-Location ".."
    Write-Host "Bootstrap deployment completed!" -ForegroundColor Green
}

function Deploy-Infrastructure {
    Write-Host "=== Phase 2: Core Infrastructure ===" -ForegroundColor Green
    
    Set-Location "terraform-infra"
    
    Write-Host "Initializing Terraform..." -ForegroundColor Blue
    terraform init
    
    Write-Host "Planning infrastructure deployment..." -ForegroundColor Blue
    terraform plan
    
    Write-Host "Applying core infrastructure..." -ForegroundColor Blue
    terraform apply -auto-approve
    
    Write-Host "Configuring kubectl..." -ForegroundColor Blue
    aws eks update-kubeconfig --region us-east-1 --name ryan-cluster
    
    Write-Host "Verifying EKS connection..." -ForegroundColor Blue
    kubectl get nodes
    
    Write-Host "Getting infrastructure outputs..." -ForegroundColor Blue
    terraform output
    
    Set-Location ".."
    Write-Host "Core infrastructure deployment completed!" -ForegroundColor Green
}

function Deploy-Backend {
    Write-Host "=== Phase 3: Backend Application ===" -ForegroundColor Green
    
    if ($BackendAppPath -eq "") {
        Write-Host "Backend app path not provided. Skipping backend build..." -ForegroundColor Yellow
    } else {
        Write-Host "Building and pushing backend image..." -ForegroundColor Blue
        
        # Save current location
        $currentLocation = Get-Location
        
        Set-Location $BackendAppPath
        
        # ECR Login
        aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 098150418900.dkr.ecr.us-east-1.amazonaws.com
        
        # Build and push
        docker build -t backend-api .
        docker tag backend-api:latest 098150418900.dkr.ecr.us-east-1.amazonaws.com/backend-api:latest
        docker push 098150418900.dkr.ecr.us-east-1.amazonaws.com/backend-api:latest
        
        # Return to original location
        Set-Location $currentLocation
    }
    
    Write-Host "Deploying EKS add-ons..." -ForegroundColor Blue
    Set-Location "eks-infra"
    terraform init
    terraform apply -auto-approve
    Set-Location ".."
    
    Write-Host "Deploying Kubernetes resources..." -ForegroundColor Blue
    Set-Location "k8s"
    
    # Create namespace
    kubectl create namespace my-app --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply resources in order
    kubectl apply -f cluster-secret-store.yaml
    kubectl apply -f external-secret.yaml
    kubectl apply -f deployment.yaml
    kubectl apply -f backend-service.yaml
    kubectl apply -f backend-loadbalancer.yaml
    
    Write-Host "Waiting for pods to be ready..." -ForegroundColor Blue
    kubectl wait --for=condition=ready pod -l app=ably-backend -n my-app --timeout=300s
    
    Write-Host "Getting LoadBalancer URL..." -ForegroundColor Blue
    $lbUrl = kubectl get service ably-backend-lb -n my-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
    Write-Host "LoadBalancer URL: $lbUrl" -ForegroundColor Yellow
    
    Set-Location ".."
    Write-Host "Backend deployment completed!" -ForegroundColor Green
}

function Deploy-Frontend {
    Write-Host "=== Phase 4: Frontend Application ===" -ForegroundColor Green
    
    if ($FrontendAppPath -eq "") {
        Write-Host "Frontend app path not provided. Skipping frontend build..." -ForegroundColor Yellow
        return
    }
    
    # Save current location
    $currentLocation = Get-Location
    
    Set-Location $FrontendAppPath
    
    Write-Host "Installing dependencies..." -ForegroundColor Blue
    npm install
    
    Write-Host "Building frontend..." -ForegroundColor Blue
    npm run build
    
    Write-Host "Deploying to S3..." -ForegroundColor Blue
    aws s3 sync dist/ s3://ryan-fe-bucket444 --delete
    
    # Get CloudFront distribution ID
    Set-Location $currentLocation
    Set-Location "terraform-infra"
    $distributionId = terraform output -raw cloudfront_distribution_id 2>$null
    if ($distributionId) {
        Write-Host "Invalidating CloudFront cache..." -ForegroundColor Blue
        aws cloudfront create-invalidation --distribution-id $distributionId --paths "/*"
    }
    
    Set-Location $currentLocation
    Write-Host "Frontend deployment completed!" -ForegroundColor Green
}

function Test-Deployment {
    Write-Host "=== Phase 5: Testing Deployment ===" -ForegroundColor Green
    
    Set-Location "terraform-infra"
    
    Write-Host "Getting CloudFront URL..." -ForegroundColor Blue
    $cloudfrontUrl = terraform output -raw cloudfront_url 2>$null
    if ($cloudfrontUrl) {
        Write-Host "Frontend URL: $cloudfrontUrl" -ForegroundColor Yellow
    }
    
    Write-Host "Checking backend pods..." -ForegroundColor Blue
    kubectl get pods -n my-app
    
    Write-Host "Checking services..." -ForegroundColor Blue
    kubectl get services -n my-app
    
    Write-Host "Checking external secrets..." -ForegroundColor Blue
    kubectl get externalsecrets -n my-app
    
    Set-Location ".."
    Write-Host "Deployment testing completed!" -ForegroundColor Green
}

# Main execution
switch ($Phase.ToLower()) {
    "all" {
        Test-Prerequisites
        Deploy-Bootstrap
        Deploy-Infrastructure
        Deploy-Backend
        Deploy-Frontend
        Test-Deployment
    }
    "bootstrap" {
        Test-Prerequisites
        Deploy-Bootstrap
    }
    "infrastructure" {
        Deploy-Infrastructure
    }
    "backend" {
        Deploy-Backend
    }
    "frontend" {
        Deploy-Frontend
    }
    "test" {
        Test-Deployment
    }
    default {
        Write-Host "Invalid phase. Use: all, bootstrap, infrastructure, backend, frontend, or test" -ForegroundColor Red
        exit 1
    }
}

Write-Host "=== Deployment Script Completed! ===" -ForegroundColor Green
