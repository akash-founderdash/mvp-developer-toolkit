#!/bin/bash

set -euo pipefail

# Configuration
SCRIPT_DIR="/app/scripts"
WORKSPACE_DIR="/workspace"
LOG_LEVEL="${LOG_LEVEL:-INFO}"
JOB_ID="${JOB_ID:-${AWS_BATCH_JOB_ID:-$(date +%s)}}"

# Pipeline stages
STAGE_INIT="INIT"
STAGE_FETCH_DATA="FETCHING_DATA"
STAGE_CLONE="CREATING_REPO"
STAGE_CLAUDE_INSTALL="CLAUDE_INSTALL"
STAGE_DEVELOP="AI_DEVELOPMENT"
STAGE_BUILD="BUILDING"
STAGE_DEPLOY="DEPLOYING"
STAGE_NOTIFY="CONFIGURING_DOMAINS"
STAGE_CLEANUP="CLEANUP"

# Global variables
CURRENT_STAGE=""
START_TIME=$(date +%s)
BUSINESS_NAME=""
REPO_NAME=""
USER_EMAIL=""
SANITIZED_NAME=""
USER_ID=""
PRODUCT_ID=""

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"jobId\":\"$JOB_ID\",\"stage\":\"$CURRENT_STAGE\",\"message\":\"$message\"}" >&2
}

log_info() {
    log "INFO" "$@"
}

log_warn() {
    log "WARN" "$@"
}

log_error() {
    log "ERROR" "$@"
}

log_debug() {
    if [ "$LOG_LEVEL" = "DEBUG" ]; then
        log "DEBUG" "$@"
    fi
}

# Error handling
handle_error() {
    local exit_code=$?
    local line_number=$1
    
    local error_message="Pipeline failed at line $line_number with exit code $exit_code in stage $CURRENT_STAGE"
    
    # Handle pipeline failure
    handle_pipeline_failure "$error_message"
    
    # Cleanup
    cleanup_resources
    
    exit $exit_code
}

trap 'handle_error $LINENO' ERR

# Parse command line arguments and environment variables
parse_arguments() {
    CURRENT_STAGE="$STAGE_INIT"
    log_info "Starting FounderDash MVP pipeline execution"
    
    # Parse AWS Batch job parameters - now just need JOB_ID
    if [ -n "${JOB_ID:-}" ]; then
        log_info "Job ID: $JOB_ID"
    else
        log_error "JOB_ID parameter is required"
        exit 1
    fi
    
    # Check required environment variables (these should contain secret names, not values)
    local required_vars=(
        "DYNAMODB_TABLE"
        "COMPLETION_TOPIC"
        "GITHUB_TOKEN_SECRET"
        "VERCEL_TOKEN_SECRET"
        "CLAUDE_API_KEY_SECRET"
    )
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            log_error "Required environment variable $var is not set"
            exit 1
        fi
    done
    
    log_info "Configuration parsed successfully"
}

# Fetch job data from DynamoDB
fetch_job_data() {
    CURRENT_STAGE="$STAGE_FETCH_DATA"
    log_info "Fetching job data from DynamoDB"
    
    # Update status to IN_PROGRESS
    python3 "$SCRIPT_DIR/update-job-status.py" \
        --job-id "$JOB_ID" \
        --status "IN_PROGRESS" \
        --step "$CURRENT_STAGE" \
        --progress 5
    
    # Fetch job data
    python3 "$SCRIPT_DIR/fetch-job-data.py" \
        --job-id "$JOB_ID" \
        --output-dir "$WORKSPACE_DIR"
    
    # Source the environment variables
    if [ -f "$WORKSPACE_DIR/job-env.sh" ]; then
        source "$WORKSPACE_DIR/job-env.sh"
        log_info "Job data loaded: $BUSINESS_NAME"
    else
        log_error "Failed to load job environment variables"
        exit 1
    fi
    
    # Update progress
    python3 "$SCRIPT_DIR/update-job-status.py" \
        --job-id "$JOB_ID" \
        --step "$CURRENT_STAGE" \
        --progress 10
}

# Execute pipeline stage
execute_stage() {
    local stage="$1"
    local script="$2"
    shift 2
    
    CURRENT_STAGE="$stage"
    log_info "Starting stage: $stage"
    
    local stage_start=$(date +%s)
    
    if [ -f "$SCRIPT_DIR/$script" ]; then
        bash "$SCRIPT_DIR/$script" "$@"
        local exit_code=$?
        
        if [ $exit_code -eq 0 ]; then
            local stage_end=$(date +%s)
            local stage_duration=$((stage_end - stage_start))
            log_info "Stage $stage completed successfully in ${stage_duration}s"
        else
            log_error "Stage $stage failed with exit code $exit_code"
            exit $exit_code
        fi
    else
        log_error "Script not found: $SCRIPT_DIR/$script"
        exit 1
    fi
}

# Send SNS completion notification
send_completion_notification() {
    local status="$1"
    local repo_url="$2"
    local deployment_url="$3"
    local staging_url="$4"
    local error_message="$5"
    
    CURRENT_STAGE="$STAGE_NOTIFY"
    log_info "Sending completion notification via SNS"
    
    local end_time=$(date +%s)
    local execution_time=$((end_time - START_TIME))
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    local message=$(cat << EOF
{
    "jobId": "$JOB_ID",
    "userId": "$USER_ID",
    "projectId": "$PRODUCT_ID",
    "businessName": "$BUSINESS_NAME",
    "status": "$status",
    "repoUrl": "$repo_url",
    "productionUrl": "$deployment_url",
    "stagingUrl": "$staging_url",
    "timestamp": "$timestamp",
    "executionTime": $execution_time,
    "batchJobId": "${AWS_BATCH_JOB_ID:-$JOB_ID}"
}
EOF
)
    
    # Add error message if status is failed
    if [ "$status" = "failed" ] && [ -n "$error_message" ]; then
        message=$(echo "$message" | sed 's/}$/,"error":"'"$error_message"'"}/')
    fi
    
    log_info "Publishing to SNS topic: $COMPLETION_TOPIC"
    
    if aws sns publish \
        --topic-arn "$COMPLETION_TOPIC" \
        --message "$message" >/dev/null 2>&1; then
        log_info "Completion notification sent successfully"
    else
        log_warn "Failed to send completion notification"
    fi
}

# Handle pipeline failure
handle_pipeline_failure() {
    local error_message="$1"
    
    log_error "Pipeline failed: $error_message"
    
    # Update job status to failed
    python3 "$SCRIPT_DIR/update-job-status.py" \
        --job-id "$JOB_ID" \
        --status "FAILED" \
        --step "$CURRENT_STAGE" \
        --error "$error_message" || true
    
    # Send failure notification
    send_completion_notification "failed" "" "" "" "$error_message"
}

# Cleanup resources
cleanup_resources() {
    CURRENT_STAGE="$STAGE_CLEANUP"
    log_info "Starting cleanup process"
    
    # Clean up temporary files
    if [ -d "$WORKSPACE_DIR" ]; then
        rm -rf "$WORKSPACE_DIR"/* 2>/dev/null || true
    fi
    
    # Clean up any other temporary resources
    # (Additional cleanup logic can be added here)
    
    log_info "Cleanup completed"
}

# Main pipeline execution
main() {
    log_info "FounderDash MVP Pipeline starting - Job ID: $JOB_ID"
    
    # Parse arguments and fetch job data
    parse_arguments
    fetch_job_data
    
    # Execute pipeline stages
    execute_stage "$STAGE_CLONE" "clone-template.sh"
    execute_stage "$STAGE_CLAUDE_INSTALL" "install-claude.sh"
    execute_stage "$STAGE_DEVELOP" "develop-mvp.sh"
    execute_stage "$STAGE_BUILD" "build-project.sh"
    execute_stage "$STAGE_DEPLOY" "deploy-vercel.sh"
    
    # Get URLs from stage outputs
    local repo_url=""
    local deployment_url=""
    local staging_url=""
    
    if [ -f "$WORKSPACE_DIR/repo_url.txt" ]; then
        repo_url=$(cat "$WORKSPACE_DIR/repo_url.txt")
    fi
    
    if [ -f "$WORKSPACE_DIR/deployment_url.txt" ]; then
        deployment_url=$(cat "$WORKSPACE_DIR/deployment_url.txt")
    fi
    
    if [ -f "$WORKSPACE_DIR/staging_url.txt" ]; then
        staging_url=$(cat "$WORKSPACE_DIR/staging_url.txt")
    fi
    
    # Update final status
    python3 "$SCRIPT_DIR/update-job-status.py" \
        --job-id "$JOB_ID" \
        --status "COMPLETED" \
        --step "COMPLETED" \
        --progress 100 \
        --repo-url "$repo_url" \
        --production-url "$deployment_url" \
        --staging-url "$staging_url"
    
    # Send success notification
    send_completion_notification "completed" "$repo_url" "$deployment_url" "$staging_url" ""
    
    # Final cleanup
    cleanup_resources
    
    local end_time=$(date +%s)
    local total_duration=$((end_time - START_TIME))
    
    log_info "FounderDash MVP Pipeline completed successfully in ${total_duration}s"
    log_info "Business: $BUSINESS_NAME"
    log_info "Repository: $repo_url"
    log_info "Production: $deployment_url"
    log_info "Staging: $staging_url"
}

# Run main function
main "$@"