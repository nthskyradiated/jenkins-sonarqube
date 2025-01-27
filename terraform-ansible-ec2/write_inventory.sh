#!/bin/bash

# Ensure Terraform state is up to date
terraform refresh

# Wait for instances to be fully provisioned
max_wait_time=180  # Maximum wait time in seconds
wait_time=0
check_interval=5   # Check every 5 seconds

check_instances_running() {
  instance_ids=$(terraform output -json instance_ids | jq -r '.[]')
  running_count=0
  total_count=$(echo "$instance_ids" | wc -l)

  for instance_id in $instance_ids; do
    state=$(aws ec2 describe-instances --instance-ids "$instance_id" --query "Reservations[].Instances[].State.Name" --output text)
    if [ "$state" == "running" ]; then
      ((running_count++))
    fi
  done

  [ "$running_count" -eq "$total_count" ]
}

# Wait until all instances are running
while ! check_instances_running; do
  if [ "$wait_time" -ge "$max_wait_time" ]; then
    echo "Timed out waiting for instances to be running."
    exit 1
  fi
  sleep "$check_interval"
  wait_time=$((wait_time + check_interval))
done

# Output the instance IPs directly from Terraform output
jenkins_ip=$(terraform output -json jenkins_instance_ip | jq -r '.')
sonarqube_ip=$(terraform output -json sonarqube_instance_ip | jq -r '.')

# Add Jenkins IP to inventory
echo "[jenkins]" > inventory
echo "$jenkins_ip" >> inventory

# Add SonarQube IP to inventory
echo "[sonarqube]" >> inventory
echo "$sonarqube_ip" >> inventory

# Check if the output file is populated
if [ -s inventory ]; then
  echo "Inventory file created successfully."
  echo '{"status": "completed"}'
else
  echo "Failed to create inventory file."
  echo '{"status": "failed"}'
fi
