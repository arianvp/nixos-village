#!/usr/bin/env bash
set -e

action='{{ action }}'
installable='{{ installable }}'
profile='{{ profile }}'
substituters='{{ substituters }}'
trustedPublicKeys='{{ trustedPublicKeys }}'

/run/current-system/sw/bin/nix build \
  --extra-experimental-features 'nix-command flakes' \
  --extra-trusted-public-keys "$trustedPublicKeys" \
  --extra-substituters "$substituters" \
  --refresh \
  --profile "$profile" \
  "$installable"

if [ "$(/run/current-system/sw/bin/readlink /run/current-system)" == "$(/run/current-system/sw/bin/readlink "$profile")" ]; then
  echo "Already booted into the desired configuration"
  exit 0
fi

if [ "$action" == "reboot" ]; then
  action="boot"
  do_reboot=1
fi

/run/wrappers/bin/sudo "$profile/bin/switch-to-configuration" "$action"

if [ "$do_reboot" == 1 ]; then
  exit 194
fi