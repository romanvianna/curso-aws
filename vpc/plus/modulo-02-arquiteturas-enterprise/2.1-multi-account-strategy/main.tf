resource "aws_organizations_organization" "example" {
  aws_service_access_principals = ["sso.amazonaws.com"]
  feature_set                   = "ALL"
}

resource "aws_organizations_account" "prod" {
  name  = "production"
  email = "production@example.com"
  parent_id = aws_organizations_organization.example.roots[0].id
}
