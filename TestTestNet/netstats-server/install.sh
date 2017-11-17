#!/bin/bash
set -e
set -u
set -x

TEMPLATES_BRANCH="dev-mainnet"

echo "========== ${TEMPLATES_BRANCH}/netstats-server/install.sh starting =========="
echo "===== current time: $(date)"
echo "===== username: $(whoami)"
echo "===== working directory: $(pwd)"
echo "===== operating system info:"
lsb_release -a
echo "===== memory usage info:"
free -m

EXT_IP="$(curl ifconfig.co)"
echo "===== external ip: ${EXT_IP}"

NETSTATS_SERVER="localhost"

INSTALL_CONFIG_REPO="https://raw.githubusercontent.com/oraclesorg/test-templates/${TEMPLATES_BRANCH}/TestTestNet/netstats-server"
echo "===== repo base path: ${INSTALL_CONFIG_REPO}"

echo "===== downloading common.vars"
curl -sLO "https://raw.githubusercontent.com/oraclesorg/test-templates/${TEMPLATES_BRANCH}/TestTestNet/common.vars"
source common.vars

# this should be provided through env by azure template
NETSTATS_SECRET="${NETSTATS_SECRET}"
NODE_FULLNAME="${NODE_FULLNAME:-NetStat}"
NODE_ADMIN_EMAIL="${NODE_ADMIN_EMAIL:-somebody@somehere}"
ADMIN_USERNAME="${ADMIN_USERNAME}"

export HOME="${HOME:-/home/${ADMIN_USERNAME}}"

echo "===== environmental variables:"
printenv

echo "===== downloading common.funcs"
curl -sLO "https://raw.githubusercontent.com/oraclesorg/test-templates/${TEMPLATES_BRANCH}/TestTestNet/common.funcs"
source common.funcs

setup_ufw() {
    echo "=====> setup_ufw"
    sudo sudo ufw enable
    sudo ufw default deny incoming
    sudo ufw allow 3000
    sudo ufw allow 4000
    sudo ufw allow 443
    sudo ufw allow 8545
    sudo ufw allow 22/tcp
    sudo ufw allow 30303/tcp
    sudo ufw allow 30303/udp
    echo "<===== setup_ufw"
}

pull_image_and_configs() {
    echo "=====> pull_image_and_configs"
    # curl -s -O "${INSTALL_CONFIG_REPO}/../${GENESIS_JSON}"
    curl -s -o "${GENESIS_JSON}" "${GENESIS_REPO_LOC}"
    curl -s -O "${INSTALL_CONFIG_REPO}/node.toml"
    curl -s -o "bootnodes.txt" "${BOOTNODES_TXT}"
    sed -i "/\[network\]/a nat=\"extip:${EXT_IP}\"" ${NODE_TOML}
    #sed -i "/\[network\]/a bootnodes=\[$(cat bootnodes.txt | sed 's/\r$//' | awk -F'#' '{ print $1 }' | awk '/enode/{ print "\""$1"\"" }' | paste -sd "," -)\]" ${NODE_TOML}
    sed -i "/\[network\]/a reserved_peers=\"/home/${ADMIN_USERNAME}/bootnodes.txt\"" ${NODE_TOML}
    cat >> ${NODE_TOML} <<EOF
[misc]
log_file = "/home/${ADMIN_USERNAME}/logs/parity.log"
EOF
    mkdir -p parity_data/keys/OraclesPoA

    echo "<===== pull_image_and_configs"
}

install_dashboard_via_systemd() {
    echo "=====> install_dashboard_via_systemd"
    git clone https://github.com/oraclesorg/eth-netstats
    cd eth-netstats
    npm install
    sudo npm install -g grunt-cli
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
    this.ipcPath = "/home/${ADMIN_USERNAME}/parity_data/jsonrpc.ipc";
    this.provider = new web3.providers.IpcProvider(this.ipcPath, net);
    this.bootstrapUrl = "https://maxcdn.bootstrapcdn.com/bootswatch/3.3.7/yeti/bootstrap.min.css";
    this.names = {
        "0xdd0bb0e2a1594240fed0c2f2c17c1e9ab4f87126": "Owner",
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

# MAIN
main () {
    sudo apt-get update

    prepare_homedir
    setup_ufw
    increase_ulimit_n
    install_ntpd
    install_haveged
    allocate_swap

    install_nodejs
    pull_image_and_configs

    if [ "${PARITY_INSTALLATION_MODE}" = "BIN" ]; then
        use_bin_via_systemd
    elif [ "${PARITY_INSTALLATION_MODE}" = "DEB" ]; then
        use_deb_via_systemd
    else
        echo "===== invalid PARITY_INSTALLATION_MODE == ${PARITY_INSTALLATION_MODE}. Should be either BIN or DEB"
        exit 1
    fi

    start_pm2_via_systemd

    install_dashboard_via_systemd
    install_netstats_via_systemd
    install_chain_explorer_via_systemd

    configure_logrotate
}

main
echo "========== ${TEMPLATES_BRANCH}/netstats-server/install.sh finished =========="
