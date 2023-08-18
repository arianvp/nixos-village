#!/usr/bin/env bash

set -euo pipefail
set -x

export TF_VAR_nix_closure=$(nix build .#nixosConfigurations.webserver.config.system.build.toplevel --print-out-paths)
nix copy --to 's3://nixos-village-cache20230817114020926200000001?region=eu-central-1&secret-key=cache.key' $TF_VAR_nix_closure
terraform plan -out=plan.out
terraform apply plan.out