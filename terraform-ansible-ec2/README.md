# Multiple EC2 Instances Deployment and Provisioning with Terraform & Ansible

## Overview
This project automates the deployment of two EC2 instances on AWS, one running Jenkins while the other running SonarQube, one RDS (Postgresql) instance. Both EC2 instances are configured to use an S3 bucket for storage. Ansible is used for provisioning and configuration management and Terraform for deployment.

## Requirements
Ensure the following tools are installed on your system:
- AWS CLI
- Terraform
- Ansible
- JQ (to parse JSON)
- YQ (to parse YAML)

## Setup Instructions

1. **Create your SSH key-pair locally:**
   ```bash
   ssh-keygen -t ed25519 -C "your_email@example.com"
   ```

2. **Set proper permissions for the private key:**
   ```bash
   chmod 600 ~/.ssh/ansible-key
   ```

3. **Export Ansible's config file to prevent SSH from checking our key:**
   ```bash
   export ANSIBLE_CONFIG=./ansible.cfg
   ```

4. **Initialize Terraform:**
   ```bash
   terraform init
   ```

5. **Deploy the infrastructure:**
   ```bash
   terraform apply --auto-approve
   ```

## Project Structure
- **ansible.cfg**: Configuration settings for Ansible.
- **inventory**: Lists the IP addresses of the EC2 instances. Created on first run and updated on subsequent runs.
- **main.tf**: Main Terraform configuration file defining AWS resources.
- **outputs.tf**
- **roles/jenkins/tasks/main.yaml**: Ansible role for Jenkins.
- **roles/sonarqube/tasks/main.yaml**: Ansible role for SonarQube.
- **terraform.tfvars**
- **variables.tf**: Defines variables used in the Terraform configuration.
- **write_inventory.sh**: Script to capture public IPs of instances and write to the inventory file.
- **vars/main.yaml**: Ansible var file.
- **lib/jenkins.yaml**: Jenkins config file to be imported.