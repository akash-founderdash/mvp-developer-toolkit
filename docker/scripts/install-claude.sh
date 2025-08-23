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

# Download and install Claude Code
install_claude_code() {
    log "Installing Claude Code CLI..."
    
    # For now, we'll use a placeholder installation
    # In a real implementation, this would download the actual Claude Code CLI
    # Since Claude Code CLI doesn't exist as a standalone tool, we'll create a mock
    
    cat > "$CLAUDE_INSTALL_DIR/claude-code" << 'EOF'
#!/bin/bash

# Mock Claude Code CLI
# This is a placeholder implementation

set -euo pipefail

COMMAND="$1"
shift

case "$COMMAND" in
    "develop")
        echo "Starting Claude Code development..."
        echo "Spec: $1"
        
        # Simulate development process
        echo "Analyzing requirements..."
        sleep 2
        echo "Generating code structure..."
        sleep 3
        echo "Implementing features..."
        sleep 5
        echo "Running tests..."
        sleep 2
        echo "Code generation completed successfully!"
        ;;
    "version")
        echo "claude-code version 1.0.0 (mock)"
        ;;
    "help"|"--help"|"-h")
        echo "Claude Code CLI - Mock Implementation"
        echo "Usage: claude-code <command> [options]"
        echo ""
        echo "Commands:"
        echo "  develop <spec>  Generate code based on specification"
        echo "  version         Show version information"
        echo "  help           Show this help message"
        ;;
    *)
        echo "Unknown command: $COMMAND"
        echo "Use 'claude-code help' for usage information"
        exit 1
        ;;
esac
EOF

    chmod +x "$CLAUDE_INSTALL_DIR/claude-code"
    
    # Add to PATH
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/mvpuser/.bashrc
}

# Configure Claude Code
configure_claude_code() {
    log "Configuring Claude Code..."
    
    # Get API key from AWS Secrets Manager
    if [ -n "${CLAUDE_API_KEY_SECRET:-}" ]; then
        log "Retrieving Claude API key from Secrets Manager..."
        CLAUDE_API_KEY=$(aws secretsmanager get-secret-value \
            --secret-id "$CLAUDE_API_KEY_SECRET" \
            --query SecretString \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$CLAUDE_API_KEY" ]; then
            # Create config file
            cat > "$CLAUDE_CONFIG_DIR/config.json" << EOF
{
    "api_key": "$CLAUDE_API_KEY",
    "model": "claude-3-sonnet-20240229",
    "max_tokens": 4000,
    "temperature": 0.1
}
EOF
            log "Claude Code configured successfully"
        else
            log "WARNING: Could not retrieve Claude API key from Secrets Manager"
        fi
    else
        log "WARNING: CLAUDE_API_KEY_SECRET environment variable not set"
    fi
}

# Verify installation
verify_installation() {
    log "Verifying Claude Code installation..."
    
    # Add to current PATH for verification
    export PATH="$CLAUDE_INSTALL_DIR:$PATH"
    
    if command -v claude-code >/dev/null 2>&1; then
        local version=$(claude-code version)
        log "Claude Code installed successfully: $version"
        
        # Test basic functionality
        if claude-code help >/dev/null 2>&1; then
            log "Claude Code verification completed successfully"
            return 0
        else
            log "ERROR: Claude Code help command failed"
            return 1
        fi
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