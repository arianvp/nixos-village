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
  managed_policy_arns = [aws_iam_policy.vmimport.arn]
}


# From: https://hydra.nixos.org/job/nixos/unstable-small/nixos.amazonImage.aarch64-linux
# TODO: automate this?
locals {
  image = "/nix/store/wmpnqy2msn8jagvhf1kk4b4jj2xyzaxv-nixos-amazon-image-23.11pre521711.3f9e803102d4-aarch64-linux/nixos-amazon-image-23.11pre521711.3f9e803102d4-aarch64-linux.vhd"
  name  = basename(local.image)
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
  architecture        = "arm64"
  boot_mode           = "uefi"
  imds_support        = "v2.0"
  ena_support         = true
  sriov_net_support   = "simple"
  root_device_name    = "/dev/xvda"

  ebs_block_device {
    device_name = "/dev/xvda"
    snapshot_id = aws_ebs_snapshot_import.image.id
  }
}
