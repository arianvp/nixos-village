#!/usr/bin/env bash

action='{{ action }}'
installable='{{ installable }}'
profile='{{ profile }}'
substituter='{{ substituter }}'
trustedPublicKey='{{ trustedPublicKey }}'

if [ "$action" == "boot" ] && [ "$(readlink /run/current-system)" == "$nixStorePath" ]; then
  echo "Already booted into the desired configuration"
  exit 0
fi

nixStorePath=$(nix build \
  --extra-experimental-features 'nix-commmand flakes' \
  --extra-trusted-public-keys "$trustedPublicKey" \
  --extra-subsituters "$substituter" \
  --print-out-path \
  "$installable")

sudo nix-env --profile "$profile" --set "$nixStorePath"

if [ "$action" == "switch" ]; then
  sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
elif [ "$action" == "reboot" ]; then
  sudo /nix/var/nix/profiles/system/bin/switch-to-configuration boot
  #  Signals SSM to reboot the instance https://docs.aws.amazon.com/systems-manager/latest/userguide/send-commands-reboot.html
  exit 194
fi