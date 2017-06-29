#!/usr/bin/env bash
set -e
set -u
set -x

echo "========== mining-node/install.sh starting =========="
echo "===== current time: $(date)"
echo "===== username: $(whoami)"
echo "===== working directory: $(pwd)"
echo "===== operating system info:"
lsb_release -a
echo "===== memory usage info:"
free -m
EXT_IP="$(curl ifconfig.co)"
echo "===== external ip: ${EXT_IP}"
echo "===== environmental variables:"
printenv

# script parameters
INSTALL_DOCKER_VERSION="17.03.1~ce-0~ubuntu-xenial"
INSTALL_DOCKER_IMAGE="parity/parity:v1.6.8"
INSTALL_CONFIG_REPO="https://raw.githubusercontent.com/oraclesorg/test-templates/master/TestTestNet/mining-node"
GENESIS_REPO_LOC="https://raw.githubusercontent.com/oraclesorg/oracles-scripts/master/spec.json"
GENESIS_JSON="spec.json"
NODE_TOML="node.toml"
NODE_PWD="node.pwd"
HOME="${HOME:-/root}"

echo "===== will use docker version: ${INSTALL_DOCKER_VERSION}"
echo "===== will use parity docker image: ${INSTALL_DOCKER_IMAGE}"
echo "===== repo base path: ${INSTALL_CONFIG_REPO}"

# this should be provided through env by azure template
NETSTATS_SERVER="${NETSTATS_SERVER}"
NETSTATS_SECRET="${NETSTATS_SECRET}"
MINING_KEYFILE="${MINING_KEYFILE}"
MINING_ADDRESS="${MINING_ADDRESS}"
MINING_KEYPASS="${MINING_KEYPASS}"
NODE_FULLNAME="${NODE_FULLNAME:-Anonymous}"
NODE_ADMIN_EMAIL="${NODE_ADMIN_EMAIL:-somebody@somehere}"
ADMIN_USERNAME="${ADMIN_USERNAME}"

prepare_homedir() {
    echo "=====> prepare_homedir"
    #ln -s "$(pwd)" "/home/${ADMIN_USERNAME}/script-dir"
    cd "/home/${ADMIN_USERNAME}"
    echo "<===== prepare_homedir"
}

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

install_nodejs() {
    echo "=====> install_nodejs"
    # curl -sL https://deb.nodesource.com/setup_0.12 | bash -
    curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash -
    sudo apt-get update
    sudo apt-get install -y build-essential git unzip wget nodejs ntp cloud-utils

    # add symlink if it doesn't exist
    [[ ! -f /usr/bin/node ]] && sudo ln -s /usr/bin/nodejs /usr/bin/node
    echo "<===== install_nodejs"
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

    # curl -s -O "${INSTALL_CONFIG_REPO}/../${GENESIS_JSON}"
    curl -s -o "${GENESIS_JSON}" "${GENESIS_REPO_LOC}"
    curl -s -O "${INSTALL_CONFIG_REPO}/${NODE_TOML}"
    sed -i "/\[network\]/a nat=\"extip:${EXT_IP}\"" ${NODE_TOML}
    cat >> ${NODE_TOML} <<EOF
[account]
password = ["${NODE_PWD}"]
unlock = ["${MINING_ADDRESS}"]
[mining]
force_sealing = true
engine_signer = "${MINING_ADDRESS}"
reseal_on_txs = "none"
EOF
    echo "${MINING_KEYPASS}" > "${NODE_PWD}"
    mkdir -p parity/keys/OraclesPoA
    echo ${MINING_KEYFILE} | base64 -d > parity/keys/OraclesPoA/mining.key.${MINING_ADDRESS}
    echo "<===== pull_image_and_configs"
}

# based on https://get.parity.io
install_netstats() {
    echo "=====> install_netstats"
    git clone https://github.com/cubedro/eth-net-intelligence-api
    cd eth-net-intelligence-api
    sed -i '/"web3"/c "web3": "0.19.x",' package.json
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
            "INSTANCE_NAME"    : "${NODE_FULLNAME}",
            "CONTACT_DETAILS"  : "${NODE_ADMIN_EMAIL}",
            "WS_SERVER"        : "http://${NETSTATS_SERVER}:3000",
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
sudo docker run -d \\
    --name oracles-poa \\
    -p 30300:30300 \\
    -p 30300:30300/udp \\
    -p 8080:8080 \\
    -p 8180:8180 \\
    -p 8540:8540 \\
    -v "$(pwd)/${NODE_PWD}:/build/${NODE_PWD}" \\
    -v "$(pwd)/parity:/build/parity" \\
    -v "$(pwd)/${GENESIS_JSON}:/build/${GENESIS_JSON}" \\
    -v "$(pwd)/${NODE_TOML}:/build/${NODE_TOML}" \\
    ${INSTALL_DOCKER_IMAGE} --config "${NODE_TOML}"
EOF
    chmod +x rundocker.sh
    ./rundocker.sh
    echo "<===== start_docker"
}

use_deb() {
    echo "=====> use_deb"
    curl -O http://d1h4xl4cr1h0mo.cloudfront.net/v1.6.8/x86_64-unknown-linux-gnu/parity_1.6.8_amd64.deb
    dpkg -i parity_1.6.8_amd64.deb
    apt install dtach
    
    cat > rundeb.sh << EOF
sudo parity --config "${NODE_TOML}" >> parity.out 2>> parity.err
EOF
    chmod +x rundeb.sh
    dtach -n par "./rundeb.sh"
    echo "<===== use_deb"
}

install_scripts() {
    echo "=====> install_scripts"
    git clone https://github.com/oraclesorg/oracles-scripts
    cd oracles-scripts/scripts
    npm install
    sudo cat > /etc/cron.hourly/transferRewardToPayoutKey << EOF
#!/bin/bash
cd "$(pwd)"
echo "Running transferRewardToPayoutKey at $(date)" >> transferRewardToPayoutKey.out
echo "Running transferRewardToPayoutKey at $(date)" >> transferRewardToPayoutKey.err
node transferRewardToPayoutKey.js >> transferRewardToPayoutKey.out 2>> transferRewardToPayoutKey.err
echo "" >> transferRewardToPayoutKey.out
echo "" >> transferRewardToPayoutKey.err
EOF
    sudo chmod 755 /etc/cron.hourly/transferRewardToPayoutKey
    cd ../..
    echo "<===== install_scripts"
}

setup_autoupdate() {
    echo "=====> setup_autoupdate"
    docker pull itech/docker-run
    cat > /etc/cron.daily/docker-autoupdate << EOF
#!/bin/sh
echo "Starting: $(date)" >> /home/${ADMIN_USERNAME}/docker-autoupdate.out
echo "Starting: $(date)" >> /home/${ADMIN_USERNAME}/docker-autoupdate.err
sudo docker run --rm -v /var/run/docker.sock:/tmp/docker.sock itech/docker-run update >> /home/${ADMIN_USERNAME}/docker-autoupdate.out 2>> /home/${ADMIN_USERNAME}/docker-autoupdate.err
echo "" >> /home/${ADMIN_USERNAME}/docker-autoupdate.out
echo "" >> /home/${ADMIN_USERNAME}/docker-autoupdate.err
EOF
    sudo chmod 755 /etc/cron.daily/docker-autoupdate
    echo "<===== setup_autoupdate"
}

# MAIN
main () {
    prepare_homedir

    install_ntpd
    install_haveged
    allocate_swap

    install_nodejs
    install_docker_ce
    pull_image_and_configs

    start_docker
    #use_deb
    
    setup_autoupdate

    install_netstats
    install_scripts
}

main
echo "========== mining-node/install.sh finished =========="
