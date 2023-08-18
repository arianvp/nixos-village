#!/usr/bin/env bash

set -euo pipefail

function get_target_state {
    curl -sSf http://169.254.169.254/latest/meta-data/autoscaling/target-lifecycle-state
}

function complete_lifecycle_action {
    instance_id=$(curl -sSf http://169.254.169.254/latest/meta-data/instance-id)
    group_name=$(curl -sSf http://169.254.169.254/latest/meta-data/tags/instance/aws:autoscaling:groupName)
    region=$(curl -sSf http://169.254.169.254/latest/meta-data/placement/region)

    aws autoscaling complete-lifecycle-action \
    --lifecycle-hook-name launching \
    --auto-scaling-group-name "$group_name" \
    --lifecycle-action-result CONTINUE \
    --instance-id "$instance_id" \
    --region "$region"
}

function main {
    while true
    do
        target_state=$(get_target_state)
        if [ "$target_state" = "InService" ]
        then
            complete_lifecycle_action
            break
        fi
        sleep 5
    done
}

main