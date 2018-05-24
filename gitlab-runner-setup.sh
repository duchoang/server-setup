#!/bin/sh
set -ue

# required env: GITLAB & TOKEN
if [ -z ${GITLAB+x} ]; then
  echo "Require env GITLAB"
  exit 1
fi
if [ -z ${TOKEN+x} ]; then
  echo "Require env TOKEN"
  exit 1
fi

SWAP_SIZE=${SWAP_SIZE:-"4"}
SWAP_LEVEL=${SWAP_LEVEL:-"10"}

############################################## CREATE SWAP ####################################################

# Create swap (default to 8G)
if ! swapon -s | grep /swapfile; then
  echo "No swapfile, create and enable"
  fallocate -l "${SWAP_SIZE}G" /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  cp /etc/fstab /etc/fstab.bak
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

# Set default swappiness to 10
cat /proc/sys/vm/swappiness

sudo sysctl vm.swappiness=${SWAP_LEVEL}
echo 'vm.swappiness=${SWAP_LEVEL}' | sudo tee -a /etc/sysctl.conf

#################################################################################################################

# Update system and install docker, gitlab-runner from linux repositories

if docker -v; then
  echo "Docker is already installed with: [$(docker -v)]"
else
  echo "Not found docker, trying to install docker"
  apt-get update
  curl -sSL https://get.docker.com/ | sh
fi

if gitlab-runner -v; then
  echo "Gitlab runner is already installed with: [$(gitlab-runner -v)]"
else
  echo "Not found, trying to install gitlab runner from official linux repositories"
  curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | sudo bash
  apt-get install gitlab-runner
fi

# Register new runner
gitlab-runner register \
  --non-interactive \
  --url "${GITLAB}" \
  --registration-token "${TOKEN}" \
  --tag-list "docker,dev" \
  --run-untagged=true \
  --locked=false \
  --executor "docker" \
  --docker-image "ruby:2.1" \
  --docker-privileged=true \
  --docker-volumes="/cache" \
  --docker-cache-dir="cache" \
  --docker-shm-size="200000000" \
  --docker-disable-cache=true
#200MB

# Check config is correctly setup
cat /etc/gitlab-runner/config.toml

echo "DONE SETUP for shared gitlab runner"

