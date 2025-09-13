#!/bin/bash

set -euo pipefail

# Build Project Script
# This script builds the MVP project created by the AI_DEVELOPMENT stage

# Configuration
SOURCE_DIR="/workspace/project/apps/web"
BUILD_OUTPUT_DIR="/workspace/build"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"stage\":\"BUILD\",\"message\":\"$message\"}"
}

log_info() {
    log "INFO" "$@"
}

log_error() {
    log "ERROR" "$@"
}

# Main build function
build_project() {
    log_info "Starting project build process"
    log_info "Source directory: $SOURCE_DIR"
    log_info "Build output directory: $BUILD_OUTPUT_DIR"
    
    # Verify source directory exists
    if [ ! -d "$SOURCE_DIR" ]; then
        log_error "Source directory not found: $SOURCE_DIR"
        exit 1
    fi
    
    # Create build output directory
    mkdir -p "$BUILD_OUTPUT_DIR"
    
    # Copy project files to build directory
    log_info "Copying project files to build directory"
    cp -r "$SOURCE_DIR"/* "$BUILD_OUTPUT_DIR"/
    
    # Change to build directory
    cd "$BUILD_OUTPUT_DIR"
    
    # Check if package.json exists
    if [ -f "package.json" ]; then
        log_info "Found package.json, installing dependencies"
        
        # Install dependencies
        if command -v npm >/dev/null 2>&1; then
            npm install --production
            log_info "Dependencies installed successfully"
            
            # Check if build script exists
            if npm run-script --silent 2>/dev/null | grep -q "build"; then
                log_info "Running build script"
                npm run build
                log_info "Build script completed"
            else
                log_info "No build script found in package.json, skipping build step"
            fi
        else
            log_error "npm not found, cannot install dependencies"
            exit 1
        fi
    else
        log_info "No package.json found, skipping dependency installation"
    fi
    
    # Create build manifest
    log_info "Creating build manifest"
    cat > "$BUILD_OUTPUT_DIR/BUILD_MANIFEST.md" << EOF
# Build Manifest

- **Build Date**: $(date)
- **Source Directory**: $SOURCE_DIR
- **Build Directory**: $BUILD_OUTPUT_DIR
- **Status**: SUCCESS

## Files Built
$(find "$BUILD_OUTPUT_DIR" -type f | head -20)

## Build Summary
Project successfully built and ready for deployment.
EOF

    log_info "Build process completed successfully"
    log_info "Build artifacts available in: $BUILD_OUTPUT_DIR"
}

# Error handling
handle_error() {
    local exit_code=$?
    log_error "Build failed with exit code $exit_code"
    exit $exit_code
}

trap 'handle_error' ERR

# Main execution
main() {
    log_info "Build script started"
    build_project
    log_info "Build script completed successfully"
}

# Run main function
main "$@"
