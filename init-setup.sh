#!/bin/sh
set -e

SWAP_SIZE=${SWAP_SIZE:-"8"}

# Create swap (default to 8G)
if ! swapon -s | grep /swapfile; then
    echo "No swapfile, create and enable"
    fallocate -l "${SWAP_SIZE}G" /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
fi

# Set swappiness to 10
cat /proc/sys/vm/swappiness

sudo sysctl vm.swappiness=10
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf

#################################################################################################################

# Install docker 18.03 CE
if docker -v; then
    echo "Docker is already installed with: [$(docker -v)]"
else
    echo "Not found docker, trying to install docker 18.03 CE"
    curl https://releases.rancher.com/install-docker/18.03.sh | sh
fi

# Install docker compose from release page
if docker-compose -v; then
    echo "Docker-compose is already installed with: [$(docker-compose -v)]"
else
    compose_file_name="docker-compose-$(uname -s)-$(uname -m)"
    echo "Not found docker-compose, trying to install v1.21.2 platform ${compose_file_name}"
    curl -L "https://github.com/docker/compose/releases/download/1.21.2/${compose_file_name}" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

#############################################################
# LAUNCHING RANCHER SERVER - SINGLE CONTAINER (NON-HA) ===> http://<SERVER_IP>:8080

if docker ps | grep rancher/server; then
    echo "Rancher server is running, no need to install"
else
    echo "Not found rancher, trying to install rancher/server:v1.6.17"
    docker run -d --restart=unless-stopped -p 8080:8080 --name=rancher-server rancher/server:v1.6.17
fi

# Download rancher CLI + compose
# if rancher -v; then
#     echo "Rancher CLI is already installed with: $(rancher -v)"
# else
#     echo "Installing Rancher CLI"
#     wget "https://releases.rancher.com/cli/v0.6.3/rancher-linux-amd64-v0.6.3.tar.gz"
#     tar xzf rancher-linux-amd64-v0.6.3.tar.gz
#     mv rancher-v0.6.3/rancher /usr/local/bin
# fi

# if rancher-compose -v; then
#     echo "Rancher Compose is already installed with: $(rancher-compose -v)"
# else
#     echo "Installing Rancher Compose"
#     wget "https://releases.rancher.com/compose/v0.12.5/rancher-compose-linux-amd64-v0.12.5.tar.gz"
#     tar xzf rancher-compose-linux-amd64-v0.12.5.tar.gz
#     mv rancher-compose-v0.12.5/rancher-compose /usr/local/bin
# fi

#############################################################

# Prepare helper script

cat >/usr/local/bin/get-container <<EOL
#!/bin/bash
NAME=\$1
docker ps -qf name=\$NAME
EOL

cat >/usr/local/bin/stats <<EOL
#!/bin/bash

FILTER=\$1
docker stats \$(docker ps --format={{.Names}} | grep \$FILTER) --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
EOL

chmod +x /usr/local/bin/get-container
chmod +x /usr/local/bin/stats

# Install ruby
apt-get -y install ruby-full

# Increase config system
sysctl -w vm.max_map_count=262144
echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf


