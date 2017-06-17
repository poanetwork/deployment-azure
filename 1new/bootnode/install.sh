#!/usr/bin/env bash
set -e
set -u
set -x

echo "========== bootnode/install.sh starting =========="
echo "===== current time: $(date)"
echo "===== username: $(whoami)"
echo "===== working directory: $(pwd)"
echo "===== operating system info:"
lsb_release -a
echo "===== memory usage info:"
free -m
echo "===== environmental variables:"
printenv

# script parameters
INSTALL_DOCKER_VERSION="17.03.1~ce-0~ubuntu-xenial"
INSTALL_DOCKER_IMAGE="ethcore/parity:v1.6.6"
INSTALL_CONFIG_REPO="https://raw.githubusercontent.com/oraclesorg/test-templates/master/1new/bootnode"
GENESIS_JSON="genesis.json"
NODE_TOML="node.toml"
NODE_PWD="node.pwd"

echo "===== will use docker version: ${INSTALL_DOCKER_VERSION}"
echo "===== will use parity docker image: ${INSTALL_DOCKER_IMAGE}"
echo "===== repo base path: ${INSTALL_CONFIG_REPO}"

# this should be provided through env by azure template
NETSTATS_SECRET="${NETSTATS_SECRET}"
OWNER_KEYFILE="${OWNER_KEYFILE}"
OWNER_KEYPASS="${OWNER_KEYPASS}"
NODE_FULLNAME="${NODE_FULLNAME:-Bootnode}"
NODE_ADMIN_EMAIL="${NODE_ADMIN_EMAIL:-somebody@somehere}"
ADMIN_USERNAME="${ADMIN_USERNAME}"

prepare_homedir() {
    ln -s "$(pwd)" "/home/${ADMIN_USERNAME}/script-dir"
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

    curl -s -O "${INSTALL_CONFIG_REPO}/../${GENESIS_JSON}"
    curl -s -O "${INSTALL_CONFIG_REPO}/${NODE_TOML}"
    echo "${OWNER_KEYPASS}" > "${NODE_PWD}"
    mkdir -p parity/keys/OraclesPoA
    echo ${OWNER_KEYFILE} | base64 -d > parity/keys/OraclesPoA/owner.key

    echo "<===== pull_image_and_configs"
}

clone_dapps() {
    echo "=====> clone_dapps"
    mkdir -p parity/dapps
    git clone https://github.com/oraclesorg/oracles-dapps-keys-generation.git parity/dapps/KeysGenerator
    git clone https://github.com/oraclesorg/oracles-dapps-voting.git parity/dapps/Voting
    git clone https://github.com/oraclesorg/oracles-dapps-validators.git parity/dapps/ValidatorsList
    echo "<===== clone_dapps"
}

install_nodejs() {
    echo "=====> install_nodejs"
    curl -sL https://deb.nodesource.com/setup_0.12 | bash -
    sudo apt-get update
    sudo apt-get install -y build-essential git unzip wget nodejs ntp cloud-utils
    sudo apt-get install -y npm

    # add symlink if it doesn't exist
    [[ ! -f /usr/bin/node ]] && sudo ln -s /usr/bin/nodejs /usr/bin/node
    echo "<===== install_nodejs"
}

install_dashboard() {
    echo "=====> install_dashboard"
    git clone https://github.com/cubedro/eth-netstats
    cd eth-netstats
    npm install
    sudo npm install -g grunt-cli
    sudo npm install pm2 -g
    grunt
    
    cat > app.json << EOF
[
    {
        "name"                 : "netstats-dashboard",
        "script"               : "bin/www",
        "log_date_format"      : "YYYY-MM-DD HH:mm:SS Z",
        "merge_logs"           : false,
        "watch"                : false,
        "max_restarts"         : 100,
        "exec_interpreter"     : "node",
        "exec_mode"            : "fork_mode",
        "env":
        {
            "NODE_ENV"         : "production",
            "WS_SECRET"        : "${NETSTATS_SECRET}"
        }
    }
]
EOF
    # nohup npm start &
    pm2 startOrRestart app.json
    cd ..
    echo "<====== install_dashboard"
}

# based on https://get.parity.io
install_netstats() {
    echo "=====> install_netstats"
    git clone https://github.com/cubedro/eth-net-intelligence-api
    cd eth-net-intelligence-api
    sudo npm install
    sudo npm install pm2 -g
    
    cat > app.json << EOF
[
    {
        "name"                 : "netstats-daemon",
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
            "WS_SERVER"        : "http://localhost:3000",
            "WS_SECRET"        : "${NETSTATS_SECRET}",
            "VERBOSITY"        : 2
        }
    }
]
EOF
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
    -p 8080:8080 \\
    -p 8180:8180 \\
    -p 8540:8540 \\
    -v "$(pwd)/${NODE_PWD}:/build/${NODE_PWD}" \\
    -v "$(pwd)/parity:/tmp/parity" \\
    -v "$(pwd)/${GENESIS_JSON}:/build/${GENESIS_JSON}" \\
    -v "$(pwd)/${NODE_TOML}:/build/${NODE_TOML}" \\
    ${INSTALL_DOCKER_IMAGE} --config "${NODE_TOML}" --ui-no-validation
EOF
    chmod +x rundocker.sh
    ./rundocker.sh
    echo "<===== start_docker"
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
    clone_dapps

    start_docker

    install_netstats
    install_dashboard
}

main
echo "========== bootnode/install.sh finished =========="
