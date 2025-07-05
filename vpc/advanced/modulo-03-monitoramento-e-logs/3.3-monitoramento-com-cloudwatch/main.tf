resource "aws_cloudwatch_metric_alarm" "network_in_alarm" {
  alarm_name          = "HighNetworkInAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "NetworkIn"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Sum"
  threshold           = 1000000000
  alarm_description   = "This alarm monitors network in for the VPC"
  actions_enabled     = true

  dimensions = {
    VPC = aws_vpc.custom_vpc.id
  }
}
