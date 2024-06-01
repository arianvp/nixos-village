#!/usr/bin/env bash
set -e
set -x

action='{{ action }}'
installable='{{ installable }}'
profile='{{ profile }}'
substituters='{{ substituters }}'
trustedPublicKeys='{{ trustedPublicKeys }}'

nixStorePath=$(/run/current-system/sw/bin/nix build \
  --extra-experimental-features 'nix-command flakes' \
  --extra-trusted-public-keys "$trustedPublicKeys" \
  --extra-substituters "$substituters" \
  --print-out-paths \
  --refresh \
  "$installable")

if [ "$(/run/current-system/sw/bin/readlink /run/current-system)" == "$(/run/current-system/sw/bin/readlink ./result)" ]; then
  echo "Already booted into the desired configuration"
  exit 0
fi


/run/wrappers/bin/sudo /run/current-system/sw/bin/nix-env --profile "$profile" --set "$nixStorePath"

if [ "$action" == "switch" ]; then
  /run/wrappers/bin/sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
elif [ "$action" == "reboot" ]; then
  /run/wrappers/bin/sudo /nix/var/nix/profiles/system/bin/switch-to-configuration boot
  #  Signals SSM to reboot the instance https://docs.aws.amazon.com/systems-manager/latest/userguide/send-commands-reboot.html
  exit 194
fi