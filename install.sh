#!/bin/bash

# ==================================================
# Xray Manager
# Lightweight Performance Reality Version
# ==================================================

# ==================================================
# Global Variables
# ==================================================

XRAY_DIR="/usr/local/etc/xray"
XRAY_CONFIG="${XRAY_DIR}/config.json"

XRAY_BIN="/usr/local/bin/xray"

XRAY_SERVICE="/etc/systemd/system/xray.service"

VLESS_LINK_FILE="/root/vless-link.txt"

XRAY_VERSION=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ==================================================
# Reality Domains
# ==================================================

REALITY_DESTS=(
    "www.cloudflare.com"
    "www.microsoft.com"
    "www.apple.com"
    "www.amazon.com"
)

# ==================================================
# Print Functions
# ==================================================

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ==================================================
# System Check
# ==================================================

check_root() {

    if [[ $EUID -ne 0 ]]; then
        print_error "Please run as root"
        exit 1
    fi

}

check_system() {

    if ! command -v apt >/dev/null 2>&1; then
        print_error "Only Debian/Ubuntu supported"
        exit 1
    fi

}

# ==================================================
# Enable BBR
# ==================================================

enable_bbr() {

    print_info "Enabling BBR..."

    cat > /etc/sysctl.d/99-xray-performance.conf <<EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

net.ipv4.tcp_fastopen=3
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_slow_start_after_idle=0

net.core.somaxconn=4096
net.ipv4.ip_local_port_range=1024 65535
EOF

    sysctl --system >/dev/null 2>&1

    print_info "BBR enabled"

}

# ==================================================
# Port Check
# ==================================================

check_port() {

    PORT=$1

    if ss -lnt | grep -q ":${PORT} "; then
        print_error "Port ${PORT} is already in use"
        exit 1
    fi

}

# ==================================================
# Install Dependencies
# ==================================================

install_dependencies() {

    print_info "Installing dependencies..."

    apt update -y

    apt install -y \
        curl \
        unzip \
        openssl

}

# ==================================================
# Install Xray Core
# ==================================================

install_xray_core() {

    print_info "Installing Xray core..."

    mkdir -p /tmp/xray-install

    cd /tmp/xray-install || exit

    XRAY_VERSION=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep tag_name | cut -d '"' -f4)

    curl -L -o xray.zip \
    "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-64.zip"

    unzip -o xray.zip

    install -m 755 xray ${XRAY_BIN}

    mkdir -p ${XRAY_DIR}

    chmod +x ${XRAY_BIN}

    cd ~ || exit

    rm -rf /tmp/xray-install

    print_info "Xray installed"

}

# ==================================================
# Generate Xray Config
# ==================================================

generate_xray_config() {

    print_info "Generating Xray config..."

    read -p "Enter port [443]: " PORT

    PORT=${PORT:-443}

    check_port ${PORT}

    DEST=${REALITY_DESTS[$RANDOM % ${#REALITY_DESTS[@]}]}

    print_info "Reality domain: ${DEST}"

    UUID=$(cat /proc/sys/kernel/random/uuid)

    KEY_OUTPUT=$(${XRAY_BIN} x25519)

    PRIVATE_KEY=$(echo "${KEY_OUTPUT}" | sed -n '1p' | cut -d ':' -f2 | tr -d ' ')
    PUBLIC_KEY=$(echo "${KEY_OUTPUT}" | sed -n '2p' | cut -d ':' -f2 | tr -d ' ')

    if [[ -z "${PRIVATE_KEY}" || -z "${PUBLIC_KEY}" ]]; then

        print_error "Failed to generate Reality keys"

        exit 1

    fi

    SHORT_ID=$(openssl rand -hex 8)

    cat > ${XRAY_CONFIG} <<EOF
{
  "log": {
    "loglevel": "warning"
  },

  "policy": {
    "levels": {
      "0": {
        "handshake": 4,
        "connIdle": 300,
        "uplinkOnly": 2,
        "downlinkOnly": 5,
        "bufferSize": 64
      }
    }
  },

  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": ${PORT},
      "protocol": "vless",

      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },

      "streamSettings": {
        "network": "tcp",
        "security": "reality",

        "sockopt": {
          "tcpFastOpen": true,
          "tcpNoDelay": true,
          "tcpKeepAliveInterval": 15
        },

        "realitySettings": {
          "show": false,
          "dest": "${DEST}:443",
          "xver": 0,

          "serverNames": [
            "${DEST}"
          ],

          "privateKey": "${PRIVATE_KEY}",

          "shortIds": [
            "${SHORT_ID}"
          ]
        }
      },

      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ]
      }
    }
  ],

  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ]
}
EOF

    SERVER_IP=$(curl -4 -s ipv4.ip.sb)

    VLESS_LINK="vless://${UUID}@${SERVER_IP}:${PORT}?type=tcp&security=reality&pbk=${PUBLIC_KEY}&fp=chrome&sni=${DEST}&sid=${SHORT_ID}&flow=xtls-rprx-vision#Xray-Reality"

    echo "${VLESS_LINK}" > ${VLESS_LINK_FILE}

    print_info "Config generated"

}

# ==================================================
# Create Service
# ==================================================

create_service() {

    print_info "Creating systemd service..."

    cat > ${XRAY_SERVICE} <<EOF
[Unit]
Description=Xray Service
After=network.target nss-lookup.target

[Service]
User=root

ExecStart=${XRAY_BIN} run -config ${XRAY_CONFIG}

Restart=on-failure
RestartSec=3

LimitNOFILE=1048576

AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload

    systemctl enable xray

}

# ==================================================
# Start Xray
# ==================================================

start_xray() {

    print_info "Starting Xray..."

    systemctl restart xray

    sleep 2

    if systemctl is-active --quiet xray; then

        print_info "Xray started successfully"

    else

        print_error "Xray failed to start"

        echo

        ${XRAY_BIN} run -config ${XRAY_CONFIG}

        exit 1

    fi

}

# ==================================================
# Update Xray Core
# ==================================================

update_xray() {

    echo
    echo "================================"
    echo "Update Xray Core"
    echo "================================"
    echo

    if [[ ! -f ${XRAY_BIN} ]]; then

        print_error "Xray is not installed"

        return

    fi

    CURRENT_VERSION=$(${XRAY_BIN} version | head -n 1)

    print_info "Current Version:"
    echo "${CURRENT_VERSION}"

    echo

    LATEST_VERSION=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep tag_name | cut -d '"' -f4)

    print_info "Latest Version: ${LATEST_VERSION}"

    echo

    mkdir -p /tmp/xray-update

    cd /tmp/xray-update || exit

    curl -L -o xray.zip \
    "https://github.com/XTLS/Xray-core/releases/download/${LATEST_VERSION}/Xray-linux-64.zip"

    unzip -o xray.zip

    systemctl stop xray

    install -m 755 xray ${XRAY_BIN}

    chmod +x ${XRAY_BIN}

    systemctl restart xray

    cd ~ || exit

    rm -rf /tmp/xray-update

    print_info "Xray updated successfully"

}

# ==================================================
# Show VLESS Link
# ==================================================

show_vless_link() {

    echo
    echo "================================"
    echo "VLESS Link"
    echo "================================"
    echo

    if [[ -f ${VLESS_LINK_FILE} ]]; then

        cat ${VLESS_LINK_FILE}

    else

        print_error "Link file not found"

    fi

}

# ==================================================
# Show Config
# ==================================================

show_config() {

    echo
    echo "================================"
    echo "Xray Config"
    echo "================================"
    echo

    if [[ -f ${XRAY_CONFIG} ]]; then

        cat ${XRAY_CONFIG}

    else

        print_error "Config not found"

    fi

}

# ==================================================
# Install Xray
# ==================================================

install_xray() {

    install_dependencies

    enable_bbr

    install_xray_core

    generate_xray_config

    create_service

    start_xray

    show_vless_link

}

# ==================================================
# Restart Xray
# ==================================================

restart_xray() {

    print_info "Restarting Xray..."

    systemctl restart xray

    sleep 2

    systemctl status xray --no-pager

}

# ==================================================
# Uninstall Xray
# ==================================================

uninstall_xray() {

    echo
    echo "================================"
    echo "Uninstall Xray"
    echo "================================"
    echo

    read -p "Are you sure? [y/N]: " CONFIRM

    case "${CONFIRM}" in
        y|Y|yes|YES)
            ;;
        *)
            print_info "Cancelled"
            return
            ;;
    esac

    systemctl stop xray 2>/dev/null
    systemctl disable xray 2>/dev/null

    rm -f ${XRAY_SERVICE}

    systemctl daemon-reload

    rm -f ${XRAY_BIN}

    rm -rf ${XRAY_DIR}

    rm -f ${VLESS_LINK_FILE}

    rm -rf /tmp/xray-install
    rm -rf /tmp/xray-update

    rm -f /etc/sysctl.d/99-xray-performance.conf

    sysctl --system >/dev/null 2>&1

    print_info "Xray completely removed"

}

# ==================================================
# Main Menu
# ==================================================

main_menu() {

    echo
    echo "================================"
    echo "         Xray Manager"
    echo "================================"
    echo "1. Install Xray"
    echo "2. Update Xray Core"
    echo "3. Restart Xray"
    echo "4. Show Config"
    echo "5. Show VLESS Link"
    echo "6. Uninstall Xray"
    echo "0. Exit"
    echo "================================"

    echo

    read -p "Choose: " CHOICE

    case $CHOICE in

        1)
            install_xray
            ;;

        2)
            update_xray
            ;;

        3)
            restart_xray
            ;;

        4)
            show_config
            ;;

        5)
            show_vless_link
            ;;

        6)
            uninstall_xray
            ;;

        0)
            exit 0
            ;;

        *)
            print_error "Invalid option"
            ;;

    esac

}

# ==================================================
# Main
# ==================================================

check_root

check_system

while true; do

    main_menu

    echo
    echo "--------------------------------"

    read -p "Press Enter to continue..."

    echo

done
