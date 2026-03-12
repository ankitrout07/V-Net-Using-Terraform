# VPC-Using-Terraform

Production-grade 3-Tier VPC architecture on AWS using Terraform. 

## Architecture
This project implements a secure, highly-available 3-tier architecture:

1.  **Tier 1: Web (Public)**
    *   Application Load Balancer (ALB)
    *   Bastion Host for SSH access
    *   Internet Gateway (IGW)
2.  **Tier 2: App (Private)**
    *   Auto Scaling Group (ASG) with Amazon Linux 2023
    *   Instances are isolated from direct internet access
    *   Egress traffic via NAT Gateway
3.  **Tier 3: DB (Isolated)**
    *   RDS PostgreSQL Instance
    *   Subnets have no internet route

### Security
- **Security Groups**: Stateful firewalls restricting traffic between tiers.
- **NAT Gateway**: Controlled egress for private instances.
- **Remote State**: AzureRM backend (configurable in `provider.tf`).

## Prerequisites
- Terraform >= 1.0
- AWS CLI configured
- Azure Storage Account (for remote state) or update `provider.tf` for local state.

## Setup
1.  Initialize Terraform:
    ```bash
    terraform init
    ```
2.  Validate configuration:
    ```bash
    terraform validate
    ```
3.  Plan deployment:
    ```bash
    terraform plan
    ```
4.  Apply changes:
    ```bash
    terraform apply
    ```
