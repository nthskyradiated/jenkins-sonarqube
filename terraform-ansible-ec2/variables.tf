variable "instance_count" {
  description = "The number of EC2 instances to create"
  type        = number
  default     = 2
}

variable "public_key" {
  description = "The public SSH key to use for the instances"
  type        = string
}

variable "s3_bucket_name" {
  description = "The name of the S3 bucket for Jenkins and SonarQube storage"
  type        = string
}

variable "region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "jenkins_instance_type" {
  description = "The instance type for the Jenkins EC2 instance"
  type        = string
  default     = "t2.micro"
}

variable "sonarqube_instance_type" {
  description = "The instance type for the SonarQube EC2 instance"
  type        = string
  default     = "t2.micro"
}

variable "iam_role_name" {
  description = "The name of the IAM role for EC2 instances"
  type        = string
  default     = "jenkins-sonarqube-role"
}

variable "db_password" {
  description = "The password for the RDS instance"
  type        = string
  sensitive   = true
}
variable "db_username" {
  description = "The username for the RDS instance"
  type        = string
  sensitive   = true
}
variable "db_name" {
  description = "The database name"
  type        = string
}

variable "rds_instance_type" {
  description = "The instance class for the RDS instance"
  type        = string
  default     = "db.t2.micro"
}

variable "aws_access_key_id" {
  description = "The AWS access key ID"
  type        = string
  sensitive   = true
}
variable "aws_secret_access_key" {
  description = "The AWS secret access key"
  type        = string
  sensitive   = true
}