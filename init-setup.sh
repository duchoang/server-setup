#!/bin/sh
set -ue

SWAP_SIZE=${SWAP_SIZE:-"2"}
SWAP_LEVEL=${SWAP_LEVEL:-"5"}

# default to 17.03, can use 18.03
DOCKER=${DOCKER:-"17.03"}

# Create swap (default to 2G)
if ! swapon -s | grep /swapfile; then
    echo "No swapfile, create and enable"
    fallocate -l "${SWAP_SIZE}G" /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    # cp /etc/fstab /etc/fstab.bak
    # echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

# Set swappiness to 5
cat /proc/sys/vm/swappiness

sudo sysctl vm.swappiness=${SWAP_LEVEL}
echo 'vm.swappiness=${SWAP_LEVEL}' | sudo tee -a /etc/sysctl.conf

# Disable password login via ssh
sed -i '/^PasswordAuthentication.*/d' /etc/ssh/sshd_config
echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config
service ssh restart

# Mount volume first
create_and_mount_volume() {
    device_name=$1
    mount_folder=$2
    device="/dev/${device_name}"
    # Only process if the system has this device
    if lsblk | grep "${device_name}"; then
        # Skip if already mounted
        if [ $(mount | grep -c "${device}") != 1 ]; then
            echo "Trying to mount this device ${device} ..."
            echo "Checking whether to use mkfs (make linux filesystem) ..."
            if blkid | grep "${device}"; then
                echo "Device ${device} already mkfs, just mount"
            else
                echo "Found error: $?, safe to mkfs"
                mkfs -t ext4 "${device}"
            fi
            mkdir -p "${mount_folder}"
            mount "${device}" "${mount_folder}"
        else
            echo "Device ${device} already mounted"
        fi
    fi
}
create_and_mount_volume "nbd1" "/storage"
create_and_mount_volume "vdb" "/storage"
create_and_mount_volume "vdc" "/storage2"
create_and_mount_volume "vdd" "/storage3"
create_and_mount_volume "nbd2" "/storage2"
create_and_mount_volume "nbd3" "/storage3"

#################################################################################################################

# Install docker 18.03 CE
if docker -v; then
    echo "Docker is already installed with: [$(docker -v)]"
else
    echo "Not found docker, trying to install docker ${DOCKER} CE"
    curl "https://releases.rancher.com/install-docker/${DOCKER}.sh" | sh
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

if ! [ -z ${RANCHER+x} ]; then
  if [ "$RANCHER" = "true" ]; then
    if docker ps | grep rancher/server; then
        echo "Rancher server is running, no need to install"
    else
        echo "Not found rancher, trying to install rancher/server:v1.6.17"
        mkdir -p /storage/rancher-mysql
        docker run -d --restart=unless-stopped -p 8080:8080 -v /storage/rancher-mysql:/var/lib/mysql -e JAVA_OPTS="-Xms2048m -Xmx2048m" --name=rancher-server rancher/server:v1.6.17
    fi
  fi
fi

# Download rancher CLI + compose
if rancher -v; then
    echo "Rancher CLI is already installed with: $(rancher -v)"
else
    echo "Installing Rancher CLI"
    # wget "https://releases.rancher.com/cli/v0.6.9/rancher-linux-amd64-v0.6.9.tar.gz"
    # tar xzf rancher-linux-amd64-v0.6.9.tar.gz
    # mv rancher-v0.6.9/rancher /usr/local/bin
    # rm rancher-linux-amd64-v0.6.9.tar.gz

    wget "https://releases.rancher.com/cli/v0.6.10-rc1/rancher-linux-amd64-v0.6.10-rc1.tar.gz"
    tar xzf rancher-linux-amd64-v0.6.10-rc1.tar.gz
    mv rancher-v0.6.10-rc1/rancher /usr/local/bin
    rm rancher-linux-amd64-v0.6.10-rc1.tar.gz
fi

if rancher-compose -v; then
    echo "Rancher Compose is already installed with: $(rancher-compose -v)"
else
    echo "Installing Rancher Compose"
    wget "https://releases.rancher.com/compose/v0.12.5/rancher-compose-linux-amd64-v0.12.5.tar.gz"
    tar xzf rancher-compose-linux-amd64-v0.12.5.tar.gz
    mv rancher-compose-v0.12.5/rancher-compose /usr/local/bin
fi

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

# Copy logdocker helper script
if ! cat /usr/local/bin/logdocker.sh; then
  echo "Copy logdocker file ..."
  curl -H 'Cache-Control: no-cache' https://raw.githubusercontent.com/duchoang/server-setup/master/logdocker.sh > logdocker.sh
  mv logdocker.sh /usr/local/bin/logdocker.sh
  chmod +x /usr/local/bin/logdocker.sh
  cat /usr/local/bin/logdocker.sh
fi

# Increase config system
sysctl -w vm.max_map_count=262144
echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf

#############################################################

# Block port by iptables
if ! cat /etc/network/if-pre-up.d/firewall; then
echo "Setting for iptables to block all port except 80/443/8080"
iptables -F INPUT

# allow established sessions to receive traffic
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# allow your application port
iptables -I INPUT -p tcp --dport 8080 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# allow SSH 
iptables -I INPUT -p tcp --dport 22 -j ACCEPT

# Allow Ping
iptables -A INPUT -p icmp --icmp-type 0 -m state --state ESTABLISHED,RELATED -j ACCEPT

# allow localhost 
iptables -A INPUT -i lo -j ACCEPT

iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -m conntrack --ctstate INVALID -j DROP

# block everything else 
iptables -A INPUT -j DROP

iptables-save > /etc/network/iptables.rules
cat << EOF >> /etc/network/if-pre-up.d/firewall
#!/bin/sh
/sbin/iptables-restore < /etc/network/iptables.rules
EOF
chmod +x /etc/network/if-pre-up.d/firewall
fi

######################################## ONLY FOR SCALEWAY SERVER ########################################

# Script to run at boot
BOOT_SCRIPT='/root/scaleway_boot.sh'
BOOT_SERVICE_NAME='scalewayboot'
BOOT_SERVICE="/etc/systemd/system/${BOOT_SERVICE_NAME}.service"
if ! [ -z ${SCALEWAY+x} ]; then
  if [ "$SCALEWAY" = "true" ]; then
    cat >${BOOT_SCRIPT} <<EOL
#!/bin/bash

mount_volume() {
    device_name=\$1
    mount_folder=\$2
    device="/dev/\${device_name}"
    if lsblk | grep "\${device_name}"; then
        mkdir -p "\${mount_folder}"
        mount "\${device}" "\${mount_folder}"
        echo "Done mounting device \${device} to \${mount_folder} with exit code = \$? !!!"
    fi
}
mount_volume "nbd1" "/storage"
mount_volume "vdb" "/storage"
mount_volume "vdc" "/storage2"
mount_volume "vdd" "/storage3"
mount_volume "nbd2" "/storage2"
mount_volume "nbd3" "/storage3"

if ! swapon -s | grep /swapfile; then
    echo "Turn on /swapfile"
    swapon /swapfile
fi

echo "Done init boot"
EOL
    chmod +x ${BOOT_SCRIPT}

    # Setup systemd service to run boot script at startup
    cat >${BOOT_SERVICE} <<EOL
[Unit]
Description=Scaleway Boot init
Wants=network-online.target local-fs.target
After=network-online.target

[Service]
Restart=on-failure
WorkingDirectory=/root/
ExecStart=/bin/bash ${BOOT_SCRIPT}

[Install]
WantedBy=multi-user.target
EOL

    # Enable service above
    systemctl enable ${BOOT_SERVICE_NAME}

    # view log of above service
    # journalctl -u ${BOOT_SERVICE_NAME}

  fi
fi
echo "DONE INIT SETUP !!!"
