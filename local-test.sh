#!/bin/bash

# Local Docker Testing Script for MVP Pipeline
# This script allows you to test the batch container locally before deploying

set -euo pipefail

# Configuration
CONTAINER_NAME="mvp-pipeline-local-test"
IMAGE_NAME="mvp-pipeline"
LOCAL_WORKSPACE_DIR="$(pwd)/test-workspace"
TEST_REPO_URL="https://github.com/akash-founderdash/event-engagement-toolkit.git"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Clean up function
cleanup() {
    log_info "Cleaning up test environment..."
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
    if [ -d "$LOCAL_WORKSPACE_DIR" ]; then
        log_info "Removing test workspace directory"
        rm -rf "$LOCAL_WORKSPACE_DIR"
    fi
}

# Setup test environment
setup_test_environment() {
    log_info "Setting up local test environment"
    
    # Clean up any existing test environment
    cleanup
    
    # Create test workspace directory
    mkdir -p "$LOCAL_WORKSPACE_DIR"
    
    # Create test directories structure
    mkdir -p "$LOCAL_WORKSPACE_DIR/source"
    mkdir -p "$LOCAL_WORKSPACE_DIR/mvp"
    mkdir -p "$LOCAL_WORKSPACE_DIR/secrets"
    
    log_success "Test environment created at: $LOCAL_WORKSPACE_DIR"
}

# Build Docker image locally
build_image() {
    log_info "Building Docker image locally..."
    
    cd docker
    if docker build -t "$IMAGE_NAME:test" .; then
        log_success "Docker image built successfully"
    else
        log_error "Failed to build Docker image"
        return 1
    fi
    cd ..
}

# Test individual stages
test_stage() {
    local stage="$1"
    shift
    local args=("$@")
    
    log_info "Testing stage: $stage"
    
    # Environment variables for the container
    local env_vars=(
        "-e" "GITHUB_TOKEN=test_token"
        "-e" "AWS_ACCESS_KEY_ID=test_key"
        "-e" "AWS_SECRET_ACCESS_KEY=test_secret"
        "-e" "AWS_DEFAULT_REGION=us-east-2"
        "-e" "LOG_LEVEL=DEBUG"
    )
    
    # Mount the test workspace
    local mount_args=(
        "-v" "$LOCAL_WORKSPACE_DIR:/workspace"
        "-v" "$(pwd)/docker/scripts:/app/scripts:ro"
    )
    
    # Run the container with the pipeline script
    docker run --rm \
        --name "$CONTAINER_NAME-$stage" \
        "${env_vars[@]}" \
        "${mount_args[@]}" \
        "$IMAGE_NAME:test" \
        bash /app/pipeline.sh "$stage" "${args[@]}"
}

# Test clone template stage (mocked)
test_clone_template() {
    log_info "Testing CLONE_TEMPLATE stage (mocked)"
    
    # Create mock source content
    cat > "$LOCAL_WORKSPACE_DIR/source/package.json" << 'EOF'
{
  "name": "event-engagement-toolkit",
  "version": "1.0.0",
  "scripts": {
    "build": "next build",
    "dev": "next dev",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "next": "^13.0.0",
    "react": "^18.0.0",
    "react-dom": "^18.0.0"
  }
}
EOF

    cat > "$LOCAL_WORKSPACE_DIR/source/next.config.js" << 'EOF'
/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    appDir: true,
  },
}

module.exports = nextConfig
EOF

    mkdir -p "$LOCAL_WORKSPACE_DIR/source/apps/web/src/app"
    cat > "$LOCAL_WORKSPACE_DIR/source/apps/web/src/app/page.tsx" << 'EOF'
export default function Page() {
  return (
    <div>
      <h1>Test MVP Application</h1>
      <p>This is a test application for local container testing.</p>
    </div>
  )
}
EOF

    log_success "Mock source code created in workspace"
}

# Test environment validation
test_environment() {
    log_info "Testing container environment"
    
    # Environment variables for the container
    local env_vars=(
        "-e" "LOG_LEVEL=DEBUG"
    )
    
    # Mount the test workspace
    local mount_args=(
        "-v" "$LOCAL_WORKSPACE_DIR:/workspace"
        "-v" "$(pwd)/docker/scripts:/app/scripts:ro"
    )
    
    # Run the environment test script
    docker run --rm \
        --name "$CONTAINER_NAME-env-test" \
        "${env_vars[@]}" \
        "${mount_args[@]}" \
        "$IMAGE_NAME:test" \
        bash /app/scripts/test-environment.sh
}

# Test develop MVP stage
test_develop_mvp() {
    log_info "Testing AI_DEVELOPMENT stage"
    
    test_stage "AI_DEVELOPMENT" "Test MVP" "A test MVP application" "Basic web application"
}

# Test complete pipeline
test_full_pipeline() {
    log_info "Testing complete pipeline locally"
    
    setup_test_environment
    test_clone_template
    test_develop_mvp
    
    log_success "Full pipeline test completed"
    
    # Show results
    if [ -d "$LOCAL_WORKSPACE_DIR/mvp" ]; then
        log_info "Generated MVP content:"
        ls -la "$LOCAL_WORKSPACE_DIR/mvp/"
        
        if [ -f "$LOCAL_WORKSPACE_DIR/mvp/DEVELOPMENT_SUMMARY.md" ]; then
            log_info "Development summary:"
            cat "$LOCAL_WORKSPACE_DIR/mvp/DEVELOPMENT_SUMMARY.md"
        fi
    fi
}

# Interactive testing menu
interactive_test() {
    while true; do
        echo
        echo "=== MVP Pipeline Local Testing ==="
        echo "1) Build Docker image"
        echo "2) Test container environment"
        echo "3) Test CLONE_TEMPLATE stage (mocked)"
        echo "4) Test AI_DEVELOPMENT stage"
        echo "5) Test full pipeline"
        echo "6) Cleanup test environment"
        echo "7) Show test workspace content"
        echo "8) Enter container for debugging"
        echo "9) Exit"
        echo
        read -p "Select option (1-9): " choice
        
        case $choice in
            1)
                build_image
                ;;
            2)
                setup_test_environment
                test_environment
                ;;
            3)
                setup_test_environment
                test_clone_template
                ;;
            4)
                if [ ! -d "$LOCAL_WORKSPACE_DIR/source" ] || [ -z "$(ls -A "$LOCAL_WORKSPACE_DIR/source" 2>/dev/null)" ]; then
                    log_warning "Source directory is empty. Running mock clone template first..."
                    setup_test_environment
                    test_clone_template
                fi
                test_develop_mvp
                ;;
            5)
                test_full_pipeline
                ;;
            6)
                cleanup
                ;;
            7)
                if [ -d "$LOCAL_WORKSPACE_DIR" ]; then
                    log_info "Test workspace content:"
                    find "$LOCAL_WORKSPACE_DIR" -type f | head -20
                else
                    log_warning "Test workspace not found. Run setup first."
                fi
                ;;
            8)
                log_info "Entering container for debugging..."
                docker run -it --rm \
                    -v "$LOCAL_WORKSPACE_DIR:/workspace" \
                    -v "$(pwd)/docker/scripts:/app/scripts:ro" \
                    -e "LOG_LEVEL=DEBUG" \
                    "$IMAGE_NAME:test" \
                    /bin/bash
                ;;
            9)
                cleanup
                log_success "Goodbye!"
                exit 0
                ;;
            *)
                log_error "Invalid option. Please select 1-9."
                ;;
        esac
    done
}

# Main function
main() {
    log_info "MVP Pipeline Local Testing Script"
    log_info "This script helps you test the Docker container locally before deployment"
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check if we're in the right directory
    if [ ! -f "docker/Dockerfile" ]; then
        log_error "Please run this script from the mvp-developer-toolkit root directory"
        exit 1
    fi
    
    # Handle command line arguments
    case "${1:-interactive}" in
        "build")
            build_image
            ;;
        "test-clone")
            setup_test_environment
            test_clone_template
            ;;
        "test-develop")
            setup_test_environment
            test_clone_template
            test_develop_mvp
            ;;
        "test-full")
            test_full_pipeline
            ;;
        "cleanup")
            cleanup
            ;;
        "interactive"|"")
            interactive_test
            ;;
        *)
            echo "Usage: $0 [build|test-clone|test-develop|test-full|cleanup|interactive]"
            echo "  build         - Build Docker image locally"
            echo "  test-clone    - Test clone template stage (mocked)"
            echo "  test-develop  - Test AI development stage"
            echo "  test-full     - Test complete pipeline"
            echo "  cleanup       - Clean up test environment"
            echo "  interactive   - Interactive testing menu (default)"
            ;;
    esac
}

# Trap cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"
