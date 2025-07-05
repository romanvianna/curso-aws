resource "aws_flow_log" "example" {
  iam_role_arn    = aws_iam_role.flow_log_role.arn
  log_destination = aws_s3_bucket.flow_log_bucket.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.custom_vpc.id
}

resource "aws_s3_bucket" "flow_log_bucket" {
  bucket = "my-vpc-flow-logs-bucket-unique"
}

resource "aws_iam_role" "flow_log_role" {
  name = "flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "flow_log_policy" {
  name = "flow-log-policy"
  role = aws_iam_role.flow_log_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "s3:PutObject"
        ]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.flow_log_bucket.arn}/*"
      },
    ]
  })
}
