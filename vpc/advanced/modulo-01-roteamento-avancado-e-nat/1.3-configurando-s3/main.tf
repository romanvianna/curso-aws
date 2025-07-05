resource "aws_s3_bucket" "b" {
  bucket = "my-unique-vpc-bucket-12345"

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}
