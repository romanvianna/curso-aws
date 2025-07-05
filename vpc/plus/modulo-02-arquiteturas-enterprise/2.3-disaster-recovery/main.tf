resource "aws_ami_copy" "dr_ami" {
  name              = "my-dr-ami"
  source_ami_id     = "ami-0c55b159cbfafe1f0"
  source_ami_region = "us-east-1"

  tags = {
    Name = "DR AMI"
  }
}

resource "aws_backup_plan" "example" {
  name = "my_backup_plan"

  rule {
    rule_name         = "daily"
    target_vault_name = aws_backup_vault.example.name
    schedule          = "cron(0 12 * * ? *)"
    lifecycle {
      delete_after_days = 90
    }
  }
}

resource "aws_backup_vault" "example" {
  name = "my_backup_vault"
}
