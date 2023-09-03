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

variable "nix" {
  type = object({
    closure            = string
    subsituter         = string
    trusted_public_key = string
  })
  default = null
}


variable "managed_policy_arns" {
  type    = set(string)
  default = []
}
