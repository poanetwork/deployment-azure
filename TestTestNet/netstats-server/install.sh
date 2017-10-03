#!/bin/bash
set -e
set -u
set -x

EXT_IP="$(curl ifconfig.co)"

# Install logentries daemon /*
start_logentries() {
    echo "=====> start_logentries"
    sudo bash -c "echo 'deb http://rep.logentries.com/ trusty main' > /etc/apt/sources.list.d/logentries.list"
    sudo bash -c "gpg --keyserver pgp.mit.edu --recv-keys C43C79AD && gpg -a --export C43C79AD | apt-key add -"
    sudo apt-get update
    sudo apt-get install -y logentries
    sudo le reinit --user-key=0665901a-e843-41c5-82c1-2cc4b39f0b21 --pull-server-side-config=False

    mkdir -p /home/${ADMIN_USERNAME}/logs
    touch /home/${ADMIN_USERNAME}/logs/dashboard.err
    touch /home/${ADMIN_USERNAME}/logs/dashboard.out
    touch /home/${ADMIN_USERNAME}/logs/parity.log
    touch /home/${ADMIN_USERNAME}/logs/netstats_daemon.err
    touch /home/${ADMIN_USERNAME}/logs/netstats_daemon.out
    touch /home/${ADMIN_USERNAME}/logs/explorer.err
    touch /home/${ADMIN_USERNAME}/logs/explorer.out
    touch /home/${ADMIN_USERNAME}/logs/parity.err
    touch /home/${ADMIN_USERNAME}/logs/parity.out

    sudo bash -c "cat >> /etc/le/config << EOF
[install_err]
path = /var/lib/waagent/custom-script/download/0/stderr
destination = dev-mainnet/${EXT_IP}

[install_out]
path = /var/lib/waagent/custom-script/download/0/stdout
destination = dev-mainnet/${EXT_IP}

[dashboard_err]
path = /home/${ADMIN_USERNAME}/logs/dashboard.err
destination = dev-mainnet/${EXT_IP}

[dashboard_out]
path = /home/${ADMIN_USERNAME}/logs/dashboard.out
destination = dev-mainnet/${EXT_IP}

[parity_log]
path = /home/${ADMIN_USERNAME}/logs/parity.log
destination = dev-mainnet/${EXT_IP}

[netstats_daemon_err]
path = /home/${ADMIN_USERNAME}/logs/netstats_daemon.err
destination = dev-mainnet/${EXT_IP}

[netstats_daemon_out]
path = /home/${ADMIN_USERNAME}/logs/netstats_daemon.out
destination = dev-mainnet/${EXT_IP}

[explorer_err]
path = /home/${ADMIN_USERNAME}/logs/explorer.err
destination = dev-mainnet/${EXT_IP}

[explorer_out]
path = /home/${ADMIN_USERNAME}/logs/explorer.out
destination = dev-mainnet/${EXT_IP}

[parity_err]
path = /home/${ADMIN_USERNAME}/logs/parity.err
destination = dev-mainnet/${EXT_IP}

[parity_out]
path = /home/${ADMIN_USERNAME}/logs/parity.out
destination = dev-mainnet/${EXT_IP}

EOF"
    sudo apt-get install -y logentries-daemon
    sudo service logentries start
    echo "<===== start_logentries"
}

start_logentries

# */

echo "========== dev-mainnet/netstats-server/install.sh starting =========="
echo "===== current time: $(date)"
echo "===== username: $(whoami)"
echo "===== working directory: $(pwd)"
echo "===== operating system info:"
lsb_release -a
echo "===== memory usage info:"
free -m
echo "===== external ip: ${EXT_IP}"

echo "===== printenv:"
printenv
echo "===== env:"
env
echo "===== set:"
set
echo "===== declare -p:"
declare -p

INSTALL_CONFIG_REPO="https://raw.githubusercontent.com/oraclesorg/test-templates/dev-mainnet/TestTestNet/bootnode"
GENESIS_REPO_LOC="https://raw.githubusercontent.com/oraclesorg/oracles-scripts/master/spec.json"
GENESIS_JSON="spec.json"
NODE_TOML="node.toml"
NODE_PWD="node.pwd"

echo "===== repo base path: ${INSTALL_CONFIG_REPO}"

# this should be provided through env by azure template
NETSTATS_SECRET="${NETSTATS_SECRET}"
NODE_FULLNAME="${NODE_FULLNAME:-NetStat}"
NODE_ADMIN_EMAIL="${NODE_ADMIN_EMAIL:-somebody@somehere}"
ADMIN_USERNAME="${ADMIN_USERNAME}"

export HOME="${HOME:-/home/${ADMIN_USERNAME}}"

prepare_homedir() {
    echo "=====> prepare_homedir"
    # ln -s "$(pwd)" "/home/${ADMIN_USERNAME}/script-dir"
    cd "/home/${ADMIN_USERNAME}"
    echo "Now changed directory to: $(pwd)"
    mkdir -p logs
    mkdir -p logs/old
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

pull_image_and_configs() {
    echo "=====> pull_image_and_configs"
    # curl -s -O "${INSTALL_CONFIG_REPO}/../${GENESIS_JSON}"
    curl -s -o "${GENESIS_JSON}" "${GENESIS_REPO_LOC}"
    curl -s -O "${INSTALL_CONFIG_REPO}/${NODE_TOML}"
    sed -i "/\[network\]/a nat=\"extip:${EXT_IP}\"" ${NODE_TOML}
    cat >> ${NODE_TOML} <<EOF
[misc]
logging="engine=trace,network=trace,discovery=trace"
log_file = "/home/${ADMIN_USERNAME}/logs/parity.log"
EOF
    mkdir -p parity/keys/OraclesPoA

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

start_pm2_via_systemd() {
    echo "=====> start_pm2_via_systemd"
        sudo bash -c "cat > /etc/systemd/system/oracles-pm2.service <<EOF
[Unit]
Description=oracles pm2 service
After=network.target
[Service]
Type=oneshot
RemainAfterExit=true
User=${ADMIN_USERNAME}
Group=${ADMIN_USERNAME}
Environment=MYVAR=myval
WorkingDirectory=/home/${ADMIN_USERNAME}
ExecStart=/usr/bin/pm2 ping
[Install]
WantedBy=multi-user.target
EOF"
    sudo systemctl enable oracles-pm2
    sudo systemctl start oracles-pm2
    echo "<===== start_pm2_via_systemd"
}

install_dashboard_via_systemd() {
    echo "=====> install_dashboard_via_systemd"
    git clone https://github.com/oraclesorg/eth-netstats
    cd eth-netstats
    npm install
    sudo npm install -g grunt-cli
    sudo npm install pm2 -g
    grunt
    echo "[\"${NETSTATS_SECRET}\"]" > ws_secret.json
    cd ..

    sudo bash -c "cat > /etc/systemd/system/oracles-dashboard.service <<EOF
[Unit]
Description=oracles dashboard service
After=network.target
[Service]
User=${ADMIN_USERNAME}
Group=${ADMIN_USERNAME}
Environment=MYVAR=myval
WorkingDirectory=/home/${ADMIN_USERNAME}/eth-netstats
Restart=always
ExecStart=/usr/bin/npm start
[Install]
WantedBy=multi-user.target
EOF"
    sudo systemctl enable oracles-dashboard
    sudo systemctl start oracles-dashboard
    echo "<====== install_dashboard_via_systemd"
}

# based on https://get.parity.io
install_netstats_via_systemd() {
    echo "=====> install_netstats_via_systemd"
    git clone https://github.com/oraclesorg/eth-net-intelligence-api
    cd eth-net-intelligence-api
    #sed -i '/"web3"/c "web3": "0.19.x",' package.json
    npm install
    sudo npm install pm2 -g

    cat > app.json << EOL
[
    {
        "name"                 : "netstats_daemon",
        "script"               : "app.js",
        "log_date_format"      : "YYYY-MM-DD HH:mm:SS Z",
        "error_file"           : "/home/${ADMIN_USERNAME}/logs/netstats_daemon.err",
        "out_file"             : "/home/${ADMIN_USERNAME}/logs/netstats_daemon.out",
        "merge_logs"           : false,
        "watch"                : false,
        "max_restarts"         : 100,
        "exec_interpreter"     : "node",
        "exec_mode"            : "fork_mode",
        "env":
        {
            "NODE_ENV"         : "production",
            "RPC_HOST"         : "localhost",
            "RPC_PORT"         : "8545",
            "LISTENING_PORT"   : "30300",
            "INSTANCE_NAME"    : "${NODE_FULLNAME}",
            "CONTACT_DETAILS"  : "${NODE_ADMIN_EMAIL}",
            "WS_SERVER"        : "http://localhost:3000",
            "WS_SECRET"        : "${NETSTATS_SECRET}",
            "VERBOSITY"        : 2
        }
    }
]
EOL
    cd ..
    sudo bash -c "cat > /etc/systemd/system/oracles-netstats.service <<EOF
[Unit]
Description=oracles netstats service
After=oracles-pm2.service
[Service]
Type=oneshot
RemainAfterExit=true
User=${ADMIN_USERNAME}
Group=${ADMIN_USERNAME}
Environment=MYVAR=myval
WorkingDirectory=/home/${ADMIN_USERNAME}/eth-net-intelligence-api
ExecStart=/usr/bin/pm2 startOrRestart app.json
[Install]
WantedBy=multi-user.target
EOF"
    sudo systemctl enable oracles-netstats
    sudo systemctl start oracles-netstats
    echo "<===== install_netstats_via_systemd"
}

install_chain_explorer_via_systemd() {
    echo "=====> install_chain_explorer_via_systemd"
    git clone https://github.com/oraclesorg/chain-explorer
    git clone https://github.com/ethereum/solc-bin chain-explorer/utils/solc-bin
    cd chain-explorer
    npm install
    sudo npm install pm2 -g
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
    sudo bash -c "cat > /etc/systemd/system/oracles-chain-explorer.service <<EOF
[Unit]
Description=oracles chain explorer service
After=oracles-pm2.service
[Service]
Type=oneshot
RemainAfterExit=true
User=${ADMIN_USERNAME}
Group=${ADMIN_USERNAME}
Environment=MYVAR=myval
WorkingDirectory=/home/${ADMIN_USERNAME}/chain-explorer
ExecStart=/usr/bin/pm2 startOrRestart app.json
[Install]
WantedBy=multi-user.target
EOF"
    sudo systemctl enable oracles-chain-explorer
    sudo systemctl start oracles-chain-explorer
    echo "<===== install_chain_explorer_via_systemd"
}

use_deb_via_systemd() {
    echo "=====> use_deb_via_systemd"
    curl -LO 'http://parity-downloads-mirror.parity.io/v1.7.0/x86_64-unknown-linux-gnu/parity_1.7.0_amd64.deb'
    sudo dpkg -i parity_1.7.0_amd64.deb

    #curl -LO 'http://d1h4xl4cr1h0mo.cloudfront.net/nightly/x86_64-unknown-debian-gnu/parity_1.8.0_amd64.deb'
    #sudo dpkg -i parity_1.8.0_amd64.deb

    sudo bash -c "cat > /etc/systemd/system/oracles-parity.service <<EOF
[Unit]
Description=oracles parity service
After=network.target
[Service]
User=${ADMIN_USERNAME}
Group=${ADMIN_USERNAME}
WorkingDirectory=/home/${ADMIN_USERNAME}
ExecStart=/usr/bin/parity --config=node.toml --ui-no-validation
Restart=always
[Install]
WantedBy=multi-user.target
EOF"
    sudo systemctl enable oracles-parity
    sudo systemctl start oracles-parity
    echo "<===== use_deb_via_systemd"
}

configure_logrotate() {
    echo "=====> configure_logrotate"

    sudo bash -c "cat > /etc/logrotate.d/oracles.conf << EOF
/home/${ADMIN_USERNAME}/logs/*.log {
    rotate 10
    size 200M
    missingok
    compress
    copytruncate
    dateext
    dateformat %Y-%m-%d-%s
    olddir old
}
/home/${ADMIN_USERNAME}/.pm2/pm2.log {
    su ${ADMIN_USERNAME} ${ADMIN_USERNAME}
    rotate 10
    size 200M
    missingok
    compress
    copytruncate
    dateext
    dateformat %Y-%m-%d-%s
}
EOF"
    echo "<===== configure_logrotate"
}

# MAIN
main () {
    sudo apt-get update

    prepare_homedir
    install_ntpd
    install_haveged
    allocate_swap

    install_nodejs
    pull_image_and_configs
    clone_dapps

    use_deb_via_systemd
    install_dashboard_via_systemd

    start_pm2_via_systemd
    install_netstats_via_systemd
    install_chain_explorer_via_systemd

    configure_logrotate
}

main
echo "========== dev-mainnet/netstats-server/install.sh finished =========="
