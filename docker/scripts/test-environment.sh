#!/bin/bash

# Container Environment Test Script
# This script tests the Docker container environment and dependencies

set -euo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}

log "Starting container environment test..."

# Test 1: Check basic commands
log "Testing basic commands..."
which bash || { log_error "bash not found"; exit 1; }
which curl || { log_error "curl not found"; exit 1; }
which git || { log_error "git not found"; exit 1; }

# Test 2: Check Node.js and npm
log "Testing Node.js environment..."
node --version || { log_error "Node.js not found"; exit 1; }
npm --version || { log_error "npm not found"; exit 1; }

# Test 3: Check Python environment
log "Testing Python environment..."
python3 --version || { log_error "Python3 not found"; exit 1; }
pip3 --version || { log_error "pip3 not found"; exit 1; }

# Test 4: Check workspace directories
log "Testing workspace structure..."
ls -la /workspace/ || { log_error "Workspace directory not accessible"; exit 1; }

# Test 5: Check script availability
log "Testing script availability..."
ls -la /app/scripts/ || { log_error "Scripts directory not found"; exit 1; }

# Test 6: Check environment variables
log "Testing environment variables..."
echo "LOG_LEVEL: ${LOG_LEVEL:-not set}"
echo "AWS_DEFAULT_REGION: ${AWS_DEFAULT_REGION:-not set}"

# Test 7: Test script execution permissions
log "Testing script permissions..."
for script in /app/scripts/*.sh; do
    if [ -f "$script" ]; then
        if [ ! -x "$script" ]; then
            log_error "Script not executable: $script"
            exit 1
        fi
    fi
done

# Test 8: Test Claude installation (mock)
log "Testing Claude installation capability..."
# This would normally test if Claude can be installed
# For now, just check if the installation script exists
if [ -f "/app/scripts/install-claude.sh" ]; then
    log "Claude installation script found"
else
    log_error "Claude installation script not found"
fi

log "All environment tests passed successfully!"

# If running interactively, show some useful information
if [ -t 0 ]; then
    echo
    echo "=== Container Environment Information ==="
    echo "Operating System: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo "Node.js Version: $(node --version)"
    echo "npm Version: $(npm --version)"
    echo "Python Version: $(python3 --version)"
    echo "Git Version: $(git --version)"
    echo "Working Directory: $(pwd)"
    echo "Available Scripts:"
    ls -1 /app/scripts/*.sh | sed 's/^/  /'
    echo
fi
