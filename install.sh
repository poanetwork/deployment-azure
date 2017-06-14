#!/usr/bin/env bash
set -e
set -u
set -x

echo "========== INSTALL.sh starting =========="
echo "whoami: $(whoami)"
echo "pwd: $(pwd)"

# script parameters
INSTALL_DOCKER_VERSION="17.03.1~ce-0~ubuntu-xenial"
INSTALL_DOCKER_IMAGE="ethcore/parity:beta-release"
INSTALL_CONFIG_REPO="https://raw.githubusercontent.com/oraclesorg/test-templates/master"
GENESIS_JSON="demo-spec.json"
NODE_TOML="node-to-enode.toml"

# this should be replaced or provided through env by azure template
NETSTATS_SECRET="${NETSTATS_SECRET:-1234321}"

install_ntpd() {
    echo "=====> install_ntpd"
    sudo timedatectl set-ntp no
    sudo apt-get -y install ntp

    sudo bash -c "cat > /etc/cron.hourly/ntpdate << EOF
#!/bin/sh
sudo service ntp stop
sudo ntpdate -s ntp.ubuntu.com
sudo service ntp start
EOF"
    sudo chmod 755 /etc/cron.hourly/ntpdate
    echo "<===== install_ntpd"
}

install_haveged() {
    echo "=====> install_haveged"
    sudo apt-get -y install haveged
    sudo update-rc.d haveged defaults
    echo "<===== install_haveged"
}

allocate_swap() {
    echo "=====> allocate_swap"
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
    echo "<===== allocate_swap"
}

install_docker_ce() {
    echo "=====> install_docker_ce"
    sudo apt-get -y install apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt-get update
    sudo apt-get -y install docker-ce=${INSTALL_DOCKER_VERSION}
    echo "<===== install_docker_ce"
}

pull_image_and_configs() {
    echo "=====> pull_image_and_configs"
    sudo docker pull ${INSTALL_DOCKER_IMAGE}
    curl -s -O "${INSTALL_CONFIG_REPO}/${GENESIS_JSON}"
    curl -s -O "${INSTALL_CONFIG_REPO}/node.pwds"
    curl -s -O "${INSTALL_CONFIG_REPO}/${NODE_TOML}"
    sed -i 's/@172.16./@/g' ${NODE_TOML}
    mkdir parity-data
    echo "<===== pull_image_and_configs"
}

# based on https://get.parity.io
install_netstats() {
    echo "=====> install_netstats"
    # install node.js
    curl -sL https://deb.nodesource.com/setup_0.12 | bash -
    sudo apt-get update
    sudo apt-get install -y build-essential git unzip wget nodejs ntp cloud-utils
    sudo apt-get install -y npm

    # add symlink if it doesn't exist
    [[ ! -f /usr/bin/node ]] && sudo ln -s /usr/bin/nodejs /usr/bin/node

    git clone https://github.com/cubedro/eth-net-intelligence-api netstats
    cd netstats
    sudo npm install
    sudo npm install pm2 -g

    cat > app.json << EOL
[
    {
        "name"                 : "node-app",
        "script"               : "app.js",
        "log_date_format"      : "YYYY-MM-DD HH:mm:SS Z",
        "merge_logs"           : false,
        "watch"                : false,
        "max_restarts"         : 100,
        "exec_interpreter"     : "node",
        "exec_mode"            : "fork_mode",
        "env":
        {
            "NODE_ENV"         : "production",
            "RPC_HOST"         : "localhost",
            "RPC_PORT"         : "8540",
            "LISTENING_PORT"   : "30300",
            "INSTANCE_NAME"    : "Oracles TestNet",
            "CONTACT_DETAILS"  : "nobody@nowhere",
            "WS_SERVER"        : "wss://rpc.ethstats.net",
            "WS_SECRET"        : "${NETSTATS_SECRET}",
            "VERBOSITY"        : 2
        }
    }
]
EOL
    pm2 startOrRestart app.json
    cd ..
    echo "<===== install_netstats"
}

start_docker() {
    echo "=====> start_docker"
    cat > rundocker.sh << EOF
sudo docker run -d \
    --name eth-parity \
    -p 30300:30300 \
    -p 8080:8080 \
    -p 8180:8180 \
    -p 8540:8540 \
    -v "$(pwd)/node.pwds:/build/node.pwds" \
    -v "$(pwd)/parity-data:/tmp/parity" \
    -v "$(pwd)/${GENESIS_JSON}:/build/${GENESIS_JSON}" \
    -v "$(pwd)/${NODE_TOML}:/build/${NODE_TOML}" \
    ${INSTALL_DOCKER_IMAGE} --config "${NODE_TOML}" --ui-no-validation
EOF
    chmod +x rundocker.sh
    ./rundocker.sh
    echo "<===== start_docker"
}

# MAIN
main () {
    install_ntpd
    install_haveged
    allocate_swap
    install_docker_ce
    pull_image_and_configs

    start_docker

    install_netstats
}

main
