variable "instance_type" {
  default = "t4g.small"
}

variable "nix_store_path" {
  description = "Injected by CI"
}