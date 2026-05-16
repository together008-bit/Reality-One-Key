#!/usr/bin/env bash

set -Eeuo pipefail

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

main() {
    require_root

    print_info "Stopping Xray service..."

    systemctl stop xray 2>/dev/null || true
    systemctl disable xray 2>/dev/null || true

    print_info "Removing Xray files..."

    rm -f /usr/local/bin/xray
    rm -rf /usr/local/etc/xray
    rm -f /etc/systemd/system/xray.service

    systemctl daemon-reload

    print_info "Xray has been removed successfully"
}

main
