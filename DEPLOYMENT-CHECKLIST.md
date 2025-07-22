# Deployment Checklist

## Pre-Deployment Checklist

### Prerequisites Verification
- [ ] AWS CLI installed and configured (`aws --version`, `aws sts get-caller-identity`)
- [ ] Terraform installed (`terraform --version`)
- [ ] Docker installed and running (`docker --version`)
- [ ] kubectl installed (`kubectl version --client`)
- [ ] Git installed (`git --version`)

### AWS Permissions Check
- [ ] IAM permissions for S3, DynamoDB, VPC, EKS, ECR, CloudFront, Secrets Manager
- [ ] AWS credentials configured (access key/secret or IAM role)
- [ ] Correct AWS region set (us-east-1)

### Code Preparation
- [ ] Backend application has Dockerfile
- [ ] Frontend application builds successfully (`npm run build`)
- [ ] Environment variables configured correctly
- [ ] API endpoints configured to work with CloudFront proxy

## Deployment Execution Checklist

### Phase 1: Bootstrap Infrastructure
- [ ] Navigate to `terraform-bootstrap` directory
- [ ] Run `terraform init`
- [ ] Run `terraform plan` (review planned changes)
- [ ] Run `terraform apply -auto-approve`
- [ ] Verify S3 bucket created: `ryan-tfstate-bucket444`
- [ ] Verify DynamoDB table created: `ryan-tf-locks444`

### Phase 2: Core Infrastructure
- [ ] Navigate to `terraform-infra` directory
- [ ] Run `terraform init`
- [ ] Run `terraform plan` (review planned changes)
- [ ] Run `terraform apply -auto-approve`
- [ ] Update kubeconfig: `aws eks update-kubeconfig --region us-east-1 --name ryan-cluster`
- [ ] Verify EKS connection: `kubectl get nodes`
- [ ] Save terraform outputs (ECR URL, CloudFront URL, etc.)

### Phase 3: Backend Application
- [ ] ECR login successful
- [ ] Docker image built successfully
- [ ] Docker image pushed to ECR
- [ ] EKS add-ons deployed (`eks-infra` terraform apply)
- [ ] Namespace created: `kubectl create namespace my-app`
- [ ] External Secrets Operator configured
- [ ] Backend deployment running: `kubectl get pods -n my-app`
- [ ] Backend service accessible: `kubectl get services -n my-app`
- [ ] LoadBalancer URL obtained
- [ ] Update CloudFront configuration with LoadBalancer URL

### Phase 4: Frontend Application
- [ ] Frontend dependencies installed (`npm install`)
- [ ] Environment variables configured (CloudFront URL)
- [ ] Frontend built successfully (`npm run build`)
- [ ] Files deployed to S3: `aws s3 sync dist/ s3://ryan-fe-bucket444`
- [ ] CloudFront cache invalidated

### Phase 5: Testing and Verification
- [ ] Frontend accessible via CloudFront URL
- [ ] API calls work through CloudFront proxy (`/api/*` paths)
- [ ] Backend pods healthy and running
- [ ] External secrets synchronized
- [ ] No error logs in backend pods
- [ ] Application functionality working end-to-end

## Post-Deployment Checklist

### Documentation
- [ ] Record all URLs (CloudFront, LoadBalancer)
- [ ] Document any configuration changes made
- [ ] Update environment-specific documentation
- [ ] Save deployment outputs and configurations

### Security Review
- [ ] Secrets properly managed through AWS Secrets Manager
- [ ] No hardcoded credentials in code
- [ ] HTTPS enforced for all communications
- [ ] Security groups properly configured

### Monitoring Setup
- [ ] CloudWatch logs configured
- [ ] Pod logs accessible via kubectl
- [ ] CloudFront access logs enabled (if needed)
- [ ] Application health checks working

### Backup and Recovery
- [ ] Terraform state backed up in S3
- [ ] Application code in version control
- [ ] Infrastructure configuration documented
- [ ] Rollback procedure documented

## Troubleshooting Checklist

### Common Issues
- [ ] ECR authentication issues → Re-run ECR login command
- [ ] EKS connection issues → Update kubeconfig
- [ ] Pod startup issues → Check logs with `kubectl logs`
- [ ] External secrets not syncing → Check secret store configuration
- [ ] Frontend not loading → Check S3 deployment and CloudFront cache
- [ ] API calls failing → Check CloudFront origin configuration

### Commands for Troubleshooting
- [ ] `kubectl describe pod POD_NAME -n my-app`
- [ ] `kubectl logs -n my-app deployment/ably-backend`
- [ ] `kubectl get externalsecrets -n my-app`
- [ ] `kubectl get events -n my-app`
- [ ] `terraform output` (for infrastructure URLs)

## Environment-Specific Notes

### Development Environment
- [ ] Use development-specific values in terraform.tfvars
- [ ] Consider smaller instance types for cost optimization
- [ ] Enable debug logging if needed

### Production Environment
- [ ] Review all security configurations
- [ ] Enable monitoring and alerting
- [ ] Configure auto-scaling
- [ ] Set up backup procedures
- [ ] Document disaster recovery procedures

## Success Criteria

### Infrastructure
- ✅ All Terraform resources created successfully
- ✅ EKS cluster accessible and healthy
- ✅ ECR repository contains backend image
- ✅ S3 bucket contains frontend files
- ✅ CloudFront distribution active and accessible

### Application
- ✅ Backend pods running and healthy
- ✅ Frontend accessible via CloudFront
- ✅ API endpoints responding correctly
- ✅ Database/external service connections working
- ✅ Authentication and authorization working

### Security
- ✅ All communications over HTTPS
- ✅ Secrets managed properly
- ✅ No exposed credentials or sensitive data
- ✅ Security groups configured correctly

This checklist ensures comprehensive deployment and verification of your AWS infrastructure and applications.
