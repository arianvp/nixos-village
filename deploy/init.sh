#!/usr/bin/env bash

set -euo pipefail
set -x


terraform init \
    -backend-config="bucket=$(cd terraform-state; terraform output -raw bucket)" \
    -backend-config="region=$(cd terraform-state; terraform output -raw region)" \
    -backend-config="dynamodb_table=$(cd terraform-state; terraform output -raw dynamodb_table)" \
    "$@"
