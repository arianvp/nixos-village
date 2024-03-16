variable "name" {
  type    = string
  default = null
}

variable "name_prefix" {
  type    = string
  default = null
}

variable "managed_policy_arns" {
  type    = set(string)
  default = null
}