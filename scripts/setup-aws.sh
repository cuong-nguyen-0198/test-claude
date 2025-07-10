#!/bin/bash

# AWS Infrastructure Setup Script for Laravel ECS Deployment

set -e

# Configuration
AWS_REGION="us-east-1"
PROJECT_NAME="laravel-app"
ECR_REPOSITORY="laravel-app"
ECS_CLUSTER="laravel-cluster"
ECS_SERVICE="laravel-service"
VPC_CIDR="10.0.0.0/16"
SUBNET_CIDR_1="10.0.1.0/24"
SUBNET_CIDR_2="10.0.2.0/24"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# Create ECR repository
create_ecr_repository() {
    log "Creating ECR repository..."
    
    if aws ecr describe-repositories --repository-names $ECR_REPOSITORY --region $AWS_REGION &> /dev/null; then
        warn "ECR repository $ECR_REPOSITORY already exists"
    else
        aws ecr create-repository \
            --repository-name $ECR_REPOSITORY \
            --region $AWS_REGION
        log "ECR repository created: $ECR_REPOSITORY"
    fi
}

# Create VPC and networking
create_vpc() {
    log "Creating VPC and networking components..."
    
    # Create VPC
    local vpc_id=$(aws ec2 create-vpc \
        --cidr-block $VPC_CIDR \
        --query 'Vpc.VpcId' \
        --output text \
        --region $AWS_REGION)
    
    aws ec2 create-tags \
        --resources $vpc_id \
        --tags Key=Name,Value=$PROJECT_NAME-vpc \
        --region $AWS_REGION
    
    log "VPC created: $vpc_id"
    
    # Create Internet Gateway
    local igw_id=$(aws ec2 create-internet-gateway \
        --query 'InternetGateway.InternetGatewayId' \
        --output text \
        --region $AWS_REGION)
    
    aws ec2 attach-internet-gateway \
        --internet-gateway-id $igw_id \
        --vpc-id $vpc_id \
        --region $AWS_REGION
    
    log "Internet Gateway created and attached: $igw_id"
    
    # Create subnets
    local subnet_1_id=$(aws ec2 create-subnet \
        --vpc-id $vpc_id \
        --cidr-block $SUBNET_CIDR_1 \
        --availability-zone ${AWS_REGION}a \
        --query 'Subnet.SubnetId' \
        --output text \
        --region $AWS_REGION)
    
    local subnet_2_id=$(aws ec2 create-subnet \
        --vpc-id $vpc_id \
        --cidr-block $SUBNET_CIDR_2 \
        --availability-zone ${AWS_REGION}b \
        --query 'Subnet.SubnetId' \
        --output text \
        --region $AWS_REGION)
    
    aws ec2 create-tags \
        --resources $subnet_1_id $subnet_2_id \
        --tags Key=Name,Value=$PROJECT_NAME-subnet \
        --region $AWS_REGION
    
    log "Subnets created: $subnet_1_id, $subnet_2_id"
    
    # Create route table
    local route_table_id=$(aws ec2 create-route-table \
        --vpc-id $vpc_id \
        --query 'RouteTable.RouteTableId' \
        --output text \
        --region $AWS_REGION)
    
    aws ec2 create-route \
        --route-table-id $route_table_id \
        --destination-cidr-block 0.0.0.0/0 \
        --gateway-id $igw_id \
        --region $AWS_REGION
    
    aws ec2 associate-route-table \
        --route-table-id $route_table_id \
        --subnet-id $subnet_1_id \
        --region $AWS_REGION
    
    aws ec2 associate-route-table \
        --route-table-id $route_table_id \
        --subnet-id $subnet_2_id \
        --region $AWS_REGION
    
    log "Route table created and associated: $route_table_id"
    
    # Create security group
    local sg_id=$(aws ec2 create-security-group \
        --group-name $PROJECT_NAME-sg \
        --description "Security group for $PROJECT_NAME" \
        --vpc-id $vpc_id \
        --query 'GroupId' \
        --output text \
        --region $AWS_REGION)
    
    aws ec2 authorize-security-group-ingress \
        --group-id $sg_id \
        --protocol tcp \
        --port 80 \
        --cidr 0.0.0.0/0 \
        --region $AWS_REGION
    
    aws ec2 authorize-security-group-ingress \
        --group-id $sg_id \
        --protocol tcp \
        --port 443 \
        --cidr 0.0.0.0/0 \
        --region $AWS_REGION
    
    log "Security group created: $sg_id"
    
    # Output values for later use
    echo "VPC_ID=$vpc_id"
    echo "SUBNET_1_ID=$subnet_1_id"
    echo "SUBNET_2_ID=$subnet_2_id"
    echo "SECURITY_GROUP_ID=$sg_id"
}

# Create ECS cluster
create_ecs_cluster() {
    log "Creating ECS cluster..."
    
    aws ecs create-cluster \
        --cluster-name $ECS_CLUSTER \
        --region $AWS_REGION
    
    log "ECS cluster created: $ECS_CLUSTER"
}

# Create IAM roles
create_iam_roles() {
    log "Creating IAM roles..."
    
    # ECS Task Execution Role
    local task_execution_role_policy='{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "ecs-tasks.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }'
    
    aws iam create-role \
        --role-name ecsTaskExecutionRole \
        --assume-role-policy-document "$task_execution_role_policy" \
        --region $AWS_REGION || true
    
    aws iam attach-role-policy \
        --role-name ecsTaskExecutionRole \
        --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy \
        --region $AWS_REGION || true
    
    # ECS Task Role
    local task_role_policy='{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "ecs-tasks.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }'
    
    aws iam create-role \
        --role-name ecsTaskRole \
        --assume-role-policy-document "$task_role_policy" \
        --region $AWS_REGION || true
    
    # Custom policy for S3 and other services
    local custom_policy='{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "s3:GetObject",
                    "s3:PutObject",
                    "s3:DeleteObject",
                    "s3:ListBucket"
                ],
                "Resource": "*"
            },
            {
                "Effect": "Allow",
                "Action": [
                    "secretsmanager:GetSecretValue"
                ],
                "Resource": "*"
            }
        ]
    }'
    
    aws iam create-policy \
        --policy-name LaravelAppPolicy \
        --policy-document "$custom_policy" \
        --region $AWS_REGION || true
    
    aws iam attach-role-policy \
        --role-name ecsTaskRole \
        --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/LaravelAppPolicy \
        --region $AWS_REGION || true
    
    log "IAM roles created successfully"
}

# Create RDS instance
create_rds() {
    log "Creating RDS instance..."
    
    aws rds create-db-instance \
        --db-instance-identifier $PROJECT_NAME-db \
        --db-instance-class db.t3.micro \
        --engine mysql \
        --engine-version 8.0 \
        --master-username admin \
        --master-user-password "$(openssl rand -base64 32)" \
        --allocated-storage 20 \
        --storage-type gp2 \
        --vpc-security-group-ids $SECURITY_GROUP_ID \
        --db-subnet-group-name default \
        --backup-retention-period 7 \
        --region $AWS_REGION
    
    log "RDS instance creation initiated"
}

# Create ElastiCache cluster
create_elasticache() {
    log "Creating ElastiCache cluster..."
    
    aws elasticache create-cache-cluster \
        --cache-cluster-id $PROJECT_NAME-redis \
        --cache-node-type cache.t3.micro \
        --engine redis \
        --num-cache-nodes 1 \
        --security-group-ids $SECURITY_GROUP_ID \
        --region $AWS_REGION
    
    log "ElastiCache cluster creation initiated"
}

# Create Application Load Balancer
create_load_balancer() {
    log "Creating Application Load Balancer..."
    
    local lb_arn=$(aws elbv2 create-load-balancer \
        --name $PROJECT_NAME-alb \
        --subnets $SUBNET_1_ID $SUBNET_2_ID \
        --security-groups $SECURITY_GROUP_ID \
        --query 'LoadBalancers[0].LoadBalancerArn' \
        --output text \
        --region $AWS_REGION)
    
    local target_group_arn=$(aws elbv2 create-target-group \
        --name $PROJECT_NAME-tg \
        --protocol HTTP \
        --port 80 \
        --vpc-id $VPC_ID \
        --target-type ip \
        --health-check-path /health \
        --query 'TargetGroups[0].TargetGroupArn' \
        --output text \
        --region $AWS_REGION)
    
    aws elbv2 create-listener \
        --load-balancer-arn $lb_arn \
        --protocol HTTP \
        --port 80 \
        --default-actions Type=forward,TargetGroupArn=$target_group_arn \
        --region $AWS_REGION
    
    log "Load balancer created: $lb_arn"
    echo "TARGET_GROUP_ARN=$target_group_arn"
}

# Main setup function
main() {
    log "Starting AWS infrastructure setup..."
    
    create_ecr_repository
    local vpc_info=$(create_vpc)
    create_ecs_cluster
    create_iam_roles
    
    # Extract VPC info
    eval $vpc_info
    
    create_rds
    create_elasticache
    create_load_balancer
    
    log "AWS infrastructure setup completed!"
    log "Please update your .aws/task-definition.json with the correct account ID and resource ARNs"
}

# Help function
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Set up AWS infrastructure for Laravel ECS deployment

OPTIONS:
    --help         Show this help message

This script will create:
- ECR repository
- VPC with subnets and security groups
- ECS cluster
- IAM roles
- RDS MySQL instance
- ElastiCache Redis cluster
- Application Load Balancer

Make sure you have AWS CLI configured with appropriate permissions.
EOF
}

# Parse command line arguments
case "$1" in
    --help)
        show_help
        exit 0
        ;;
    "")
        main
        ;;
    *)
        error "Unknown option: $1. Use --help for usage information."
        ;;
esac