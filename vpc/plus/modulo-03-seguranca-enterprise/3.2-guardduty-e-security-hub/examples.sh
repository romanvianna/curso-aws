#!/bin/bash

# Habilitar o GuardDuty
aws guardduty create-detector --enable

# Habilitar o Security Hub
aws securityhub enable-security-hub
