resource "aws_iam_policy" "vpc_admin_policy" {
  name        = "MyVPCAdminAccess"
  description = "Allows administrative access to VPC resources"
  policy      = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action   = [
          "ec2:*Vpc*",
          "ec2:*Subnet*",
          "ec2:*RouteTable*",
          "ec2:*SecurityGroup*",
          "ec2:*NetworkAcl*",
          "ec2:*InternetGateway*",
          "ec2:*NatGateway*",
          "ec2:*VpcEndpoint*"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}
