#!/usr/bin/env bash
set -e

profile='{{ profile }}'


/run/wrappers/bin/sudo /run/current-system/sw/bin/nix-env --profile "$profile" --rollback

/run/wrappers/bin/sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch