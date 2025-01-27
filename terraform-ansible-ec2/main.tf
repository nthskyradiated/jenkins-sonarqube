locals {
  ssh_user         = "ubuntu"
  key_name         = "ansible-key"
  private_key_path = "~/.ssh/ansible-key"
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "terra-ansible-vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "terra-ansible-ig" {
  vpc_id = aws_vpc.terra-ansible-vpc.id
}

resource "aws_route_table" "terra-ansible-rt" {
  vpc_id = aws_vpc.terra-ansible-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.terra-ansible-ig.id
  }
}

resource "aws_subnet" "terra-ansible-subnet" {
  vpc_id            = aws_vpc.terra-ansible-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "terra-ansible-subnet"
  }
}

resource "aws_route_table_association" "terra-ansible-rta" {
  subnet_id      = aws_subnet.terra-ansible-subnet.id
  route_table_id = aws_route_table.terra-ansible-rt.id
}

resource "aws_security_group" "terra-ansible-sg" {
  name        = "terra-ansible-sg"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.terra-ansible-vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for Jenkins
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins_sg"
  description = "Allow access to Jenkins on port 8080"
  vpc_id      = aws_vpc.terra-ansible-vpc.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for SonarQube
resource "aws_security_group" "sonarqube_sg" {
  name        = "sonarqube_sg"
  description = "Allow access to SonarQube on port 9000"
  vpc_id      = aws_vpc.terra-ansible-vpc.id

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = local.key_name
  public_key = var.public_key
}

# Create an S3 bucket
resource "aws_s3_bucket" "terra_ansible_bucket" {
  bucket = var.s3_bucket_name
  tags = {
    Name = "JenkinsSonarQubeStorage"
  }
}

# resource "aws_s3_bucket_acl" "terra_ansible_bucket_acl" {
#   bucket = aws_s3_bucket.terra_ansible_bucket.id
#   acl    = "private"
# }

# resource "random_string" "bucket_suffix" {
#   length  = 8
#   special = false
# }

resource "aws_s3_bucket_public_access_block" "terra_ansible_bucket_block" {
  bucket = aws_s3_bucket.terra_ansible_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}


resource "aws_s3_bucket_policy" "terra_ansible_bucket_policy" {
  bucket = aws_s3_bucket.terra_ansible_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowSpecificAccess",
        Effect = "Allow",
        Principal = {
          AWS = [
            aws_iam_role.jenkins_role.arn,
            aws_iam_role.sonarqube_role.arn
          ]
        },
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject"
        ],
        Resource = [
          aws_s3_bucket.terra_ansible_bucket.arn,
          "${aws_s3_bucket.terra_ansible_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_instance" "jenkins_instance" {
  ami                         = "ami-04b4f1a9cf54c11d0"
  instance_type               = var.jenkins_instance_type
  vpc_security_group_ids      = [aws_security_group.terra-ansible-sg.id, aws_security_group.jenkins_sg.id]
  key_name                    = local.key_name
  subnet_id                   = aws_subnet.terra-ansible-subnet.id
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.jenkins_instance_profile.name

  tags = {
    Name = "JenkinsInstance"
    Role = "Jenkins"
  }

  provisioner "remote-exec" {
    inline = ["echo 'Wait until SSH is ready'"]

    connection {
      type        = "ssh"
      user        = local.ssh_user
      private_key = file(local.private_key_path)
      host        = self.public_ip
    }
  }
}

resource "aws_instance" "sonarqube_instance" {
  ami                         = "ami-04b4f1a9cf54c11d0"
  instance_type               = var.sonarqube_instance_type
  vpc_security_group_ids      = [aws_security_group.terra-ansible-sg.id, aws_security_group.sonarqube_sg.id]
  key_name                    = local.key_name
  subnet_id                   = aws_subnet.terra-ansible-subnet.id
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.sonarqube_instance_profile.name

  tags = {
    Name = "SonarQubeInstance"
    Role = "SonarQube"
  }

  provisioner "remote-exec" {
    inline = ["echo 'Wait until SSH is ready'"]

    connection {
      type        = "ssh"
      user        = local.ssh_user
      private_key = file(local.private_key_path)
      host        = self.public_ip
    }
  }
}

# IAM policy for S3 access
resource "aws_iam_policy" "s3_access_policy" {
  name        = "S3AccessPolicy"
  description = "Policy for Jenkins and SonarQube to access S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.terra_ansible_bucket.arn,
          "${aws_s3_bucket.terra_ansible_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role" "jenkins_role" {
  name = var.iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "jenkins_policy_attachment" {
  policy_arn = aws_iam_policy.s3_access_policy.arn
  role       = aws_iam_role.jenkins_role.name
}

resource "aws_iam_role" "sonarqube_role" {
  name = "SonarQubeRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sonarqube_policy_attachment" {
  policy_arn = aws_iam_policy.s3_access_policy.arn
  role       = aws_iam_role.sonarqube_role.name
}

# Create IAM instance profile for Jenkins and SonarQube
resource "aws_iam_instance_profile" "jenkins_instance_profile" {
  name = "jenkins_instance_profile"
  role = aws_iam_role.jenkins_role.name
}

resource "aws_iam_instance_profile" "sonarqube_instance_profile" {
  name = "sonarqube_instance_profile"
  role = aws_iam_role.sonarqube_role.name
}

# Null resource to trigger ansible-playbook run after instance creation
resource "null_resource" "ansible_provision" {
  depends_on = [aws_instance.jenkins_instance, aws_instance.sonarqube_instance]

  provisioner "local-exec" {
    command = "ansible-playbook -i '${join(",", [aws_instance.jenkins_instance.public_ip, aws_instance.sonarqube_instance.public_ip])},' --private-key ${local.private_key_path} -u ubuntu jenkins_sonarqube.yaml"
  }
}

resource "null_resource" "write_inventory" {
  depends_on = [aws_instance.jenkins_instance, aws_instance.sonarqube_instance]

  provisioner "local-exec" {
    command = "bash ./write_inventory.sh && ansible-playbook -i inventory --private-key ~/.ssh/ansible-key -u ubuntu jenkins_sonarqube.yaml"
  }
}
