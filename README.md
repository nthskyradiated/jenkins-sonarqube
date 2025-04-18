# Jenkins and SonarQube Deployment

This repo provides two variants for deploying Jenkins and SonarQube:
1. Using Docker Compose.
2. Using AWS EC2 instances with Terraform and Ansible.
3. Via Kubernetes as deployments.
4. @TODO as Helm deployment using Terraform.

## Docker Compose Deployment

This approach uses Docker Compose to deploy Jenkins, SonarQube, and a PostgreSQL database for SonarQube. Additionally, it provisions a `jenkins/ssh-agent` container to pair with Jenkins as its node.

### Prerequisites

- Docker
- Docker Compose

### Steps

1. Clone the repository:
    ```sh
    git clone https://github.com/nthskyradiated/jenkins-sonarqube.git
    cd jenkins-sonarqube/docker-compose
    ```

2. Start the services:
    ```sh
    docker network create jenkins
    docker compose up -d
    ```

3. Access the services:
    - Jenkins: `http://localhost:8080`
    - SonarQube: `http://localhost:9000`

## AWS Deployment with Terraform and Ansible

This approach uses Terraform to provision EC2 instances on AWS and Ansible to configure Jenkins and SonarQube on those instances.

### Prerequisites

- Terraform
- Ansible
- AWS CLI configured with appropriate credentials
- YQ (to parse YAML. https://github.com/mikefarah/yq )

### Steps

1. Navigate to the `terraform-ansible-ec2` directory:
    ```sh
    cd terraform-ansible-ec2
    ```

2. Follow the instructions in the README file located in the `terraform-ansible-ec2` folder to provision and configure the instances.

## License
MIT
