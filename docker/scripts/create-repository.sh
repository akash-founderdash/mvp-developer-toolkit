#!/bin/bash

set -euo pipefail

# Configuration
MVP_OUTPUT_DIR="/workspace/mvp"
MAX_RETRIES=3
RETRY_DELAY=5

# Arguments
MVP_NAME="$1"

# Derived variables
REPO_NAME=$(echo "$MVP_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"stage\":\"REPO_CREATE\",\"message\":\"$message\"}" >&2
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
    log_error "Repository creation failed with exit code $exit_code"
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

# Setup GitHub CLI authentication
setup_github_auth() {
    log_info "Setting up GitHub CLI authentication"
    
    # Get GitHub token from AWS Secrets Manager
    if [ -n "${GITHUB_TOKEN_SECRET:-}" ]; then
        log_info "Retrieving GitHub token from Secrets Manager"
        
        local github_token
        github_token=$(aws secretsmanager get-secret-value \
            --secret-id "$GITHUB_TOKEN_SECRET" \
            --query SecretString \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$github_token" ]; then
            # Authenticate GitHub CLI
            echo "$github_token" | gh auth login --with-token
            
            # Verify authentication
            if gh auth status >/dev/null 2>&1; then
                log_info "GitHub CLI authenticated successfully"
                
                # Get authenticated user info
                local username
                username=$(gh api user --jq '.login')
                log_info "Authenticated as: $username"
                
                return 0
            else
                log_error "GitHub CLI authentication verification failed"
                return 1
            fi
        else
            log_error "Could not retrieve GitHub token from Secrets Manager"
            return 1
        fi
    else
        log_error "GITHUB_TOKEN_SECRET environment variable not set"
        return 1
    fi
}

# Check if repository already exists
check_repository_exists() {
    local repo_name="$1"
    
    log_info "Checking if repository already exists: $repo_name"
    
    if gh repo view "$repo_name" >/dev/null 2>&1; then
        log_info "Repository already exists: $repo_name"
        return 0
    else
        log_info "Repository does not exist: $repo_name"
        return 1
    fi
}

# Create GitHub repository
create_github_repository() {
    local repo_name="$1"
    local description="$2"
    
    log_info "Creating GitHub repository: $repo_name"
    
    # Check if repository already exists
    if check_repository_exists "$repo_name"; then
        log_error "Repository already exists: $repo_name"
        return 1
    fi
    
    # Create repository with GitHub CLI
    local create_cmd="gh repo create '$repo_name' --private --description '$description' --clone=false"
    
    if retry_with_backoff "$create_cmd"; then
        log_info "Repository created successfully: $repo_name"
        
        # Get repository URL
        local repo_url
        repo_url=$(gh repo view "$repo_name" --json url --jq '.url')
        log_info "Repository URL: $repo_url"
        
        # Store repository URL for later use
        echo "$repo_url" > /workspace/repo_url.txt
        
        return 0
    else
        log_error "Failed to create repository: $repo_name"
        return 1
    fi
}

# Prepare repository content
prepare_repository_content() {
    log_info "Preparing repository content"
    
    if [ ! -d "$MVP_OUTPUT_DIR" ]; then
        log_error "MVP output directory not found: $MVP_OUTPUT_DIR"
        return 1
    fi
    
    cd "$MVP_OUTPUT_DIR"
    
    # Initialize Git repository if not already initialized
    # Ensure home directory exists for git config
    mkdir -p "$HOME"
    
    if [ ! -d ".git" ]; then
        log_info "Initializing Git repository"
        git init
        git branch -M main
    fi
    
    # Configure Git user (use --global to ensure it works)
    git config --global user.name "MVP Pipeline Bot"
    git config --global user.email "mvp-pipeline@example.com"
    
    # Create or update README.md
    create_repository_readme
    
    # Create .gitignore if it doesn't exist
    if [ ! -f ".gitignore" ]; then
        create_gitignore
    fi
    
    log_info "Repository content prepared"
}

# Create repository README
create_repository_readme() {
    log_info "Creating repository README"
    
    local readme_file="README.md"
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    
    cat > "$readme_file" << EOF
# $MVP_NAME

Generated MVP application based on event-engagement-toolkit.

## Description

This is an automatically generated MVP application created by the MVP Pipeline system.

## Features

- Next.js application with TypeScript
- Tailwind CSS for styling
- Supabase integration for backend services
- Vercel deployment ready

## Getting Started

### Prerequisites

- Node.js 20.x or later
- pnpm (recommended) or npm

### Installation

1. Clone the repository:
   \`\`\`bash
   git clone <repository-url>
   cd $REPO_NAME
   \`\`\`

2. Install dependencies:
   \`\`\`bash
   pnpm install
   \`\`\`

3. Set up environment variables:
   \`\`\`bash
   cp .env.example .env.local
   \`\`\`

4. Run the development server:
   \`\`\`bash
   pnpm dev
   \`\`\`

Open [http://localhost:3000](http://localhost:3000) with your browser to see the result.

## Deployment

This application is configured for deployment on Vercel. Simply connect your GitHub repository to Vercel for automatic deployments.

## Project Structure

- \`apps/web/\` - Main Next.js application
- \`packages/\` - Shared packages and utilities
- \`infrastructure/\` - Infrastructure as code (Terraform)

## Generated Information

- **Generated**: $timestamp
- **Source**: event-engagement-toolkit
- **Pipeline**: MVP Pipeline v1.0

## Support

This is an automatically generated application. For support, please refer to the original event-engagement-toolkit documentation.
EOF

    log_info "README.md created successfully"
}

# Create .gitignore file
create_gitignore() {
    log_info "Creating .gitignore file"
    
    cat > ".gitignore" << 'EOF'
# Dependencies
node_modules/
.pnp
.pnp.js

# Testing
coverage/

# Next.js
.next/
out/

# Production
build/
dist/

# Environment variables
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Vercel
.vercel

# TypeScript
*.tsbuildinfo
next-env.d.ts

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Logs
logs
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*
pnpm-debug.log*
lerna-debug.log*

# Runtime data
pids
*.pid
*.seed
*.pid.lock

# Temporary folders
tmp/
temp/

# Optional npm cache directory
.npm

# Optional eslint cache
.eslintcache

# Microbundle cache
.rpt2_cache/
.rts2_cache_cjs/
.rts2_cache_es/
.rts2_cache_umd/

# Optional REPL history
.node_repl_history

# Output of 'npm pack'
*.tgz

# Yarn Integrity file
.yarn-integrity

# parcel-bundler cache (https://parceljs.org/)
.cache
.parcel-cache

# Stores VSCode versions used for testing VSCode extensions
.vscode-test

# yarn v2
.yarn/cache
.yarn/unplugged
.yarn/build-state.yml
.yarn/install-state.gz
.pnp.*
EOF

    log_info ".gitignore created successfully"
}

# Add and commit files
commit_files() {
    log_info "Adding and committing files"
    log_debug ">Current directory: $(pwd)"
    log_info ">mvp output dir: $MVP_OUTPUT_DIR"
    cd "$MVP_OUTPUT_DIR"
    
    # Add all files
    git add .
    
    # Check if there are changes to commit
    if git diff --staged --quiet; then
        log_info "No changes to commit"
        return 0
    fi  
    
    # Commit files
    local commit_message="Initial commit: $MVP_NAME MVP

Generated by MVP Pipeline
Timestamp: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Source: event-engagement-toolkit"
    
    if git commit -m "$commit_message"; then
        log_info "Files committed successfully"
    else
        log_error "Failed to commit files"
        return 1
    fi
}

# Push to GitHub repository
push_to_github() {
    local repo_name="$1"
    
    log_info "Pushing code to GitHub repository: $repo_name"
    
    cd "$MVP_OUTPUT_DIR"
    
    # Get repository URL for pushing
    local repo_url
    repo_url=$(gh repo view "$repo_name" --json cloneUrl --jq '.cloneUrl')
    
    # Add remote origin
    if git remote get-url origin >/dev/null 2>&1; then
        git remote set-url origin "$repo_url"
    else
        git remote add origin "$repo_url"
    fi
    
    # Push to main branch
    local push_cmd="git push -u origin main"
    
    if retry_with_backoff "$push_cmd"; then
        log_info "Code pushed successfully to GitHub"
        
        # Get final repository URL
        local final_repo_url
        final_repo_url=$(gh repo view "$repo_name" --json url --jq '.url')
        
        # Update stored repository URL
        echo "$final_repo_url" > /workspace/repo_url.txt
        
        log_info "Repository available at: $final_repo_url"
        return 0
    else
        log_error "Failed to push code to GitHub"
        return 1
    fi
}

# Verify repository creation
verify_repository() {
    local repo_name="$1"
    
    log_info "Verifying repository creation"
    
    # Check repository exists and is accessible
    if ! gh repo view "$repo_name" >/dev/null 2>&1; then
        log_error "Repository verification failed: $repo_name"
        return 1
    fi
    
    # Get repository information using GitHub CLI with individual queries
    local repo_url
    repo_url=$(gh repo view "$repo_name" --json url --jq '.url' 2>/dev/null || echo "")
    
    local is_private
    is_private=$(gh repo view "$repo_name" --json isPrivate --jq '.isPrivate' 2>/dev/null || echo "unknown")
    
    local default_branch
    default_branch=$(gh repo view "$repo_name" --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null || echo "main")
    
    log_info "Repository verification successful"
    log_info "URL: $repo_url"
    log_info "Private: $is_private"
    log_info "Default branch: $default_branch"
    
    return 0
}

# Main function
main() {
    log_info "Starting repository creation process"
    log_info "MVP Name: $MVP_NAME"
    log_info "Repository Name: $REPO_NAME"
    
    setup_github_auth
    
    local description="MVP application: $MVP_NAME - Generated by MVP Pipeline"
    
    create_github_repository "$REPO_NAME" "$description"
    prepare_repository_content
    commit_files
    push_to_github "$REPO_NAME"
    verify_repository "$REPO_NAME"
    
    log_info "Repository creation completed successfully"
    log_info "Repository: $REPO_NAME"
    
    # Read and log the final repository URL
    if [ -f "/workspace/repo_url.txt" ]; then
        local final_url
        final_url=$(cat /workspace/repo_url.txt)
        log_info "Repository URL: $final_url"
    fi
}

# Run main function
main "$@"