# Nixos on AWS

## Introduction

* I maintain a large cluster of NixOS machines on AWS for work

## The problem statement

* [config/webserver.nix](config/webserver.nix) is a simple webserver config
* We want to deploy a fleet of webservers to AWS with a loadbalancer in front
* Machines should be hands-off (no manual maintenance)


## Iteration 1. Create machine and `nixos-rebuild`

[ec2.tf](ec2.tf)
[00_ec2_push_build.tf](00_ec2_push_build.tf)

```bash
nixos-rebuild switch --flake .#webserver --target-host root@$(terraform output ec2_push_build_public_ip)
```

### Problems

* Works fine for one machine
* Annoying to execute this over any over again for every machine in ASG
* It's best practise to not have machines publicly reachable
* Arbitrary point between machine is up and machine is provisioned. Which means
  we need to manually deregister and register machines from the loadbalancer
  when they're being provisioned.

## Iteration 2: Put the nix config in the machine config directly

[01_ec2_user_data_build.tf](01_ec2_user_data_build.tf)

### Helps with

* When scaling the autoscaling group, machines automatically come up with new config
* When changing config, ASG will do rolling refresh of machines for us
* ASG will automatically deregister and register machines from the loadbalancer
* No need for SSH access or public IP anymore. Improve security

### Problems

* Nix build happens on the target machine. Doesn't work in resource-constrained envs
* Even _with_ E.g. a `t3.nano` instance will OOM if the nix evaluator is involved

## Iteration 3: Put nix closure reference in the machine config and pull from cache

[02_ec2_user_data_pull.tf](02_ec2_user_data_pull.tf)

### How it works

* [s3.tf](s3.tf) creates an S3 bucket to act as Nix Cache
* [.github/workflows/ci.yml](.github/workflows/ci.yml) builds the nix config and pushes it to the cache
* [02_ec2_user_data_pull.tf](02_ec2_user_data_pull.tf) pulls the nix closure from the cache and  activates it

### Problems

* `amazon-init.service` (The thing that executes the user-data script) runs extremely
  late in the boot process (after `multi-user.target`). This is because our 
  `switch-to-configuration` code in NixOS doesn't support running in the initial 
  transaction. This means the boot isn't parallelized at all and takes a long time.

## Solution 4: build own AMIs? 

* Easy in NixOS to build your own images [flake.nix](flake.nix)
* can upload them with [import-image.sh](import-image.sh)

### Problems

* AMI import in Amazon can take between 5 and 30 minutes!!
* There's a way to directly write to EBS snapshots using ebs-direct. Bypassing
  amazon's slow `vmimport` service. E.g. [coldsnap](https://github.com/awslabs/coldsnap) but when I tried using it it produced corrupt images. I didn't investigate further.
* An image per closure will bloat your nix store quickly


### Solution 5: Provision in initrd?

* Don't have the code yet
* Download the `nix_closure` from S3 in the initrd
  ```
  nix copy --from s3://my-bucket --to /sysroot/nix
  ```
* stage-2 immediately comes up with correct config.

# Conclusion and future work

* NixOS is a great fit for immutable infrastructure
* NixOS has modules for creating AWS-optimised configs and image

## Future work

* Our official AMI sucks balls
* The AMI on https//nixos.org doesn't get updated after initial release
  This means you don't get kernel updates without rebooting. Rebooting
  is problematic in an ASG.
* no auto-login on console so hard to debug issues
* Even our `nix-store --realise` uses too much RAM for `t3.nano` and locks up the machine
* For now; build your own base images. But we should fix this upstream!!
* AMI is legacy boot and not UEFI. We should fix this upstream!!
* See if we can get `coldnsap` working for faster image uploads

### Server Optimised NixOS

* https://github.com/arianvp/server-optimised-nixos  is a NixOS derivative
  for UEFI images optimised for cloud.   Where i'll be working on e.g. the initrd
  stuff.
