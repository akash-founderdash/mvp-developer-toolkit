#!/bin/bash

set -euo pipefail

# Configuration
MVP_OUTPUT_DIR="/workspace/mvp"
MAX_RETRIES=3
RETRY_DELAY=10

# Arguments
MVP_NAME="$1"

# Derived variables
PROJECT_NAME=$(echo "$MVP_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"stage\":\"DEPLOY\",\"message\":\"$message\"}" >&2
}

log_info() {
    log "INFO" "$@"
}

log_error() {
    log "ERROR" "$@"
}

log_debug() {
    if [ "${LOG_LEVEL:-INFO}" = "DEBUG" ]; then
        log "DEBUG" "$@"
    fi
}

# Error handling
handle_error() {
    local exit_code=$?
    log_error "Vercel deployment failed with exit code $exit_code"
    exit $exit_code
}

trap handle_error ERR

# Retry function with exponential backoff
retry_with_backoff() {
    local cmd="$1"
    local retries=0
    local delay=$RETRY_DELAY
    
    while [ $retries -lt $MAX_RETRIES ]; do
        if eval "$cmd"; then
            return 0
        fi
        
        retries=$((retries + 1))
        if [ $retries -lt $MAX_RETRIES ]; then
            log_info "Command failed, retrying in ${delay}s (attempt $retries/$MAX_RETRIES)"
            sleep $delay
            delay=$((delay * 2))  # Exponential backoff
        fi
    done
    
    log_error "Command failed after $MAX_RETRIES attempts: $cmd"
    return 1
}

# Setup Vercel CLI authentication
setup_vercel_auth() {
    log_info "Setting up Vercel CLI authentication"
    
    # Get Vercel token from AWS Secrets Manager
    if [ -n "${VERCEL_TOKEN_SECRET:-}" ]; then
        log_info "Retrieving Vercel token from Secrets Manager"
        
        local vercel_token
        vercel_token=$(aws secretsmanager get-secret-value \
            --secret-id "$VERCEL_TOKEN_SECRET" \
            --query SecretString \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$vercel_token" ]; then
            # Set Vercel token as environment variable
            export VERCEL_TOKEN="$vercel_token"
            
            # Verify authentication by getting user info
            if vercel whoami >/dev/null 2>&1; then
                local username
                username=$(vercel whoami)
                log_info "Vercel CLI authenticated successfully as: $username"
                return 0
            else
                log_error "Vercel CLI authentication verification failed"
                return 1
            fi
        else
            log_error "Could not retrieve Vercel token from Secrets Manager"
            return 1
        fi
    else
        log_error "VERCEL_TOKEN_SECRET environment variable not set"
        return 1
    fi
}

# Get repository information
get_repository_info() {
    log_info "Getting repository information"
    
    if [ ! -f "/workspace/repo_url.txt" ]; then
        log_error "Repository URL file not found"
        return 1
    fi
    
    local repo_url
    repo_url=$(cat /workspace/repo_url.txt)
    
    if [ -z "$repo_url" ]; then
        log_error "Repository URL is empty"
        return 1
    fi
    
    log_info "Repository URL: $repo_url"
    echo "$repo_url"
}

# Check if Vercel project already exists
check_project_exists() {
    local project_name="$1"
    
    log_info "Checking if Vercel project already exists: $project_name"
    
    # Check if project exists by looking for the name in the output
    if vercel projects ls 2>/dev/null | grep -q "$project_name"; then
        log_info "Vercel project already exists: $project_name"
        return 0
    else
        log_info "Vercel project does not exist: $project_name"
        return 1
    fi
}

# Create Vercel project
create_vercel_project() {
    local project_name="$1"
    local repo_url="$2"
    
    log_info "Creating Vercel project: $project_name"
    log_info "Repository: $repo_url"
    
    cd "$MVP_OUTPUT_DIR"
    
    # Check if project already exists
    if check_project_exists "$project_name"; then
        log_info "Project already exists, skipping creation"
        return 0
    fi
    
    # Extract GitHub repository information from URL
    local github_repo
    github_repo=$(echo "$repo_url" | sed 's|https://github.com/||' | sed 's|\.git$||')
    
    log_info "GitHub repository: $github_repo"
    
    # Create project using Vercel CLI
    local create_cmd="vercel --yes --name '$project_name' --prod"
    
    if retry_with_backoff "$create_cmd"; then
        log_info "Vercel project created successfully: $project_name"
        return 0
    else
        log_error "Failed to create Vercel project: $project_name"
        return 1
    fi
}

# Configure project settings
configure_project_settings() {
    local project_name="$1"
    
    log_info "Configuring Vercel project settings"
    
    cd "$MVP_OUTPUT_DIR"
    
    # Create vercel.json configuration
    create_vercel_config
    
    # Set environment variables if needed
    configure_environment_variables "$project_name"
    
    log_info "Project settings configured successfully"
}

# Create Vercel configuration
create_vercel_config() {
    log_info "Creating Vercel configuration"
    
    local vercel_config="vercel.json"
    
    cat > "$vercel_config" << 'EOF'
{
  "version": 2,
  "builds": [
    {
      "src": "apps/web/package.json",
      "use": "@vercel/next"
    }
  ],
  "routes": [
    {
      "src": "/(.*)",
      "dest": "apps/web/$1"
    }
  ],
  "env": {
    "NODE_VERSION": "20.x"
  },
  "buildCommand": "cd apps/web && pnpm build",
  "devCommand": "cd apps/web && pnpm dev",
  "installCommand": "pnpm install",
  "outputDirectory": "apps/web/.next"
}
EOF

    log_info "Vercel configuration created: $vercel_config"
}

# Configure environment variables
configure_environment_variables() {
    local project_name="$1"
    
    log_info "Configuring environment variables"
    
    # Set common environment variables for Next.js
    local env_vars=(
        "NODE_ENV=production"
        "NEXT_TELEMETRY_DISABLED=1"
    )
    
    for env_var in "${env_vars[@]}"; do
        local key="${env_var%%=*}"
        local value="${env_var#*=}"
        
        log_debug "Setting environment variable: $key"
        
        # Set environment variable for production
        if vercel env add "$key" production <<< "$value" >/dev/null 2>&1; then
            log_debug "Environment variable set: $key"
        else
            log_debug "Failed to set environment variable: $key (may already exist)"
        fi
    done
    
    log_info "Environment variables configured"
}

# Deploy to Vercel
deploy_to_vercel() {
    local project_name="$1"
    
    log_info "Deploying to Vercel: $project_name"
    
    cd "$MVP_OUTPUT_DIR"
    
    # Deploy with production flag
    local deploy_cmd="vercel --prod --yes"
    
    local deployment_output
    if deployment_output=$(retry_with_backoff "$deploy_cmd"); then
        log_info "Deployment initiated successfully"
        
        # Extract deployment URL from output
        local deployment_url
        deployment_url=$(echo "$deployment_output" | grep -E "https://.*\.vercel\.app" | tail -1 | tr -d ' ')
        
        if [ -n "$deployment_url" ]; then
            log_info "Deployment URL: $deployment_url"
            echo "$deployment_url" > /workspace/deployment_url.txt
            return 0
        else
            log_error "Could not extract deployment URL from output"
            return 1
        fi
    else
        log_error "Deployment failed"
        return 1
    fi
}

# Monitor deployment status
monitor_deployment() {
    local project_name="$1"
    
    log_info "Monitoring deployment status"
    
    local max_wait=300  # 5 minutes
    local wait_time=0
    local check_interval=10
    
    while [ $wait_time -lt $max_wait ]; do
        # Get deployment status
        local deployments
        deployments=$(vercel deployments --format json 2>/dev/null || echo "[]")
        
        if [ "$deployments" != "[]" ]; then
            # Extract state and URL using grep and sed instead of jq
            local state
            state=$(echo "$deployments" | grep -o '"state":"[^"]*"' | head -1 | sed 's/"state":"\([^"]*\)"/\1/' || echo "UNKNOWN")
            
            local url
            url=$(echo "$deployments" | grep -o '"url":"[^"]*"' | head -1 | sed 's/"url":"\([^"]*\)"/\1/' || echo "")
            
            log_info "Deployment state: $state"
            
            case "$state" in
                "READY")
                    log_info "Deployment completed successfully"
                    if [ -n "$url" ]; then
                        local full_url="https://$url"
                        log_info "Application URL: $full_url"
                        echo "$full_url" > /workspace/deployment_url.txt
                    fi
                    return 0
                    ;;
                "ERROR"|"CANCELED")
                    log_error "Deployment failed with state: $state"
                    return 1
                    ;;
                "BUILDING"|"QUEUED"|"INITIALIZING")
                    log_info "Deployment in progress: $state"
                    ;;
                *)
                    log_info "Unknown deployment state: $state"
                    ;;
            esac
        fi
        
        sleep $check_interval
        wait_time=$((wait_time + check_interval))
    done
    
    log_error "Deployment monitoring timed out after ${max_wait}s"
    return 1
}

# Verify deployment
verify_deployment() {
    log_info "Verifying deployment"
    
    if [ ! -f "/workspace/deployment_url.txt" ]; then
        log_error "Deployment URL file not found"
        return 1
    fi
    
    local deployment_url
    deployment_url=$(cat /workspace/deployment_url.txt)
    
    if [ -z "$deployment_url" ]; then
        log_error "Deployment URL is empty"
        return 1
    fi
    
    log_info "Testing deployment URL: $deployment_url"
    
    # Test if the deployment is accessible
    local http_status
    http_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 30 "$deployment_url" || echo "000")
    
    if [ "$http_status" = "200" ]; then
        log_info "Deployment verification successful (HTTP $http_status)"
        return 0
    else
        log_error "Deployment verification failed (HTTP $http_status)"
        return 1
    fi
}

# Get project information
get_project_info() {
    local project_name="$1"
    
    log_info "Getting project information"
    
    # Get basic project information
    log_info "Project Name: $project_name"
    
    # Try to get project details using vercel CLI
    if vercel projects ls 2>/dev/null | grep -q "$project_name"; then
        log_info "Project exists in Vercel"
    else
        log_info "Project not found in Vercel list"
    fi
}

# Main function
main() {
    log_info "Starting Vercel deployment process"
    log_info "MVP Name: $MVP_NAME"
    log_info "Project Name: $PROJECT_NAME"
    
    setup_vercel_auth
    
    local repo_url
    repo_url=$(get_repository_info)
    
    create_vercel_project "$PROJECT_NAME" "$repo_url"
    configure_project_settings "$PROJECT_NAME"
    deploy_to_vercel "$PROJECT_NAME"
    monitor_deployment "$PROJECT_NAME"
    verify_deployment
    get_project_info "$PROJECT_NAME"
    
    log_info "Vercel deployment completed successfully"
    
    # Read and log the final deployment URL
    if [ -f "/workspace/deployment_url.txt" ]; then
        local final_url
        final_url=$(cat /workspace/deployment_url.txt)
        log_info "Application URL: $final_url"
    fi
}

# Run main function
main "$@"