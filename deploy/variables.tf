variable "instance_type" {
  default = "t4g.small"
}

variable "nix_closure" {
  description = "Injected by CI"
  default     = null
}