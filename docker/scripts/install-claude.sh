#!/bin/bash

set -euo pipefail

# Configuration
CLAUDE_INSTALL_DIR="/home/mvpuser/.local/bin"
CLAUDE_CONFIG_DIR="/home/mvpuser/.config/claude"
MAX_RETRIES=3
RETRY_DELAY=5

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [CLAUDE-INSTALL] $1" >&2
}

# Error handling
handle_error() {
    local exit_code=$?
    log "ERROR: Claude Code installation failed with exit code $exit_code"
    exit $exit_code
}

trap handle_error ERR

# Retry function
retry() {
    local cmd="$1"
    local retries=0
    
    while [ $retries -lt $MAX_RETRIES ]; do
        if eval "$cmd"; then
            return 0
        fi
        
        retries=$((retries + 1))
        if [ $retries -lt $MAX_RETRIES ]; then
            log "Command failed, retrying in ${RETRY_DELAY}s (attempt $retries/$MAX_RETRIES)"
            sleep $RETRY_DELAY
        fi
    done
    
    log "ERROR: Command failed after $MAX_RETRIES attempts: $cmd"
    return 1
}

# Create directories
create_directories() {
    log "Creating Claude directories..."
    mkdir -p "$CLAUDE_INSTALL_DIR"
    mkdir -p "$CLAUDE_CONFIG_DIR"
}

# Step 1: Skip system installation (Node.js and npm already available in container)
install_nodejs_npm() {
    log "Step 1: Skipping Node.js/npm installation (already available in container)..."
    log "Node.js and npm are pre-installed in the container environment"
}

# Step 2: Check if installation was successful
verify_nodejs_npm() {
    log "Step 2: Verifying Node.js and npm installation..."
    
    # Check Node.js version
    log "Running: node -v"
    local node_version=$(node -v)
    log "Node.js version: $node_version"
    
    # Check npm version
    log "Running: npm -v"
    local npm_version=$(npm -v)
    log "npm version: $npm_version"
    
    # Verify both are working
    if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
        log "Node.js and npm verification successful"
        return 0
    else
        log "ERROR: Node.js or npm verification failed"
        return 1
    fi
}

# Step 3: Install Claude using npm without sudo (container environment)
install_claude_via_npm() {
    log "Step 3: Installing Claude Code CLI via npm (without sudo)..."
    
    # Set npm to install globally in user directory to avoid permission issues
    export NPM_CONFIG_PREFIX=/home/mvpuser/.npm-global
    mkdir -p /home/mvpuser/.npm-global
    
    # Add to PATH for this session
    export PATH=/home/mvpuser/.npm-global/bin:$PATH
    
    # Install claude using npm without sudo
    log "Running: npm install -g @anthropic-ai/claude-code"
    npm install -g @anthropic-ai/claude-code
    
    # Make the PATH change permanent
    echo 'export NPM_CONFIG_PREFIX=/home/mvpuser/.npm-global' >> /home/mvpuser/.bashrc
    echo 'export PATH=/home/mvpuser/.npm-global/bin:$PATH' >> /home/mvpuser/.bashrc
}

# Step 4: Check if Claude got installed
verify_claude_installation() {
    log "Step 4: Verifying Claude installation..."
    
    # Check Claude version
    log "Running: claude --version"
    if command -v claude >/dev/null 2>&1; then
        local claude_version=$(claude --version 2>/dev/null || echo "Version check failed")
        log "Claude version: $claude_version"
        log "Claude installation verification successful"
        return 0
    else
        log "ERROR: Claude installation verification failed - command not found"
        return 1
    fi
}

# Step 5: Set necessary environment variables dynamically
setup_claude_environment() {
    log "Step 5: Setting up Claude environment variables..."
    
    # Get API key from AWS Secrets Manager
    if [ -n "${CLAUDE_API_KEY_SECRET:-}" ]; then
        log "Retrieving Claude API key from Secrets Manager..."
        CLAUDE_API_KEY=$(aws secretsmanager get-secret-value \
            --secret-id "$CLAUDE_API_KEY_SECRET" \
            --query SecretString \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$CLAUDE_API_KEY" ]; then
            # Export environment variables
            export ANTHROPIC_API_KEY="$CLAUDE_API_KEY"
            export ANTHROPIC_MODEL="claude-sonnet-4-20250514"
            
            log "Environment variables set:"
            log "ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY:0:20}..."
            log "ANTHROPIC_MODEL: $ANTHROPIC_MODEL"
            
            # Make these available to other scripts
            echo "export ANTHROPIC_API_KEY=\"$CLAUDE_API_KEY\"" >> /home/mvpuser/.bashrc
            echo "export ANTHROPIC_MODEL=\"claude-sonnet-4-20250514\"" >> /home/mvpuser/.bashrc
        else
            log "ERROR: Could not retrieve Claude API key from Secrets Manager"
            return 1
        fi
    else
        log "ERROR: CLAUDE_API_KEY_SECRET environment variable not set"
        return 1
    fi
}

# Step 6: Update Claude permissions
setup_claude_permissions() {
    log "Step 6: Setting up Claude permissions..."
    
    # Create .claude directory in project root if it doesn't exist
    local project_root="/workspace"
    local claude_settings_dir="$project_root/.claude"
    local settings_file="$claude_settings_dir/settings.local.json"
    
    # Create directory
    mkdir -p "$claude_settings_dir"
    
    # Create settings.local.json with bypass permissions
    cat > "$settings_file" << 'EOF'
{
    "permissions": {
        "defaultMode": "bypassPermissions"
    }
}
EOF
    
    log "Created Claude permissions file: $settings_file"
    log "Permissions set to bypass mode"
}

# Download and install Claude Code
install_claude_code() {
    log "Starting Claude Code installation process..."
    
    # Execute all steps in sequence
    install_nodejs_npm
    verify_nodejs_npm
    install_claude_via_npm  
    verify_claude_installation
    setup_claude_environment
    log "Claude Code installation process completed successfully!"
}

# Configure Claude Code (deprecated - now handled in install_claude_code)
configure_claude_code() {
    log "Claude configuration is now handled during installation..."
    return 0
}

# Verify installation
verify_installation() {
    log "Verifying Claude Code installation..."
    
    # Check if claude command is available
    if command -v claude >/dev/null 2>&1; then
        local version=$(claude --version 2>/dev/null || echo "Version check completed")
        log "Claude Code installed successfully: $version"
        
        # Test basic functionality
        log "Claude installation verification completed successfully"
        return 0
    else
        log "ERROR: Claude Code not found in PATH"
        return 1
    fi
}

# Main installation process
main() {
    log "Starting Claude Code installation..."
    
    retry "create_directories"
    retry "install_claude_code"
    retry "configure_claude_code"
    retry "verify_installation"
    
    log "Claude Code installation completed successfully!"
}

# Run main function
main "$@"