#!/bin/bash

# Script to update EventBridge targets with latest job definition revision
set -euo pipefail

# Configuration
REGION="${AWS_DEFAULT_REGION:-us-east-2}"
EVENT_BUS_NAME="${EVENTBRIDGE_BUS_NAME:-mvp-development}"
RULE_NAME="${RULE_NAME:-mvp-pipeline-development-rule}"
JOB_DEFINITION_NAME="${JOB_DEFINITION_NAME:-mvp-pipeline-job-definition}"
JOB_QUEUE_ARN="${JOB_QUEUE_ARN:-arn:aws:batch:us-east-2:077075375386:job-queue/mvp-pipeline-job-queue}"
EVENTBRIDGE_ROLE_ARN="${EVENTBRIDGE_ROLE_ARN:-arn:aws:iam::077075375386:role/mvp-pipeline-eventbridge-role}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}ℹ️  $*${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $*${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $*${NC}"
}

log_error() {
    echo -e "${RED}❌ $*${NC}"
}

# Get current active job definition revision
get_current_revision() {
    local revision
    revision=$(aws batch describe-job-definitions \
        --job-definition-name "$JOB_DEFINITION_NAME" \
        --status ACTIVE \
        --region "$REGION" \
        --query 'jobDefinitions[0].revision' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$revision" ] || [ "$revision" = "None" ]; then
        log_error "Could not find active job definition: $JOB_DEFINITION_NAME"
        return 1
    fi
    
    echo "$revision"
}

# Get current EventBridge target job definition
get_eventbridge_target_revision() {
    local job_def
    job_def=$(aws events list-targets-by-rule \
        --rule "$RULE_NAME" \
        --event-bus-name "$EVENT_BUS_NAME" \
        --region "$REGION" \
        --query 'Targets[0].BatchParameters.JobDefinition' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$job_def" ] || [ "$job_def" = "None" ]; then
        log_error "Could not find EventBridge target job definition"
        return 1
    fi
    
    # Extract revision number if present
    if [[ "$job_def" == *":"* ]]; then
        echo "${job_def##*:}"
    else
        echo "unknown"
    fi
}

# Update EventBridge target with new job definition revision
update_eventbridge_target() {
    local new_revision="$1"
    local job_def_with_revision="${JOB_DEFINITION_NAME}:${new_revision}"
    
    log_info "Updating EventBridge target to use job definition: $job_def_with_revision"
    
    # Create the target configuration
    local target_config='[
        {
            "Id": "BatchJobTarget",
            "Arn": "'$JOB_QUEUE_ARN'",
            "BatchParameters": {
                "JobName": "mvp-pipeline-job",
                "JobDefinition": "'$job_def_with_revision'"
            },
            "RoleArn": "'$EVENTBRIDGE_ROLE_ARN'",
            "InputTransformer": {
                "InputPathsMap": {
                    "jobId": "$.detail.jobId"
                },
                "InputTemplate": "{\"Parameters\":{\"JOB_ID\":\"<jobId>\"}}"
            }
        }
    ]'
    
    # Update the target
    if aws events put-targets \
        --rule "$RULE_NAME" \
        --event-bus-name "$EVENT_BUS_NAME" \
        --targets "$target_config" \
        --region "$REGION" >/dev/null 2>&1; then
        
        log_success "EventBridge target updated successfully"
        return 0
    else
        log_error "Failed to update EventBridge target"
        return 1
    fi
}

# Verify the update
verify_update() {
    local expected_revision="$1"
    
    log_info "Verifying EventBridge target update..."
    
    local actual_revision
    actual_revision=$(get_eventbridge_target_revision)
    
    if [ "$actual_revision" = "$expected_revision" ]; then
        log_success "Verification passed: EventBridge target is using revision $actual_revision"
        return 0
    else
        log_error "Verification failed: Expected revision $expected_revision, but got $actual_revision"
        return 1
    fi
}

# Main function
main() {
    echo -e "${BLUE}EventBridge Target Updater${NC}"
    echo -e "${BLUE}=========================${NC}"
    echo ""
    echo "Configuration:"
    echo "  Region: $REGION"
    echo "  Event Bus: $EVENT_BUS_NAME"
    echo "  Rule: $RULE_NAME"
    echo "  Job Definition: $JOB_DEFINITION_NAME"
    echo ""
    
    # Get current job definition revision
    log_info "Getting current active job definition revision..."
    local current_revision
    if ! current_revision=$(get_current_revision); then
        exit 1
    fi
    log_success "Current active job definition revision: $current_revision"
    
    # Get current EventBridge target revision
    log_info "Getting current EventBridge target job definition..."
    local target_revision
    if ! target_revision=$(get_eventbridge_target_revision); then
        exit 1
    fi
    log_success "Current EventBridge target revision: $target_revision"
    
    # Check if update is needed
    if [ "$current_revision" = "$target_revision" ]; then
        log_success "EventBridge target is already up to date (revision $current_revision)"
        echo ""
        echo "No action needed."
        exit 0
    fi
    
    log_warning "EventBridge target needs update:"
    echo "  Current: revision $target_revision"
    echo "  Latest:  revision $current_revision"
    echo ""
    
    # Update the target
    if update_eventbridge_target "$current_revision"; then
        if verify_update "$current_revision"; then
            log_success "EventBridge target successfully updated to revision $current_revision"
        else
            exit 1
        fi
    else
        exit 1
    fi
    
    echo ""
    log_success "Update complete! EventBridge will now use the latest job definition."
}

# Check if script is being run directly or sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
