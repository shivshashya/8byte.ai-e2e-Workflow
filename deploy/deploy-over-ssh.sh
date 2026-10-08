#!/bin/bash
# Runs ON THE PIPELINE RUNNER (or an operator's machine with AWS access).
# Connects to the private EC2 host and runs deploy.sh there.
#
# Usage: deploy-over-ssh.sh <staging|production> <image>
# Needs: EC2_INSTANCE_ID and AWS_REGION in the environment, plus AWS credentials
# allowed to open the EC2 Instance Connect tunnel and send a temporary key.
set -euo pipefail

ENVIRONMENT="$1"
IMAGE="$2"
: "${EC2_INSTANCE_ID:?EC2_INSTANCE_ID is not set}"
: "${AWS_REGION:?AWS_REGION is not set}"

# A new key pair for this run only. It is deleted when the script ends.
KEY_DIR="$(mktemp -d)"
trap 'rm -rf "$KEY_DIR"' EXIT
ssh-keygen -q -t ed25519 -N "" -f "$KEY_DIR/key"

# The host accepts this public key for 60 seconds, long enough to connect.
# No permanent SSH key exists on the host or in the pipeline.
aws ec2-instance-connect send-ssh-public-key \
  --region "$AWS_REGION" \
  --instance-id "$EC2_INSTANCE_ID" \
  --instance-os-user ec2-user \
  --ssh-public-key "file://$KEY_DIR/key.pub" >/dev/null

# The host has no public IP. open-tunnel reaches it through the EC2 Instance
# Connect endpoint, and IAM limits the tunnel to this host's SSH port. The
# runner has never seen the host before, so it records the host key on first
# use in a throwaway known_hosts file.
ssh -T -i "$KEY_DIR/key" \
  -o IdentitiesOnly=yes \
  -o StrictHostKeyChecking=accept-new \
  -o UserKnownHostsFile="$KEY_DIR/known_hosts" \
  -o ConnectTimeout=20 \
  -o ServerAliveInterval=15 \
  -o ProxyCommand="aws ec2-instance-connect open-tunnel --region $AWS_REGION --instance-id $EC2_INSTANCE_ID" \
  "ec2-user@$EC2_INSTANCE_ID" \
  "bash -s -- '$ENVIRONMENT' '$IMAGE' '$AWS_REGION'" <"$(dirname "$0")/deploy.sh"
