#!/bin/bash

# Usar o Reachability Analyzer para verificar a conectividade
# aws ec2 create-network-insights-path --source-ip 10.0.1.10 --destination-ip 10.0.2.20 --protocol tcp --destination-port 80
# aws ec2 start-network-insights-analysis --network-insights-path-id nipa-0abcdef1234567890

# Analisar VPC Flow Logs para identificar problemas de tráfego
# aws logs filter-log-events --log-group-name /aws/vpc/flow-logs/my-flow-logs --filter-pattern "[version, account_id, interface_id, srcaddr, dstaddr, srcport, dstport, protocol, packets, bytes, start, end, action, log_status]" --query "events[*].message"
