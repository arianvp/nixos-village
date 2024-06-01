
#!/usr/bin/env bash
set -e

action='{{ action }}'
profile='{{ profile }}'


/run/wrappers/bin/sudo /run/current-system/sw/bin/nix-env --profile "$profile" --rollback

if [ "$action" == "switch" ]; then
  /run/wrappers/bin/sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
elif [ "$action" == "reboot" ]; then
  /run/wrappers/bin/sudo /nix/var/nix/profiles/system/bin/switch-to-configuration boot
  #  Signals SSM to reboot the instance https://docs.aws.amazon.com/systems-manager/latest/userguide/send-commands-reboot.html
  exit 194
fi