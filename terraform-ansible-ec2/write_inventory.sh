# this is of no use now. It is included only as reference to what I used to create the inventory file before.
# replaced by the null resource block "ansible_provision" in the terraform code. 
#!/bin/bash

terraform refresh

# Wait for instances to be fully provisioned
max_wait_time=180
wait_time=0
check_interval=5

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

jenkins_ip=$(terraform output -json jenkins_instance_ip | jq -r '.')
sonarqube_ip=$(terraform output -json sonarqube_instance_ip | jq -r '.')

# Populate the inventory file
echo "[jenkins]" > inventory
echo "$jenkins_ip" >> inventory

echo "[sonarqube]" >> inventory
echo "$sonarqube_ip" >> inventory


if [ -s inventory ]; then
  echo "Inventory file created successfully."
  echo '{"status": "completed"}'
else
  echo "Failed to create inventory file."
  echo '{"status": "failed"}'
fi
