variable "organizational_unit_parent_id" {
  type        = string
  description = "The ID of organizational unit parent"
}

variable "security" {
  type        = string
  description = "The name of the security organizational unit"
}

variable "workloads" {
  type        = string
  description = "The name of the organizational unit workload"
}

variable "juice_shop_account_email" {
  type        = string
  description = "The juice-shop account email"
}

variable "security_account_email" {
  type        = string
  description = "The security account email"
}
