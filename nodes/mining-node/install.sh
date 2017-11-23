#!/bin/bash
set -e
set -u
set -x

# this should be provided through env by azure template
TEMPLATES_BRANCH="${TEMPLATES_BRANCH}"
MAIN_REPO_FETCH="${MAIN_REPO_FETCH}"

echo "========== ${TEMPLATES_BRANCH}/mining-node/install.sh starting =========="
echo "===== current time: $(date)"
echo "===== username: $(whoami)"
echo "===== working directory: $(pwd)"
echo "===== operating system info:"
lsb_release -a
echo "===== memory usage info:"
free -m

EXT_IP="$(curl ifconfig.co)"
echo "===== external ip: ${EXT_IP}"

echo "===== downloading common.vars"
curl -sLO "https://raw.githubusercontent.com/${MAIN_REPO_FETCH}/deployment-azure/${TEMPLATES_BRANCH}/nodes/common.vars"
source common.vars

INSTALL_CONFIG_REPO="${REPO_BASE_PATH}/mining-node"
echo "===== INSTALL_CONFIG_REPO: ${INSTALL_CONFIG_REPO}"

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

export HOME="${HOME:-/home/${ADMIN_USERNAME}}"

echo "===== environmental variables:"
printenv

echo "===== downloading common.funcs"
curl -sLO "https://raw.githubusercontent.com/${MAIN_REPO_FETCH}/deployment-azure/${TEMPLATES_BRANCH}/nodes/common.funcs"
source common.funcs

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
[account]
password = ["${NODE_PWD}"]
unlock = ["${MINING_ADDRESS}"]
[mining]
force_sealing = true
engine_signer = "${MINING_ADDRESS}"
tx_gas_limit = "${TX_GAS_LIMIT}"
reseal_on_txs = "none"
EOF
    echo "${MINING_KEYPASS}" > "${NODE_PWD}"
    mkdir -p parity_data/keys/OraclesPoA
    echo ${MINING_KEYFILE} | base64 -d > parity_data/keys/OraclesPoA/mining.key.${MINING_ADDRESS}
    echo "<===== pull_image_and_configs"
}

install_scripts() {
    echo "=====> install_scripts"
    git clone -b ${SCRIPTS_BRANCH} --single-branch https://github.com/${MAIN_REPO_FETCH}/oracles-scripts
    ln -s ../${NODE_TOML} oracles-scripts/node.toml
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

    if [ "${PARITY_INSTALLATION_MODE}" = "BIN" ]; then
        use_bin_via_systemd
    elif [ "${PARITY_INSTALLATION_MODE}" = "DEB" ]; then
        use_deb_via_systemd
    else
        echo "===== invalid PARITY_INSTALLATION_MODE == ${PARITY_INSTALLATION_MODE}. Should be either BIN or DEB"
        exit 1
    fi

    start_pm2_via_systemd
    install_netstats_via_systemd
    install_scripts
    configure_logrotate
}

main
echo "========== ${TEMPLATES_BRANCH}/mining-node/install.sh finished =========="
