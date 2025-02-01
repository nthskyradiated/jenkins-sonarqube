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

resource "aws_subnet" "terra-ansible-subnet-2" {
  vpc_id            = aws_vpc.terra-ansible-vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "terra-ansible-subnet-2"
  }
}


# DB Subnet Group
resource "aws_db_subnet_group" "sonarqube_db_subnet_group" {
  name       = "sonarqube_db_subnet_group"
  subnet_ids = [aws_subnet.terra-ansible-subnet.id, aws_subnet.terra-ansible-subnet-2.id]

  tags = {
    Name = "SonarQube DB Subnet Group"
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

resource "aws_security_group" "rds_sg" {
  name        = "rds_sg"
  description = "Allow access to RDS from SonarQube instance"
  vpc_id      = aws_vpc.terra-ansible-vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.terra-ansible-sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
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

  user_data = <<-EOF
              #!/bin/bash
              echo "SONARQUBE_JDBC_URL=jdbc:postgresql://${aws_db_instance.sonarqube_db.endpoint}/${aws_db_instance.sonarqube_db.db_name}" >> /etc/environment
              echo "SONARQUBE_JDBC_USERNAME=${var.db_username}" >> /etc/environment
              echo "SONARQUBE_JDBC_PASSWORD=${var.db_password}" >> /etc/environment
              EOF

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

resource "aws_db_instance" "sonarqube_db" {
  identifier             = "sonarqube-db"
  engine                 = "postgres"
  engine_version         = "15.10"
  instance_class         = var.rds_instance_type
  allocated_storage      = 20
  storage_type           = "gp2"
  username               = var.db_username
  password               = var.db_password
  db_name                = var.db_name
  db_subnet_group_name   = aws_db_subnet_group.sonarqube_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  multi_az               = false
}

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

provisioner "local-exec" {
  command = <<EOT
    yq -Y -i '.unclassified.gitHubPluginConfig.hookUrl = "http://${aws_instance.jenkins_instance.public_ip}:8080/github-webhook/"' ./lib/jenkins.yaml
    yq -Y -i '.unclassified.location.url = "http://${aws_instance.jenkins_instance.public_ip}:8080/"' ./lib/jenkins.yaml
    yq -Y -i '.unclassified.sonarGlobalConfiguration.installations[0].serverUrl = "http://${aws_instance.sonarqube_instance.public_ip}:9000"' ./lib/jenkins.yaml
  EOT
}

}

resource "null_resource" "update_ansible_vars" {
  provisioner "local-exec" {
    command = <<EOT
# Check if sonarqube_jdbc_url is present, then update or add
if grep -q "sonarqube_jdbc_url:" ./vars/main.yaml; then
  sed -i 's|^sonarqube_jdbc_url:.*|sonarqube_jdbc_url: jdbc:postgresql://${aws_db_instance.sonarqube_db.endpoint}/${aws_db_instance.sonarqube_db.db_name}|' ./vars/main.yaml
else
  echo "sonarqube_jdbc_url: jdbc:postgresql://${aws_db_instance.sonarqube_db.endpoint}/${aws_db_instance.sonarqube_db.db_name}" >> ./vars/main.yaml
fi

# Check if sonarqube_jdbc_username is present, then update or add
if grep -q "sonarqube_jdbc_username:" ./vars/main.yaml; then
  sed -i 's|^sonarqube_jdbc_username:.*|sonarqube_jdbc_username: ${var.db_username}|' ./vars/main.yaml
else
  echo "sonarqube_jdbc_username: ${var.db_username}" >> ./vars/main.yaml
fi

# Check if sonarqube_jdbc_password is present, then update or add
if grep -q "sonarqube_jdbc_password:" ./vars/main.yaml; then
  sed -i 's|^sonarqube_jdbc_password:.*|sonarqube_jdbc_password: ${var.db_password}|' ./vars/main.yaml
else
  echo "sonarqube_jdbc_password: ${var.db_password}" >> ./vars/main.yaml
fi
EOT
  }

  depends_on = [aws_db_instance.sonarqube_db]
}

resource "null_resource" "write_inventory" {
  depends_on = [aws_instance.jenkins_instance, aws_instance.sonarqube_instance]

  provisioner "local-exec" {
    command = "bash ./write_inventory.sh && ansible-playbook -i inventory --private-key ${local.private_key_path} -u ubuntu jenkins_sonarqube.yaml"
  }
}
