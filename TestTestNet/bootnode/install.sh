#!/bin/bash
set -e
set -u
set -x

echo "========== dev/bootnode/install.sh starting =========="
echo "===== current time: $(date)"
echo "===== username: $(whoami)"
echo "===== working directory: $(pwd)"
echo "===== operating system info:"
lsb_release -a
echo "===== memory usage info:"
free -m
EXT_IP="$(curl ifconfig.co)"
echo "===== external ip: ${EXT_IP}"

echo "===== printenv:"
printenv
echo "===== env:"
env
echo "===== set:"
set
echo "===== declare -p:"
declare -p

#echo "===== AFTER SUDO"
#echo "===== SUDO printenv:"
#sudo -u root -E -H bash -c "printenv"
#echo "===== SUDO env:"
#sudo -u root -E -H bash -c "env"
#echo "===== SUDO set:"
#sudo -u root -E -H bash -c "set"
#echo "===== SUDO declare -p:"
#sudo -u root -E -H bash -c "declare -p"

# script parameters
INSTALL_DOCKER_VERSION="17.03.1~ce-0~ubuntu-xenial"
INSTALL_DOCKER_IMAGE="parity/parity:v1.6.8"
INSTALL_CONFIG_REPO="https://raw.githubusercontent.com/oraclesorg/test-templates/dev/TestTestNet/bootnode"
GENESIS_REPO_LOC="https://raw.githubusercontent.com/oraclesorg/oracles-scripts/devtestnet/spec.json"
GENESIS_JSON="spec.json"
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

#echo "===== HOME before: ${HOME:-NONE}"
export HOME="${HOME:-/home/${ADMIN_USERNAME}}"
#echo "===== HOME after: ${HOME}"

prepare_homedir() {
    echo "=====> prepare_homedir"
    # ln -s "$(pwd)" "/home/${ADMIN_USERNAME}/script-dir"
    cd "/home/${ADMIN_USERNAME}"
    echo "Now changed directory to: $(pwd)"
    mkdir -p logs
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
    # curl -sL https://deb.nodesource.com/setup_0.12 | bash -
    curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash -
    sudo apt-get update
    sudo apt-get install -y build-essential git unzip wget nodejs ntp cloud-utils

    # add symlink if it doesn't exist
    [[ ! -f /usr/bin/node ]] && sudo ln -s /usr/bin/nodejs /usr/bin/node
    echo "<===== install_nodejs"
}

install_dashboard() {
    echo "=====> install_dashboard"
    git clone https://github.com/oraclesorg/eth-netstats
    cd eth-netstats
    npm install
    sudo npm install -g grunt-cli
    sudo npm install pm2 -g
    grunt

#    cat > app.json << EOF
#[
#    {
#        "name"                 : "netstats-dashboard",
#        "script"               : "bin/www",
#        "log_date_format"      : "YYYY-MM-DD HH:mm:SS Z",
#        "error_file"           : "/home/${ADMIN_USERNAME}/logs/dashboard.err",
#        "out_file"             : "/home/${ADMIN_USERNAME}/logs/dashboard.out",
#        "merge_logs"           : false,
#        "watch"                : false,
#        "max_restarts"         : 100,
#        "exec_interpreter"     : "node",
#        "exec_mode"            : "fork_mode",
#        "env":
#        {
#            "NODE_ENV"         : "production",
#            "WS_SECRET"        : "${NETSTATS_SECRET}"
#        }
#    }
#]
#EOF
    echo "[\"${NETSTATS_SECRET}\"]" > ws_secret.json
    cd ..
    apt-get install -y dtach
    cat > dashboard.start <<EOF
dtach -n dashboard bash -c "cd eth-netstats && npm start >> ../logs/dashboard.out 2>> ../logs/dashboard.err"
EOF
    chmod +x dashboard.start
    ./dashboard.start
    echo "<====== install_dashboard"
}

# based on https://get.parity.io
install_netstats() {
    echo "=====> install_netstats"
    git clone https://github.com/oraclesorg/eth-net-intelligence-api
    cd eth-net-intelligence-api
    #sed -i '/"web3"/c "web3": "0.19.x",' package.json
    sudo npm install
    sudo npm install pm2 -g

    cat > app.json << EOF
[
    {
        "name"                 : "netstats-daemon",
        "script"               : "app.js",
        "log_date_format"      : "YYYY-MM-DD HH:mm:SS Z",
        "error_file"           : "/home/${ADMIN_USERNAME}/logs/dashboard.err",
        "out_file"             : "/home/${ADMIN_USERNAME}/logs/dashboard.out",
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
    cd ..
    cat > netstats.start <<EOF
cd eth-net-intelligence-api
pm2 startOrRestart app.json
cd ..
EOF
    chmod +x netstats.start
    ./netstats.start
    echo "<===== install_netstats"
}

install_chain_explorer() {
    echo "=====> install_chain_explorer"
    git clone https://github.com/oraclesorg/chain-explorer
    git clone https://github.com/ethereum/solc-bin chain-explorer/utils/solc-bin
    cd chain-explorer
    npm install
    cat > config.js <<EOF
var web3 = require('web3');
var net = require('net');

var config = function () {
    this.logFormat = "combined";
    this.ipcPath = "/home/${ADMIN_USERNAME}/parity/jsonrpc.ipc";
    this.provider = new web3.providers.IpcProvider(this.ipcPath, net);
    this.bootstrapUrl = "https://maxcdn.bootstrapcdn.com/bootswatch/3.3.7/yeti/bootstrap.min.css";
    this.names = {
        "0xdd0bb0e2a1594240fed0c2f2c17c1e9ab4f87126": "Bootnode",
    };
}

module.exports = config;
EOF
#    sudo apt-get install -y dtach
#    cat > explorer.start <<EOF
#dtach -n explorer bash -c "cd chain-explorer; PORT=4000 npm start > ../logs/explorer.out 2> ../logs/explorer.err"
#EOF

    cat > app.json << EOF
[
    {
        "name"                 : "explorer",
        "script"               : "./bin/www",
        "log_date_format"      : "YYYY-MM-DD HH:mm:SS Z",
        "error_file"           : "/home/${ADMIN_USERNAME}/logs/explorer.err",
        "out_file"             : "/home/${ADMIN_USERNAME}/logs/explorer.out",
        "merge_logs"           : false,
        "watch"                : false,
        "max_restarts"         : 100,
        "exec_interpreter"     : "node",
        "exec_mode"            : "fork_mode",
        "env":
        {
            "NODE_ENV"         : "production",
            "PORT"             : 4000,
        }
    }
]
EOF
    cd ..
    cat > explorer.start <<EOF
cd chain-explorer
pm2 startOrRestart app.json
cd ..
EOF
    chmod +x explorer.start
    sudo ./explorer.start
    echo "<===== install_chain_explorer"
}

start_docker() {
    echo "=====> start_docker"
    cat > docker.start << EOF
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
    ${INSTALL_DOCKER_IMAGE} -lengine=trace --config "${NODE_TOML}" --ui-no-validation > logs/docker.out 2> logs/docker.err
container_id="\$(cat logs/docker.out)"
sudo ln -sf "/var/lib/docker/containers/\${container_id}/\${container_id}-json.log" logs/parity.log
EOF
    chmod +x docker.start
    ./docker.start
    echo "<===== start_docker"
}

use_deb() {
    echo "=====> use_deb"
    curl -O http://d1h4xl4cr1h0mo.cloudfront.net/v1.6.8/x86_64-unknown-linux-gnu/parity_1.6.8_amd64.deb
    dpkg -i parity_1.6.8_amd64.deb
    apt install dtach
    
    cat > rundeb.sh << EOF
sudo parity -lengine=trace --config "${NODE_TOML}" --ui-no-validation >> parity.out 2>> parity.err
EOF
    chmod +x rundeb.sh
    dtach -n par "./rundeb.sh"
    echo "<===== use_deb"
}

setup_autoupdate() {
    echo "=====> setup_autoupdate"
    sudo docker pull oraclesorg/docker-run
    sudo bash -c "cat > /etc/cron.daily/docker-autoupdate << EOF
#!/bin/sh
outlog='/home/${ADMIN_USERNAME}/logs/docker-autoupdate.out'
errlog='/home/${ADMIN_USERNAME}/logs/docker-autoupdate.err'
echo \"Starting: \\\$(date)\" >> \"\\\${outlog}\"
echo \"Starting: \\\$(date)\" >> \"\\\${errlog}\"
sudo docker run --rm -v /var/run/docker.sock:/tmp/docker.sock oraclesorg/docker-run update >> \"\\\${outlog}\" 2>> \"\\\${errlog}\"
echo \"\" >> \"\\\${outlog}\"
echo \"\" >> \"\\\${errlog}\"
EOF"
    sudo chmod 755 /etc/cron.daily/docker-autoupdate
    echo "<===== setup_autoupdate"
}

# MAIN
main () {
    sudo apt-get update

    prepare_homedir
    install_ntpd
    install_haveged
    allocate_swap

    install_nodejs
    install_docker_ce
    pull_image_and_configs
    clone_dapps

    start_docker
    #use_deb

    setup_autoupdate

    install_dashboard
    install_netstats
    install_chain_explorer
}

main
echo "========== dev/bootnode/install.sh finished =========="
