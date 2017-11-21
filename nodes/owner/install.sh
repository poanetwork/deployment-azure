#!/bin/bash
set -e
set -u
set -x

# this should be provided through env by azure template
TEMPLATES_BRANCH="${TEMPLATES_BRANCH}"

echo "========== ${TEMPLATES_BRANCH}/owner/install.sh starting =========="
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
curl -sLO "https://raw.githubusercontent.com/oraclesorg/deployment-azure/${TEMPLATES_BRANCH}/nodes/common.vars"
source common.vars

INSTALL_CONFIG_REPO="${REPO_BASE_PATH}/owner"
echo "===== INSTALL_CONFIG_REPO: ${INSTALL_CONFIG_REPO}"

# this should be provided through env by azure template
NETSTATS_SERVER="${NETSTATS_SERVER}"
NETSTATS_SECRET="${NETSTATS_SECRET}"
OWNER_KEYFILE="${OWNER_KEYFILE}"
OWNER_KEYPASS="${OWNER_KEYPASS}"
NODE_FULLNAME="${NODE_FULLNAME:-Owner}"
NODE_ADMIN_EMAIL="${NODE_ADMIN_EMAIL:-somebody@somehere}"
ADMIN_USERNAME="${ADMIN_USERNAME}"

export HOME="${HOME:-/home/${ADMIN_USERNAME}}"

echo "===== environmental variables:"
printenv

echo "===== downloading common.funcs"
curl -sLO "https://raw.githubusercontent.com/oraclesorg/deployment-azure/${TEMPLATES_BRANCH}/nodes/common.funcs"
source common.funcs

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
unlock = ["${OWNER_ADDRESS}"]
[mining]
force_sealing = true
engine_signer = "${OWNER_ADDRESS}"
tx_gas_limit = "${TX_GAS_LIMIT}"
reseal_on_txs = "none"
EOF
    echo "${OWNER_KEYPASS}" > "${NODE_PWD}"
    mkdir -p parity_data/keys/OraclesPoA
    echo ${OWNER_KEYFILE} | base64 -d > parity_data/keys/OraclesPoA/owner.key

    echo "<===== pull_image_and_configs"
}

download_initial_keys_script() {
    echo "=====> download_initial_keys_script"
    git clone -b ${IKEYS_BRANCH} --single-branch https://github.com/oraclesorg/oracles-initial-keys
    cd oracles-initial-keys
    npm install
    cd ..
    echo "<===== download_initial_keys_script"
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
    install_netstats_via_systemd

    configure_logrotate

    download_initial_keys_script
}

main
echo "========== ${TEMPLATES_BRANCH}/owner/install.sh finished =========="
