#!/bin/bash
set -e
set -u
set -x

EXT_IP="$(curl ifconfig.co)"

echo "========== dev-mainnet/mining-node/install.sh starting =========="
echo "===== current time: $(date)"
echo "===== username: $(whoami)"
echo "===== working directory: $(pwd)"
echo "===== operating system info:"
lsb_release -a
echo "===== memory usage info:"
free -m
echo "===== external ip: ${EXT_IP}"
echo "===== environmental variables:"
printenv

# script parameters
INSTALL_CONFIG_REPO="https://raw.githubusercontent.com/oraclesorg/test-templates/dev-mainnet/TestTestNet/mining-node"
GENESIS_REPO_LOC="https://raw.githubusercontent.com/oraclesorg/oracles-scripts/sokol/spec.json"
GENESIS_JSON="spec.json"
NODE_TOML="node.toml"
NODE_PWD="node.pwd"
BOOTNODES_TXT="https://raw.githubusercontent.com/oraclesorg/test-templates/dev-mainnet/TestTestNet/bootnodes.txt"
PARITY_DEB_LOC="https://parity-downloads-mirror.parity.io/v1.8.1/x86_64-unknown-linux-gnu/parity_1.8.1_amd64.deb"

export HOME="${HOME:-/home/${ADMIN_USERNAME}}"

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
#SSHPUBKEY="${SSHPUBKEY}"

prepare_homedir() {
    echo "=====> prepare_homedir"
    #ln -s "$(pwd)" "/home/${ADMIN_USERNAME}/script-dir"
    cd "/home/${ADMIN_USERNAME}"
    mkdir -p logs
    mkdir -p logs/old
    echo "<===== prepare_homedir"
}

set_ssh_keys() {
    echo "=====> set_ssh_keys"

    if [ -n "${SSHPUBKEY}" ]; then
        echo "=====> got ssh public key: ${SSHPUBKEY}"
        mkdir -p "/home/${ADMIN_USERNAME}/.ssh"
        chmod 700 "/home/${ADMIN_USERNAME}/.ssh"
        echo "${SSHPUBKEY}" >> "/home/${ADMIN_USERNAME}/.ssh/authorized_keys"
        chmod 600 "/home/${ADMIN_USERNAME}/.ssh/authorized_keys"
    fi

    echo "<===== set_ssh_keys"
}

setup_ufw() {
    echo "=====> setup_ufw"
    sudo sudo ufw enable
    sudo ufw default deny incoming
    sudo ufw allow 443
    sudo ufw allow 8545
    sudo ufw allow 22/tcp
    sudo ufw allow 30303/tcp
    sudo ufw allow 30303/udp
    echo "<===== setup_ufw"
}

increase_ulimit_n() {
     echo "=====> increase_ulimit_n"
     echo "${ADMIN_USERNAME} soft nofile 100000" | sudo tee /etc/security/limits.conf >> /dev/null
     echo "${ADMIN_USERNAME} hard nofile 100000" | sudo tee /etc/security/limits.conf >> /dev/null
     echo "<===== increase_ulimit_n"
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


pull_image_and_configs() {
    echo "=====> pull_image_and_configs"

    # curl -s -O "${INSTALL_CONFIG_REPO}/../${GENESIS_JSON}"
    curl -s -o "${GENESIS_JSON}" "${GENESIS_REPO_LOC}"
    curl -s -O "${INSTALL_CONFIG_REPO}/${NODE_TOML}"
    curl -s -o "bootnodes.txt" "${BOOTNODES_TXT}"
    sed -i "/\[network\]/a nat=\"extip:${EXT_IP}\"" ${NODE_TOML}
    #sed -i "/\[network\]/a bootnodes=\[$(cat bootnodes.txt | sed 's/\r$//' | awk -F'#' '{ print $1 }' | awk '/enode/{ print "\""$1"\"" }' | paste -sd "," -)\]" ${NODE_TOML}
    sed -i "/\[network\]/a reserved_peers=\"/home/${ADMIN_USERNAME}/bootnodes.txt\"" ${NODE_TOML}
    cat >> ${NODE_TOML} <<EOF
[misc]
log_file = "/home/${ADMIN_USERNAME}/logs/parity.log"
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

start_pm2_via_systemd() {
    echo "=====> start_pm2_via_systemd"
    sudo npm install pm2 -g
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
            "WS_SERVER"        : "http://${NETSTATS_SERVER}:3000",
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
After=network.target

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

use_deb_via_systemd() {
    echo "=====> use_deb_via_systemd"
    curl -LO "${PARITY_DEB_LOC}"
    sudo dpkg -i "$(basename ${PARITY_DEB_LOC})"

    sudo bash -c "cat > /etc/systemd/system/oracles-parity.service <<EOF
[Unit]
Description=oracles parity service
After=network.target

[Service]
User=${ADMIN_USERNAME}
Group=${ADMIN_USERNAME}
WorkingDirectory=/home/${ADMIN_USERNAME}
ExecStart=/usr/bin/parity --config=node.toml
Restart=always

[Install]
WantedBy=multi-user.target
EOF"
    sudo systemctl enable oracles-parity
    sudo systemctl start oracles-parity
    echo "<===== use_deb_via_systemd"
}

install_scripts() {
    echo "=====> install_scripts"
    git clone -b sokol --single-branch https://github.com/oraclesorg/oracles-scripts
    ln -s ../node.toml oracles-scripts/node.toml
    cd oracles-scripts/scripts
    npm install
    sudo bash -c "cat > /etc/cron.hourly/transferRewardToPayoutKey <<EOF
#!/bin/bash
cd "$(pwd)"
echo \"Starting at \\\$(date)\" >> \"/home/${ADMIN_USERNAME}/logs/transferRewardToPayoutKey.out\"
echo \"Starting at \\\$(date)\" >> \"/home/${ADMIN_USERNAME}/logs/transferRewardToPayoutKey.err\"
node transferRewardToPayoutKey.js >> \"/home/${ADMIN_USERNAME}/logs/transferRewardToPayoutKey.out\" 2>> \"/home/${ADMIN_USERNAME}/logs/transferRewardToPayoutKey.err\"
echo \"\" >> \"/home/${ADMIN_USERNAME}/logs/transferRewardToPayoutKey.out\"
echo \"\" >> \"/home/${ADMIN_USERNAME}/logs/transferRewardToPayoutKey.err\"
EOF"
    sudo chmod 755 /etc/cron.hourly/transferRewardToPayoutKey
    cd ../..
    echo "<===== install_scripts"
}

configure_logrotate() {
    echo "=====> configure_logrotate"

    sudo bash -c "cat > /home/${ADMIN_USERNAME}/oracles-logrotate.conf << EOF
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

    sudo bash -c "cat > /etc/cron.hourly/oracles-logrotate <<EOF
#!/bin/bash
/usr/sbin/logrotate /home/${ADMIN_USERNAME}/oracles-logrotate.conf
EOF"
    sudo chmod 755 /etc/cron.hourly/oracles-logrotate

    echo "<===== configure_logrotate"
}

# MAIN
main () {
    sudo apt-get update

    prepare_homedir
    #set_ssh_keys
    setup_ufw
    increase_ulimit_n
    install_ntpd
    install_haveged
    allocate_swap

    install_nodejs
    pull_image_and_configs

    use_deb_via_systemd

    start_pm2_via_systemd
    install_netstats_via_systemd
    install_scripts
    configure_logrotate
}

main
echo "========== dev-mainnet/mining-node/install.sh finished =========="
