variable "name" {
  type = string
  default = null
}

variable "name_prefix" {
  type = string
  default = null
}

variable "path" {
  type    = string
  default = "/"
}

variable "managed_policy_arns" {
  type = set(string)
    default = null
}