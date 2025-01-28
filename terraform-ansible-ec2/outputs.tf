output "jenkins_instance_ip" {
  value = aws_instance.jenkins_instance.public_ip
}

output "sonarqube_instance_ip" {
  value = aws_instance.sonarqube_instance.public_ip
}

output "s3_bucket_name" {
  value = aws_s3_bucket.terra_ansible_bucket.bucket
}

output "instance_ids" {
  value = [aws_instance.jenkins_instance.id, aws_instance.sonarqube_instance.id]
}

output "instance_public_ips" {
  value = [aws_instance.jenkins_instance.public_ip, aws_instance.sonarqube_instance.public_ip]
}

output "rds_endpoint" {
  value = aws_db_instance.sonarqube_db.endpoint
}