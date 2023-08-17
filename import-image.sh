#!/usr/bin/env bash


aws ec2 import-snapshot \
    --disk-container "Description=NixOS 20.09,Format=raw,UserBucket={S3Bucket=nixos-20-09-import,S3Key=nixos-20-09.img}" \  


aws ec2 wait snapshot-imported --import-task-ids import-snap-0a0a0a0a0a0a0a0a0