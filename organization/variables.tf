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

variable "allowed_regions" {
  type        = list(string)
  description = "The allowed regions for ressources"
}

variable "developper" {
  type        = string
  description = "The account to give the users access to"
}

variable "auth_account_id" {
 type         = string
 description  = "The account to create the users in"
}

riable "cross_account_role" {
 type         = string
 description  = "The name of the role for the target and auth accounts"
}
variable "users" {
 type         = list(string)
 description  = "A list of user email addresses"
}
