#!/bin/bash
set -euo pipefail

# Administrative access and deployment commands both use SSH.
# AL2023 standard includes SSM Agent; disable it for this SSH-only host.
systemctl disable --now amazon-ssm-agent

# Install the host tools and explicitly ensure EC2 Instance Connect is present.
for attempt in 1 2 3; do
  if dnf install -y docker awscli-2 jq ec2-instance-connect amazon-cloudwatch-agent rsyslog logrotate; then
    break
  fi
  if [ "$attempt" -eq 3 ]; then
    echo "Package installation failed after three attempts." >&2
    exit 1
  fi
  sleep 5
done

# AL2023 uses journald by default. Export host events to files for collection.
install -d -m 0755 /var/lib/rsyslog
cat > /etc/rsyslog.conf <<'RSYSLOG'
global(workDirectory="/var/lib/rsyslog")
module(load="imjournal" StateFile="imjournal.state")
auth,authpriv.* /var/log/secure
*.info;auth.none;authpriv.none /var/log/messages
RSYSLOG
touch /var/log/messages /var/log/secure
chmod 0600 /var/log/messages /var/log/secure
rsyslogd -N1
systemctl enable --now rsyslog

# Bound local system files; the CloudWatch collector follows their rotation.
# Replace distribution rules for these files to avoid duplicate rotation entries.
for packaged_rotation in /etc/logrotate.d/syslog /etc/logrotate.d/rsyslog; do
  if [ -f "$packaged_rotation" ]; then
    mv "$packaged_rotation" /var/lib/rsyslog/
  fi
done
cat > /etc/logrotate.d/rsyslog <<'LOGROTATE'
/var/log/messages /var/log/secure {
    daily
    maxsize 10M
    rotate 7
    missingok
    notifempty
    compress
    delaycompress
    create 0600 root root
    sharedscripts
    postrotate
        /usr/bin/systemctl kill -s HUP rsyslog.service >/dev/null 2>&1 || true
    endscript
}
LOGROTATE

# New containers inherit centralized logging and a bounded local read cache.
install -d -m 0755 /etc/docker
cat > /etc/docker/daemon.json <<'JSON'
${docker_logging_config}
JSON

dockerd --validate --config-file=/etc/docker/daemon.json
systemctl enable --now docker
systemctl enable --now sshd

# Use sudo docker over SSH. Membership of the docker group would grant root access.
# Environment networks, application containers, and DB secrets are deployment work.
docker --version
aws --version
systemctl is-active docker sshd
echo "EC2 host bootstrap completed."
