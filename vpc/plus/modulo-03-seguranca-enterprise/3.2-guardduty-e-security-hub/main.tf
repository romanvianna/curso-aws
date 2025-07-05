resource "aws_guardduty_detector" "main" {
  enable = true
}

resource "aws_securityhub_account" "main" {
  # No specific attributes needed for enabling Security Hub at the account level
}
