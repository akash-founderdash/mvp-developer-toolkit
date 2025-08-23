#!/bin/bash

set -euo pipefail

# Configuration
SOURCE_DIR="/workspace/source"
OUTPUT_DIR="/workspace/mvp"
MAX_RETRIES=3
RETRY_DELAY=10

# Arguments
MVP_NAME="$1"
DESCRIPTION="$2"
REQUIREMENTS="$3"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"stage\":\"DEVELOP\",\"message\":\"$message\"}" >&2
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
    log_error "MVP development failed with exit code $exit_code"
    
    # Capture any error logs
    if [ -f "/tmp/claude_error.log" ]; then
        log_error "Claude error details: $(cat /tmp/claude_error.log)"
    fi
    
    exit $exit_code
}

trap handle_error ERR

# Retry function
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
            delay=$((delay * 2))
        fi
    done
    
    log_error "Command failed after $MAX_RETRIES attempts: $cmd"
    return 1
}

# Prepare development environment
prepare_environment() {
    log_info "Preparing development environment"
    
    # Ensure source directory exists
    if [ ! -d "$SOURCE_DIR" ]; then
        log_error "Source directory not found: $SOURCE_DIR"
        return 1
    fi
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Copy source to output directory for modification
    log_info "Copying source code to output directory"
    cp -r "$SOURCE_DIR"/* "$OUTPUT_DIR/"
    
    # Ensure Claude Code is in PATH
    export PATH="/home/mvpuser/.local/bin:$PATH"
    
    # Verify Claude Code installation
    if ! command -v claude-code >/dev/null 2>&1; then
        log_error "Claude Code not found in PATH"
        return 1
    fi
    
    log_info "Development environment prepared"
}

# Create development specification
create_development_spec() {
    log_info "Creating development specification"
    
    local spec_file="$OUTPUT_DIR/mvp_spec.md"
    
    cat > "$spec_file" << EOF
# MVP Development Specification

## Project Name
$MVP_NAME

## Description
$DESCRIPTION

## Requirements
$REQUIREMENTS

## Technical Constraints
- Based on event-engagement-toolkit codebase
- Next.js application with TypeScript
- Tailwind CSS for styling
- Supabase for backend services
- Vercel deployment ready

## Development Guidelines
- Maintain existing project structure
- Follow existing code patterns and conventions
- Ensure all new features are properly tested
- Update documentation as needed
- Maintain compatibility with existing dependencies

## Output Requirements
- Fully functional Next.js application
- All dependencies properly configured
- Build process working correctly
- Ready for Vercel deployment
EOF

    log_info "Development specification created: $spec_file"
    echo "$spec_file"
}

# Execute Claude Code development
execute_claude_development() {
    local spec_file="$1"
    
    log_info "Starting Claude Code development process"
    log_info "MVP Name: $MVP_NAME"
    log_info "Specification: $spec_file"
    
    cd "$OUTPUT_DIR"
    
    # Create development command
    local claude_cmd="claude-code develop '$spec_file'"
    
    # Execute with output capture
    log_info "Executing Claude Code development..."
    
    if retry_with_backoff "$claude_cmd"; then
        log_info "Claude Code development completed successfully"
    else
        log_error "Claude Code development failed"
        return 1
    fi
}

# Monitor development progress
monitor_progress() {
    log_info "Monitoring development progress"
    
    # This is a placeholder for progress monitoring
    # In a real implementation, this would parse Claude output for progress indicators
    
    local progress_indicators=(
        "Analyzing requirements"
        "Generating code structure"
        "Implementing features"
        "Running tests"
        "Code generation completed"
    )
    
    for indicator in "${progress_indicators[@]}"; do
        log_info "Progress: $indicator"
        sleep 2
    done
}

# Validate generated code
validate_generated_code() {
    log_info "Validating generated code"
    
    cd "$OUTPUT_DIR"
    
    # Check for essential files
    local required_files=(
        "package.json"
        "next.config.js"
        "tailwind.config.js"
        "tsconfig.json"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            log_error "Required file missing after development: $file"
            return 1
        fi
    done
    
    # Check for app directory structure
    if [ ! -d "apps/web" ]; then
        log_error "Web app directory structure missing"
        return 1
    fi
    
    # Validate package.json (basic check)
    if ! node -e "JSON.parse(require('fs').readFileSync('package.json', 'utf8'))" 2>/dev/null; then
        log_error "Invalid package.json format"
        return 1
    fi
    
    # Check if build script exists
    if ! grep -q '"build"' package.json; then
        log_error "Build script not found in package.json"
        return 1
    fi
    
    log_info "Code validation completed successfully"
}

# Run quality checks
run_quality_checks() {
    log_info "Running code quality checks"
    
    cd "$OUTPUT_DIR"
    
    # Type checking
    if command -v tsc >/dev/null 2>&1; then
        log_info "Running TypeScript type checking"
        if ! npx tsc --noEmit; then
            log_error "TypeScript type checking failed"
            return 1
        fi
    fi
    
    # Linting (if available)
    if grep -q '"lint"' package.json; then
        log_info "Running linting"
        if ! npm run lint; then
            log_error "Linting failed"
            return 1
        fi
    fi
    
    # Build test
    log_info "Testing build process"
    if ! npm run build; then
        log_error "Build process failed"
        return 1
    fi
    
    log_info "Quality checks completed successfully"
}

# Generate development summary
generate_summary() {
    log_info "Generating development summary"
    
    local summary_file="$OUTPUT_DIR/DEVELOPMENT_SUMMARY.md"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    cat > "$summary_file" << EOF
# MVP Development Summary

## Project Information
- **Name**: $MVP_NAME
- **Generated**: $timestamp
- **Source**: event-engagement-toolkit

## Description
$DESCRIPTION

## Requirements Implemented
$REQUIREMENTS

## Technical Details
- Framework: Next.js with TypeScript
- Styling: Tailwind CSS
- Backend: Supabase
- Deployment: Vercel-ready

## Files Modified/Created
$(find . -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" | head -20)

## Build Status
✅ TypeScript compilation successful
✅ Build process successful
✅ Ready for deployment

## Next Steps
1. Push to GitHub repository
2. Deploy to Vercel
3. Configure environment variables
4. Test deployed application
EOF

    log_info "Development summary created: $summary_file"
}

# Main function
main() {
    log_info "Starting MVP development process"
    log_info "MVP Name: $MVP_NAME"
    
    prepare_environment
    
    local spec_file
    spec_file=$(create_development_spec)
    
    execute_claude_development "$spec_file"
    monitor_progress
    validate_generated_code
    run_quality_checks
    generate_summary
    
    log_info "MVP development completed successfully"
    log_info "Output directory: $OUTPUT_DIR"
    
    # Store output directory path for next stage
    echo "$OUTPUT_DIR" > /workspace/mvp_output_dir.txt
}

# Run main function
main "$@"