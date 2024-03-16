resource "aws_s3_bucket" "images" {
  bucket_prefix = "nixos-village-images"
  force_destroy = true
}

output "images_bucket" {
  value = aws_s3_bucket.images.bucket
}

data "aws_iam_policy_document" "assume_vmimport" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vmie.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = ["vmimport"]
    }
  }
}

data "aws_iam_policy_document" "vmimport" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      "${aws_s3_bucket.images.arn}",
      "${aws_s3_bucket.images.arn}/*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "ec2:ModifySnapshotAttribute",
      "ec2:CopySnapshot",
      "ec2:RegisterImage",
      "ec2:Describe*"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "vmimport" {
  name   = "vmimport"
  policy = data.aws_iam_policy_document.vmimport.json
}

resource "aws_iam_role" "vmimport" {
  name                = "vmimport"
  assume_role_policy  = data.aws_iam_policy_document.assume_vmimport.json
  inline_policy {
    name   = "vmimport"
    policy = data.aws_iam_policy_document.vmimport.json
  }
}

import {
  to = aws_iam_role.vmimport
  id = "vmimport"
}


/*
# From: https://hydra.nixos.org/job/nixos/unstable-small/nixos.amazonImage.aarch64-linux
# TODO: automate this?
locals {
  name  = basename(local.image)
  image = "/nix/store/bvi0ylv3xgabwlk337bfykavnhrfxpzm-nixos-amazon-image-23.11.20240314.878ef7d-x86_64-linux/nixos-amazon-image-23.11.20240314.878ef7d-x86_64-linux.vhd"
}

resource "aws_s3_object" "image" {
  bucket = aws_s3_bucket.images.bucket
  key    = local.name
  source = local.image
}

resource "aws_ebs_snapshot_import" "image" {
  disk_container {
    format = "VHD"
    user_bucket {
      s3_bucket = aws_s3_bucket.images.bucket
      s3_key    = aws_s3_object.image.key
    }
  }
  role_name = aws_iam_role.vmimport.name
}

resource "aws_ami" "image" {
  name                = local.name
  virtualization_type = "hvm"
  architecture        = "x86_64"
  boot_mode           = "legacy-bios"
  imds_support        = "v2.0"
  ena_support         = true
  sriov_net_support   = "simple"
  root_device_name    = "/dev/xvda"

  ebs_block_device {
    device_name = "/dev/xvda"
    snapshot_id = aws_ebs_snapshot_import.image.id
  }
}*/
