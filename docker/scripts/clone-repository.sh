#!/bin/bash

set -euo pipefail

# Configuration
REPO_URL="https://github.com/your-org/event-engagement-toolkit.git"
CLONE_DIR="/workspace/source"
MAX_RETRIES=3
RETRY_DELAY=5

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"stage\":\"CLONE\",\"message\":\"$message\"}" >&2
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
    log_error "Repository cloning failed with exit code $exit_code"
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

# Setup Git authentication
setup_git_auth() {
    log_info "Setting up Git authentication"
    
    # Get GitHub token from AWS Secrets Manager
    if [ -n "${GITHUB_TOKEN_SECRET:-}" ]; then
        log_info "Retrieving GitHub token from Secrets Manager"
        
        local github_token
        github_token=$(aws secretsmanager get-secret-value \
            --secret-id "$GITHUB_TOKEN_SECRET" \
            --query SecretString \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$github_token" ]; then
            # Configure Git to use token authentication
            git config --global credential.helper store
            echo "https://oauth2:${github_token}@github.com" > ~/.git-credentials
            
            # Set Git user (required for commits)
            git config --global user.name "MVP Pipeline Bot"
            git config --global user.email "mvp-pipeline@example.com"
            
            log_info "Git authentication configured successfully"
        else
            log_error "Could not retrieve GitHub token from Secrets Manager"
            return 1
        fi
    else
        log_error "GITHUB_TOKEN_SECRET environment variable not set"
        return 1
    fi
}

# Clone repository
clone_repository() {
    log_info "Cloning repository: $REPO_URL"
    
    # Remove existing directory if it exists
    if [ -d "$CLONE_DIR" ]; then
        log_info "Removing existing clone directory"
        rm -rf "$CLONE_DIR"
    fi
    
    # Create parent directory
    mkdir -p "$(dirname "$CLONE_DIR")"
    
    # Clone with shallow depth for performance
    local clone_cmd="git clone --depth 1 --single-branch --branch main '$REPO_URL' '$CLONE_DIR'"
    
    if retry_with_backoff "$clone_cmd"; then
        log_info "Repository cloned successfully"
    else
        # Try with master branch if main fails
        log_info "Retrying with master branch"
        clone_cmd="git clone --depth 1 --single-branch --branch master '$REPO_URL' '$CLONE_DIR'"
        
        if retry_with_backoff "$clone_cmd"; then
            log_info "Repository cloned successfully (master branch)"
        else
            log_error "Failed to clone repository with both main and master branches"
            return 1
        fi
    fi
}

# Validate repository structure
validate_repository() {
    log_info "Validating repository structure"
    
    if [ ! -d "$CLONE_DIR" ]; then
        log_error "Clone directory does not exist: $CLONE_DIR"
        return 1
    fi
    
    # Check for essential files
    local required_files=(
        "package.json"
        "README.md"
    )
    
    local required_dirs=(
        "apps"
        "packages"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$CLONE_DIR/$file" ]; then
            log_error "Required file not found: $file"
            return 1
        fi
    done
    
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$CLONE_DIR/$dir" ]; then
            log_error "Required directory not found: $dir"
            return 1
        fi
    done
    
    # Check if it's a valid Git repository
    if [ ! -d "$CLONE_DIR/.git" ]; then
        log_error "Not a valid Git repository"
        return 1
    fi
    
    # Get repository information
    cd "$CLONE_DIR"
    local commit_hash=$(git rev-parse HEAD)
    local branch_name=$(git rev-parse --abbrev-ref HEAD)
    
    log_info "Repository validation successful"
    log_info "Branch: $branch_name"
    log_info "Commit: $commit_hash"
    
    # Store repository info for later use
    echo "$commit_hash" > /workspace/source_commit.txt
    echo "$branch_name" > /workspace/source_branch.txt
}

# Install dependencies
install_dependencies() {
    log_info "Installing repository dependencies"
    
    cd "$CLONE_DIR"
    
    # Check if pnpm-lock.yaml exists
    if [ -f "pnpm-lock.yaml" ]; then
        log_info "Installing dependencies with pnpm"
        
        local install_cmd="pnpm install --frozen-lockfile"
        
        if retry_with_backoff "$install_cmd"; then
            log_info "Dependencies installed successfully"
        else
            log_error "Failed to install dependencies"
            return 1
        fi
    elif [ -f "package-lock.json" ]; then
        log_info "Installing dependencies with npm"
        
        local install_cmd="npm ci"
        
        if retry_with_backoff "$install_cmd"; then
            log_info "Dependencies installed successfully"
        else
            log_error "Failed to install dependencies"
            return 1
        fi
    elif [ -f "yarn.lock" ]; then
        log_info "Installing dependencies with yarn"
        
        local install_cmd="yarn install --frozen-lockfile"
        
        if retry_with_backoff "$install_cmd"; then
            log_info "Dependencies installed successfully"
        else
            log_error "Failed to install dependencies"
            return 1
        fi
    else
        log_info "No lock file found, using npm install"
        
        local install_cmd="npm install"
        
        if retry_with_backoff "$install_cmd"; then
            log_info "Dependencies installed successfully"
        else
            log_error "Failed to install dependencies"
            return 1
        fi
    fi
}

# Main function
main() {
    log_info "Starting repository cloning process"
    
    setup_git_auth
    clone_repository
    validate_repository
    install_dependencies
    
    log_info "Repository cloning completed successfully"
    log_info "Repository location: $CLONE_DIR"
}

# Run main function
main "$@"