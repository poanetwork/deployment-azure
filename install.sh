#!/usr/bin/env bash
set -e
set -u
set -x

# script parameters
INSTALL_DOCKER_VERSION="17.03.1~ce-0~ubuntu-xenial"
INSTALL_CONFIG_REPO="https://raw.githubusercontent.com/oraclesorg/test-templates/master"

# install ntpd, replace timesyncd
sudo timedatectl set-ntp no
sudo apt-get -y install ntp

# install haveged
sudo apt-get -y install haveged
sudo update-rc.d haveged defaults

# allocate swap
sudo apt-get -y install bc
#sudo fallocate -l $(echo "$(free -b | awk '/Mem/{ print $2 }')*2"  | bc -l) /swapfile
sudo fallocate -l 1G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
sudo sh -c "printf '/swapfile   none    swap    sw    0   0\n' >> /etc/fstab"
sudo sh -c "printf 'vm.swappiness=10\n' >> /etc/sysctl.conf"
sudo sysctl vm.vfs_cache_pressure=50
sudo sh -c "printf 'vm.vfs_cache_pressure = 50\n' >> /etc/sysctl.conf"

# download and install docker
sudo apt-get -y install apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get -y install docker-ce=${INSTALL_DOCKER_VERSION}

# pull image, configs and setup parity
sudo docker pull ethcore/parity:stable
curl -s -O "${INSTALL_CONFIG_REPO}/demo-spec.json"
curl -s -O "${INSTALL_CONFIG_REPO}/node.pwds"
curl -s -O "${INSTALL_CONFIG_REPO}/node-to-enode.toml"
sed -i 's/@172.16./@/g' node-to-enode.toml
mkdir parity-data

# start parity in docker
sudo docker run -d \
    --name eth-parity \
    -p 30300:30300 \
    -p 8080:8080 \
    -p 8180:8180 \
    -p 8540:8540 \
    -v "$(pwd)/node.pwds:/build/node.pwds" \
    -v "$(pwd)/parity-data:/tmp/parity" \
    -v "$(pwd)/demo-spec.json:/build/demo-spec.json" \
    -v "$(pwd)/node-to-enode.toml:/build/node-to-enode.toml" \
    ethcore/parity:stable --config "node-to-enode.toml"
