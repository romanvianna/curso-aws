# O troubleshooting é uma atividade operacional e não é diretamente provisionado pelo Terraform. No entanto, o Terraform pode provisionar os recursos necessários para o troubleshooting, como VPC Flow Logs e CloudWatch.

# Exemplo de provisionamento de VPC Flow Logs para troubleshooting
resource "aws_flow_log" "troubleshooting_flow_log" {
  iam_role_arn    = aws_iam_role.flow_log_role.arn
  log_destination = aws_s3_bucket.flow_log_bucket.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.custom_vpc.id
}
