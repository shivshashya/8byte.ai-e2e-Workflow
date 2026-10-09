#!/bin/bash
set -euo pipefail

# Administrative access and deployment commands both use SSH.
# AL2023 standard includes SSM Agent; disable it for this SSH-only host.
systemctl disable --now amazon-ssm-agent

# Install the host tools and explicitly ensure EC2 Instance Connect is present.
for attempt in 1 2 3; do
  if dnf install -y docker awscli-2 jq ec2-instance-connect amazon-cloudwatch-agent; then
    break
  fi
  if [ "$attempt" -eq 3 ]; then
    echo "Package installation failed after three attempts." >&2
    exit 1
  fi
  sleep 5
done

# Bound local container logs so they cannot fill the root disk indefinitely.
install -d -m 0755 /etc/docker
cat > /etc/docker/daemon.json <<'JSON'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
JSON

systemctl enable --now docker
systemctl enable --now sshd

# Use sudo docker over SSH. Membership of the docker group would grant root access.
# Environment networks, application containers, and DB secrets are deployment work.
docker --version
aws --version
systemctl is-active docker sshd
echo "EC2 host bootstrap completed."
