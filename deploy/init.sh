#!/usr/bin/env bash

set -euo pipefail
set -x


tofu init \
    -backend-config="bucket=$(cd terraform-state; tofu output -raw bucket)" \
    -backend-config="region=$(cd terraform-state; tofu output -raw region)" \
    -backend-config="dynamodb_table=$(cd terraform-state; tofu output -raw dynamodb_table)" \
    "$@"
