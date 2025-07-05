resource "aws_iam_policy" "vpc_read_only" {
  name        = "MyVPCReadOnlyAccess"
  description = "Allows read-only access to VPC resources"
  policy      = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action   = [
          "ec2:Describe*"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}
