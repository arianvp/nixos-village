variable "name" {
  type = string
}

variable "image_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "key_name" {
  type    = string
  default = null
}

variable "nix_store_path" {
  type = string
  default = null
}

variable "nix_substituters" {
  type = list(string)
}

variable "managed_policy_arns" {
  type    = set(string)
  default = []
}
