variable "image_id" {
  default = "ami-0891608ae66031439"
}

variable "instance_type" {
  default = "t4g.small"
}

variable "nix_closure" {
  description = "Injected by CI"
  default     = null
}