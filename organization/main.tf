resource "aws_organizations_organizational_unit" "security" {
  name      = var.security
  parent_id = var.organizational_unit_parent_id
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = var.workloads
  parent_id = var.organizational_unit_parent_id
}

resource "aws_organizations_account" "juice_shop" {
  name              = "juice-shop"
  email             = var.juice_shop_account_email
  parent_id         = aws_organizations_organizational_unit.workloads.id
  close_on_deletion = true
}

resource "aws_organizations_account" "security" {
  name              = var.security
  email             = var.security_account_email
  parent_id         = aws_organizations_organizational_unit.security.id
  close_on_deletion = true
}
