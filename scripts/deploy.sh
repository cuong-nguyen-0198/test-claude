#!/bin/bash

# Laravel AWS ECS Deployment Script

set -e

# Configuration
AWS_REGION="us-east-1"
ECR_REPOSITORY="laravel-app"
ECS_CLUSTER="laravel-cluster"
ECS_SERVICE="laravel-service"
TASK_DEFINITION_FILE=".aws/task-definition.json"

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

# Check if AWS CLI is installed
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        error "AWS CLI is not installed. Please install it first."
    fi
    log "AWS CLI is installed"
}

# Check if required environment variables are set
check_environment() {
    if [[ -z "$AWS_ACCESS_KEY_ID" || -z "$AWS_SECRET_ACCESS_KEY" ]]; then
        error "AWS credentials not found. Please set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
    fi
    log "AWS credentials found"
}

# Login to ECR
ecr_login() {
    log "Logging into Amazon ECR..."
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPOSITORY
    log "Successfully logged into ECR"
}

# Build and push Docker image
build_and_push() {
    local image_tag=${1:-$(git rev-parse --short HEAD)}
    local ecr_uri="$ECR_REPOSITORY:$image_tag"

    log "Building Docker image with tag: $image_tag"
    docker build -f Dockerfile.prod -t $ecr_uri .

    log "Pushing image to ECR..."
    docker push $ecr_uri

    log "Image pushed successfully: $ecr_uri"
    echo $ecr_uri
}

# Update ECS task definition
update_task_definition() {
    local image_uri=$1
    local temp_file=$(mktemp)

    log "Updating task definition with new image..."

    # Replace image URI in task definition
    sed "s|YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/laravel-app:latest|$image_uri|g" $TASK_DEFINITION_FILE > $temp_file

    # Register new task definition
    aws ecs register-task-definition \
        --cli-input-json file://$temp_file \
        --region $AWS_REGION

    rm $temp_file
    log "Task definition updated successfully"
}

# Deploy to ECS
deploy_to_ecs() {
    log "Deploying to ECS service..."

    # Update service with new task definition
    aws ecs update-service \
        --cluster $ECS_CLUSTER \
        --service $ECS_SERVICE \
        --force-new-deployment \
        --region $AWS_REGION

    log "Deployment initiated"
}

# Wait for deployment to complete
wait_for_deployment() {
    log "Waiting for deployment to complete..."

    aws ecs wait services-stable \
        --cluster $ECS_CLUSTER \
        --services $ECS_SERVICE \
        --region $AWS_REGION

    log "Deployment completed successfully"
}

# Run database migrations
run_migrations() {
    log "Running database migrations..."

    # Get task definition ARN
    local task_def_arn=$(aws ecs describe-services \
        --cluster $ECS_CLUSTER \
        --services $ECS_SERVICE \
        --query 'services[0].taskDefinition' \
        --output text \
        --region $AWS_REGION)

    # Run migration task
    aws ecs run-task \
        --cluster $ECS_CLUSTER \
        --task-definition $task_def_arn \
        --overrides '{
            "containerOverrides": [{
                "name": "laravel-app",
                "command": ["php", "artisan", "migrate", "--force"]
            }]
        }' \
        --region $AWS_REGION

    log "Database migrations completed"
}

# Clear application cache
clear_cache() {
    log "Clearing application cache..."

    # Get task definition ARN
    local task_def_arn=$(aws ecs describe-services \
        --cluster $ECS_CLUSTER \
        --services $ECS_SERVICE \
        --query 'services[0].taskDefinition' \
        --output text \
        --region $AWS_REGION)

    # Clear cache
    aws ecs run-task \
        --cluster $ECS_CLUSTER \
        --task-definition $task_def_arn \
        --overrides '{
            "containerOverrides": [{
                "name": "laravel-app",
                "command": ["php", "artisan", "cache:clear"]
            }]
        }' \
        --region $AWS_REGION

    log "Application cache cleared"
}

# Main deployment function
main() {
    log "Starting deployment process..."

    check_aws_cli
    check_environment
    ecr_login

    local image_uri=$(build_and_push)
    update_task_definition $image_uri
    deploy_to_ecs
    wait_for_deployment

    if [[ "$1" == "--migrate" ]]; then
        run_migrations
    fi

    if [[ "$1" == "--clear-cache" ]]; then
        clear_cache
    fi

    log "Deployment completed successfully!"
}

# Help function
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy Laravel application to AWS ECS

OPTIONS:
    --migrate       Run database migrations after deployment
    --clear-cache   Clear application cache after deployment
    --help         Show this help message

ENVIRONMENT VARIABLES:
    AWS_ACCESS_KEY_ID       AWS access key ID
    AWS_SECRET_ACCESS_KEY   AWS secret access key
    AWS_DEFAULT_REGION      AWS region (default: us-east-1)
    LOG_SLACK_WEBHOOK_URL   SLACK webhook url

EXAMPLES:
    $0                     # Deploy without migrations
    $0 --migrate           # Deploy and run migrations
    $0 --clear-cache       # Deploy and clear cache
EOF
}

# Parse command line arguments
case "$1" in
    --help)
        show_help
        exit 0
        ;;
    --migrate|--clear-cache)
        main "$1"
        ;;
    "")
        main
        ;;
    *)
        error "Unknown option: $1. Use --help for usage information."
        ;;
esac
