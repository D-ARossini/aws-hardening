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

data "aws_organizations_organization" "this" {}

resource "aws_organizations_policy_attachment" "root" {
  policy_id = aws_organizations_policy.top_level_region_lock.id
  target_id = data.aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_policy" "top_level_region_lock" {
  name    = "region-lock"
  content = data.aws_iam_policy_document.region_lock_policy.json
}

data "aws_iam_policy_document" "region_lock_policy" {
  statement {
    effect      = "Deny"
    not_actions = local.service_exemptions
    resources   = ["*"]
    condition {
      test     = "StringNotEquals"
      values   = var.allowed_regions
      variable = "aws:RequestedRegion"
    }
  }
}
