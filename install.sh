#!/usr/bin/env bash

set -e

########################################
# Xray Private Installer
# Only for:
# - Debian / Ubuntu
# - VLESS + REALITY
# - Personal usage
########################################

XRAY_INSTALL_DIR="/usr/local/bin"
XRAY_CONFIG_DIR="/usr/local/etc/xray"
XRAY_CONFIG_FILE="${XRAY_CONFIG_DIR}/config.json"
XRAY_SERVICE_FILE="/etc/systemd/system/xray.service"

SUPPORTED_PORTS=(443 8443 2053 2083 2096)
DEFAULT_SNI="www.cloudflare.com"

########################################
# Colors
########################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

########################################
# Helpers
########################################

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

require_root() {
    if [[ "$EUID" -ne 0 ]]; then
        print_error "Please run as root"
        exit 1
    fi
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release

        case "$ID" in
            ubuntu|debian)
                OS="$ID"
                ;;
            *)
                print_error "Unsupported OS: $ID"
                exit 1
                ;;
        esac
    else
        print_error "Cannot detect OS"
        exit 1
    fi
}

install_dependencies() {
    print_info "Installing dependencies..."

    apt update

    apt install -y \
        curl \
        wget \
        unzip \
        openssl \
        jq \
        cron
}

enable_bbr() {
    print_info "Enabling BBR..."

    cat > /etc/sysctl.d/99-xray-bbr.conf <<EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

    sysctl --system >/dev/null 2>&1 || true
}

choose_port() {
    RANDOM_INDEX=$((RANDOM % ${#SUPPORTED_PORTS[@]}))
    DEFAULT_PORT="${SUPPORTED_PORTS[$RANDOM_INDEX]}"

    read -rp "Port [default: ${DEFAULT_PORT}]: " PORT

    PORT="${PORT:-$DEFAULT_PORT}"
}

choose_sni() {
    read -rp "Reality SNI [default: ${DEFAULT_SNI}]: " SNI

    SNI="${SNI:-$DEFAULT_SNI}"
}

generate_uuid() {
    UUID=$(cat /proc/sys/kernel/random/uuid)
}

install_xray() {
    print_info "Fetching latest Xray release..."

    LATEST_VERSION=$(curl -s \
        https://api.github.com/repos/XTLS/Xray-core/releases/latest \
        | jq -r .tag_name)

    if [[ -z "$LATEST_VERSION" ]]; then
        print_error "Failed to fetch latest version"
        exit 1
    fi

    ARCH=$(uname -m)

    case "$ARCH" in
        x86_64)
            XRAY_ARCH="64"
            ;;
        aarch64|arm64)
            XRAY_ARCH="arm64-v8a"
            ;;
        *)
            print_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac

    DOWNLOAD_URL="https://github.com/XTLS/Xray-core/releases/download/${LATEST_VERSION}/Xray-linux-${XRAY_ARCH}.zip"

    TMP_DIR=$(mktemp -d)

    print_info "Downloading Xray ${LATEST_VERSION}..."

    wget -qO "${TMP_DIR}/xray.zip" "$DOWNLOAD_URL"

    unzip -q "${TMP_DIR}/xray.zip" -d "$TMP_DIR"

    install -m 755 "${TMP_DIR}/xray" "${XRAY_INSTALL_DIR}/xray"

    mkdir -p "$XRAY_CONFIG_DIR"

    rm -rf "$TMP_DIR"
}

generate_reality_keys() {
    print_info "Generating Reality keys..."

    KEY_OUTPUT=$("${XRAY_INSTALL_DIR}/xray" x25519 2>&1)

    while IFS= read -r line; do
        case "$line" in
            *"Private key:"*)
                PRIVATE_KEY=$(echo "$line" | cut -d ':' -f2 | xargs)
                ;;
            *"Public key:"*)
                PUBLIC_KEY=$(echo "$line" | cut -d ':' -f2 | xargs)
                ;;
        esac
    done <<< "$KEY_OUTPUT"

    if [[ -z "$PRIVATE_KEY" || -z "$PUBLIC_KEY" ]]; then
        print_error "Failed to generate Reality keys"

        echo
        echo "Raw output:"
        echo "$KEY_OUTPUT"
        echo

        exit 1
    fi

    SHORT_ID=$(openssl rand -hex 8)
}

generate_config() {
    print_info "Generating config.json..."

    cat > "$XRAY_CONFIG_FILE" <<EOF
{
  "log": {
    "loglevel": "warning"
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
        "realitySettings": {
          "show": false,
          "dest": "${SNI}:443",
          "xver": 0,
          "serverNames": [
            "${SNI}"
          ],
          "privateKey": "${PRIVATE_KEY}",
          "shortIds": [
            "${SHORT_ID}"
          ]
        }
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
}

validate_config() {
    print_info "Validating config..."

    "${XRAY_INSTALL_DIR}/xray" run -test -config "$XRAY_CONFIG_FILE"
}

create_service() {
    print_info "Creating systemd service..."

    cat > "$XRAY_SERVICE_FILE" <<EOF
[Unit]
Description=Xray Service
After=network.target nss-lookup.target

[Service]
User=root
ExecStart=${XRAY_INSTALL_DIR}/xray run -config ${XRAY_CONFIG_FILE}
Restart=on-failure
RestartSec=5

LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable xray
    systemctl restart xray
}

get_server_ip() {
    SERVER_IP=$(curl -s https://api.ipify.org || true)

    if [[ -z "$SERVER_IP" ]]; then
        SERVER_IP="YOUR_SERVER_IP"
    fi
}

generate_vless_link() {
    VLESS_LINK="vless://${UUID}@${SERVER_IP}:${PORT}?type=tcp&security=reality&pbk=${PUBLIC_KEY}&fp=chrome&sni=${SNI}&sid=${SHORT_ID}&flow=xtls-rprx-vision#xray-reality"
}

show_result() {
    clear

    echo "========================================"
    echo " Xray Installation Complete"
    echo "========================================"
    echo
    echo "Server IP:"
    echo "${SERVER_IP}"
    echo
    echo "Port:"
    echo "${PORT}"
    echo
    echo "UUID:"
    echo "${UUID}"
    echo
    echo "Public Key:"
    echo "${PUBLIC_KEY}"
    echo
    echo "Short ID:"
    echo "${SHORT_ID}"
    echo
    echo "Reality SNI:"
    echo "${SNI}"
    echo
    echo "VLESS Link:"
    echo
    echo "${VLESS_LINK}"
    echo
    echo "Config File:"
    echo "${XRAY_CONFIG_FILE}"
    echo
    echo "Systemd:"
    echo "systemctl status xray"
    echo
    echo "========================================"
}

main() {
    require_root
    detect_os
    install_dependencies
    enable_bbr

    choose_port
    choose_sni

    generate_uuid

    install_xray
    generate_reality_keys
    generate_config
    validate_config
    create_service

    get_server_ip
    generate_vless_link
    show_result
}

main
