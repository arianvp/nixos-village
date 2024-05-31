#!/usr/bin/env bash

action='{{ action }}'
installable='{{ installable }}'
profile='{{ profile }}'
substituters='{{ substituters }}'
trustedPublicKeys='{{ trustedPublicKeys }}'

if [ "$action" == "boot" ] && [ "$(/run/current-system/sw/bin/readlink /run/current-system)" == "$nixStorePath" ]; then
  echo "Already booted into the desired configuration"
  exit 0
fi

nixStorePath=$(/run/current-system/sw/bin/nix build \
  --extra-experimental-features 'nix-command flakes' \
  --extra-trusted-public-keys "$trustedPublicKeys" \
  --extra-substituters "$substituters" \
  --print-out-paths \
  "$installable")

/run/wrappers/bin/sudo /run/current-system/sw/bin/nix-env --profile "$profile" --set "$nixStorePath"

if [ "$action" == "switch" ]; then
  sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
elif [ "$action" == "reboot" ]; then
  sudo /nix/var/nix/profiles/system/bin/switch-to-configuration boot
  #  Signals SSM to reboot the instance https://docs.aws.amazon.com/systems-manager/latest/userguide/send-commands-reboot.html
  exit 194
fi