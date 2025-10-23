#!/bin/bash
echo ECS_CLUSTER=${cluster_name} > /etc/ecs/ecs.config
mkdir -p /opt/wireguard/config
chown -R ec2-user:ec2-user /opt/wireguard || true
# The ECS AMI will start the agent automatically when /etc/ecs/ecs.config exists
