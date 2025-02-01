# Multiple EC2 Instances Deployment and Provisioning with Terraform & Ansible

## Overview
Deploys two EC2 instances on AWS, one running Jenkins while the other running SonarQube, one RDS (Postgresql) instance for SonarQube. Both EC2 instances are configured to use an S3 bucket for their storage. Ansible is used for provisioning and configuration management and Terraform for deployment.

### Several tools are also installed on the Jenkins instance: 
 - Docker
 - Trivy
 - Fontconfig
 - GNUPG

## Requirements
Ensure the following tools are installed on your system:
- AWS CLI
- Terraform
- Ansible
- YQ (to parse YAML. https://github.com/mikefarah/yq )

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
- **write_inventory.sh**: Script to capture public IPs of instances and write to the inventory file. (*no longer used. Replaced by null resource "ansible-provision"*)
- **vars/main.yaml**: Ansible var file.  (*please see null_resource "update_ansible_vars" block on main.tf.*)
- **lib/jenkins.yaml**: Jenkins Configuration-as-Code file to be imported. (*please see null_resource "ansible_provision" block on main.tf to see what entries will be written to jenkins.yaml.*)