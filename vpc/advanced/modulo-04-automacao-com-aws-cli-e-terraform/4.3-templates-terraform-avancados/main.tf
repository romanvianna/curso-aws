module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-advanced-vpc"
  cidr = "10.20.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.20.1.0/24", "10.20.2.0/24"]
  private_subnets = ["10.20.3.0/24", "10.20.4.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Environment = "Dev"
  }
}
