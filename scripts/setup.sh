#!/bin/bash
set -euxo pipefail

# ==========================================
# ECS-Optimized AMI Provisioning
# ==========================================

LOG_FILE="/var/log/EC2_installation.log"
sudo touch "$LOG_FILE"
sudo chown ec2-user:ec2-user "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

echo ">>> Starting AMI provisioning on ECS-Optimized base..."

# Update system and install tools
echo ">>> Updating packages..."
sudo yum update -y
sudo yum install -y git curl wget unzip jq htop net-tools telnet bind-utils lsof nc

# Install AWS CLI v2
echo ">>> Installing AWS CLI v2..."
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q -o awscliv2.zip
sudo ./aws/install --update
rm -rf aws awscliv2.zip

# Docker configuration
echo ">>> Enabling Docker..."
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker ec2-user || true

# ECS agent placeholder config (overwritten by userdata at launch)
echo ">>> Writing ECS placeholder config..."
sudo mkdir -p /etc/ecs
sudo tee /etc/ecs/ecs.config > /dev/null <<EOF
ECS_CLUSTER=PLACEHOLDER_CLUSTER
ECS_ENABLE_TASK_IAM_ROLE=true
ECS_ENABLE_CONTAINER_METADATA=true
ECS_LOGLEVEL=info
ECS_AVAILABLE_LOGGING_DRIVERS=["json-file","awslogs"]
ECS_ENABLE_AWSLOGS_EXECUTIONROLE_OVERRIDE=true
EOF

# Cleanup
echo ">>> Cleaning yum cache..."
sudo yum clean all

echo ">>> AMI build complete. Ready for ECS."
