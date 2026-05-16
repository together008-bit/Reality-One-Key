#!/usr/bin/env bash

set -Eeuo pipefail

XRAY_INSTALL_DIR="/usr/local/bin"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
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

download_latest_xray() {
    print_info "Fetching latest Xray release..."

    LATEST_VERSION=$(curl -s \
        https://api.github.com/repos/XTLS/Xray-core/releases/latest \
        | jq -r .tag_name)

    if [[ -z "${LATEST_VERSION}" ]]; then
        print_error "Failed to fetch latest version"
        exit 1
    fi

    ARCH=$(uname -m)

    case "${ARCH}" in
        x86_64)
            XRAY_ARCH="64"
            ;;
        aarch64|arm64)
            XRAY_ARCH="arm64-v8a"
            ;;
        *)
            print_error "Unsupported architecture: ${ARCH}"
            exit 1
            ;;
    esac

    DOWNLOAD_URL="https://github.com/XTLS/Xray-core/releases/download/${LATEST_VERSION}/Xray-linux-${XRAY_ARCH}.zip"

    TMP_DIR=$(mktemp -d)

    print_info "Downloading Xray ${LATEST_VERSION}..."

    wget -qO "${TMP_DIR}/xray.zip" "${DOWNLOAD_URL}"

    unzip -q "${TMP_DIR}/xray.zip" -d "${TMP_DIR}"

    if [[ -f "${XRAY_INSTALL_DIR}/xray" ]]; then
        cp "${XRAY_INSTALL_DIR}/xray" "${XRAY_INSTALL_DIR}/xray.bak"
    fi

    install -m 755 "${TMP_DIR}/xray" "${XRAY_INSTALL_DIR}/xray"

    rm -rf "${TMP_DIR}"
}

restart_xray() {
    print_info "Restarting Xray..."

    systemctl restart xray

    sleep 2

    if systemctl is-active --quiet xray; then
        print_info "Xray upgraded successfully"

        "${XRAY_INSTALL_DIR}/xray" version
    else
        print_error "Xray failed to start"

        if [[ -f "${XRAY_INSTALL_DIR}/xray.bak" ]]; then
            print_info "Rolling back..."

            mv "${XRAY_INSTALL_DIR}/xray.bak" "${XRAY_INSTALL_DIR}/xray"

            systemctl restart xray
        fi

        exit 1
    fi
}

main() {
    require_root

    download_latest_xray

    restart_xray
}

main
