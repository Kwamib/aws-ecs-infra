#!/bin/bash
set -euo pipefail
export PATH=$PATH:/usr/local/bin:/usr/bin:/bin

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [user-data] $1"; }
trap 'log "ERROR on line $LINENO"; exit 1' ERR

# ==========================================
# Network Connectivity Check
# ==========================================
log "Checking network readiness..."

MAX_WAIT=300
WAIT_TIME=0

while ! ip route | grep -q default && [ $WAIT_TIME -lt $MAX_WAIT ]; do
    log "Waiting for default route... ($WAIT_TIME/$MAX_WAIT seconds)"
    sleep 10
    WAIT_TIME=$((WAIT_TIME + 10))
done

WAIT_TIME=0
while ! nslookup aws.amazon.com >/dev/null 2>&1 && [ $WAIT_TIME -lt $MAX_WAIT ]; do
    log "Waiting for DNS resolution... ($WAIT_TIME/$MAX_WAIT seconds)"
    sleep 10
    WAIT_TIME=$((WAIT_TIME + 10))
done

WAIT_TIME=0
while ! curl -s --connect-timeout 10 https://aws.amazon.com >/dev/null && [ $WAIT_TIME -lt $MAX_WAIT ]; do
    log "Waiting for internet connectivity... ($WAIT_TIME/$MAX_WAIT seconds)"
    sleep 15
    WAIT_TIME=$((WAIT_TIME + 15))
done

log "Network is ready."

# ==========================================
# CloudWatch Agent
# ==========================================
log "Installing CloudWatch Agent..."
yum install -y amazon-cloudwatch-agent

log "Starting CloudWatch Agent with config from SSM..."
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c ssm:/${PROJECT_NAME:-clixx}/cwagent/config \
  -s

sleep 10
if ! systemctl is-active --quiet amazon-cloudwatch-agent; then
    log "ERROR: CloudWatch Agent failed to start"
    systemctl status amazon-cloudwatch-agent
    exit 1
fi

log "CloudWatch Agent started successfully."

# ==========================================
# ECS Agent Configuration
# ==========================================
log "Writing ECS config..."
cat <<EOF > /etc/ecs/ecs.config
ECS_CLUSTER=${CLUSTER_NAME:-clixx-cluster}
ECS_ENABLE_TASK_IAM_ROLE=true
ECS_ENABLE_CONTAINER_METADATA=true
ECS_ENABLE_AWSLOGS_EXECUTIONROLE_OVERRIDE=true
ECS_AVAILABLE_LOGGING_DRIVERS=["json-file","awslogs"]
EOF

log "Fixing ECS service dependency..."
sudo systemctl stop ecs || true

if [ ! -f /etc/systemd/system/ecs.service ]; then
    sudo cp /usr/lib/systemd/system/ecs.service /etc/systemd/system/ecs.service
fi

sudo sed -i '/After=cloud-final.service/d' /etc/systemd/system/ecs.service
sudo systemctl daemon-reload

log "Starting ECS agent..."
sudo systemctl enable ecs || true
if ! sudo systemctl start ecs; then
    log "Initial start failed, trying restart..."
    sudo systemctl restart ecs
fi

sleep 15
if ! systemctl is-active --quiet ecs; then
    log "ERROR: ECS service failed to start"
    systemctl status ecs
    exit 1
fi

log "ECS agent registered with cluster successfully."
log "User-data complete. WordPress will configure via ECS task definition environment variables."
