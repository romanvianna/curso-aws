#!/bin/bash

# Criar uma organização
aws organizations create-organization --feature-set ALL

# Criar uma nova conta na organização
aws organizations create-account --email user@example.com --name MyNewAccount --role-name OrganizationAccountAccessRole
