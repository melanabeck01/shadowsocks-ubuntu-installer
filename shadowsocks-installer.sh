#!/bin/bash
# Shadowsocks Server Installer for Ubuntu 22/24 LTS
# Automated installation with secure defaults
# Author: Claude Code
# License: MIT

set -euo pipefail
LOG="/var/log/shadowsocks-installer.log"
CONFIG_DIR="/etc/shadowsocks-libev"
CONFIG_FILE="$CONFIG_DIR/config.json"
SERVICE_NAME="shadowsocks-server"
BACKUP_DIR="/opt/shadowsocks-backup"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }
err() { log "ERROR: $*"; exit 1; }
chk() { command -v "$1" >/dev/null || err "$1 not found"; }
genpass() { openssl rand -base64 32 | tr -d "=+/" | cut -c1-25; }
genport() { shuf -i 10000-65535 -n1; }

detect_ubuntu() {
    local ver=$(lsb_release -rs 2>/dev/null || echo "")
    case "$ver" in
        22.04) echo "22" ;;
        24.04) echo "24" ;;
        *) err "Unsupported Ubuntu version: $ver. Requires 22.04 or 24.04 LTS" ;;
    esac
}

install_deps(){
log "Installing dependencies"
DEBIAN_FRONTEND=noninteractive apt update -qq || err "Failed to update packages"
DEBIAN_FRONTEND=noninteractive apt install -y curl wget gnupg lsb-release ufw openssl pwgen || err "Failed to install dependencies"
}

install_shadowsocks(){
local ubuntu_ver=$1
log "Installing shadowsocks-libev for Ubuntu $ubuntu_ver"
DEBIAN_FRONTEND=noninteractive apt update -qq
DEBIAN_FRONTEND=noninteractive apt install -y shadowsocks-libev || err "Failed to install shadowsocks-libev"
systemctl stop shadowsocks-libev 2>/dev/null||true
}

create_config(){
local password=$1
local port=$2
log "Creating configuration"
mkdir -p "$CONFIG_DIR"
cat>"$CONFIG_FILE"<<EOF
{
    "server":"0.0.0.0",
    "server_port":$port,
    "password":"$password",
    "timeout":300,
    "method":"aes-256-gcm",
    "fast_open":false,
    "workers":1
}
EOF
chmod 600 "$CONFIG_FILE"
}

setup_service() {
    log "Setting up systemd service"
    
    # Create custom service file
    cat > /etc/systemd/system/shadowsocks-server.service << 'EOF'
[Unit]
Description=Shadowsocks Server
After=network.target

[Service]
Type=simple
User=nobody
Group=nogroup
WorkingDirectory=/etc/shadowsocks-libev
ExecStart=/usr/bin/ss-server -c /etc/shadowsocks-libev/config.json
Restart=always
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
    
    # Fix permissions
    chown -R nobody:nogroup "$CONFIG_DIR"
    chmod 755 "$CONFIG_DIR"
    chmod 644 "$CONFIG_FILE"
    
    # Disable default service and use our custom one
    systemctl disable shadowsocks-libev 2>/dev/null || true
    systemctl stop shadowsocks-libev 2>/dev/null || true
    
    systemctl daemon-reload
    systemctl enable shadowsocks-server || err "Failed to enable service"
    systemctl start shadowsocks-server || err "Failed to start service"
    sleep 3
    
    # Check service status
    if ! systemctl is-active --quiet shadowsocks-server; then
        log "Service failed to start, checking logs..."
        journalctl -u shadowsocks-server --no-pager -l
        err "Service not running"
    fi
}

setup_firewall(){
local port=$1
log "Configuring firewall"
ufw --force enable
ufw allow "$port"/tcp
ufw allow "$port"/udp
ufw allow ssh
ufw reload
}

create_backup(){
log "Creating backup functionality"
mkdir -p "$BACKUP_DIR"
cat>"$BACKUP_DIR/backup.sh"<<'EOF'
#!/bin/bash
BACKUP_FILE="$BACKUP_DIR/shadowsocks-$(date +%Y%m%d-%H%M%S).tar.gz"
tar -czf "$BACKUP_FILE" /etc/shadowsocks-libev/ /etc/systemd/system/shadowsocks-server.service 2>/dev/null
echo "Backup created: $BACKUP_FILE"
EOF
chmod +x "$BACKUP_DIR/backup.sh"
}

create_restore(){
cat>"$BACKUP_DIR/restore.sh"<<'EOF'
#!/bin/bash
if [ $# -ne 1 ]; then
    echo "Usage: $0 <backup-file>"
    exit 1
fi
tar -xzf "$1" -C / 2>/dev/null
systemctl daemon-reload
systemctl restart shadowsocks-server
echo "Restore completed"
EOF
chmod +x "$BACKUP_DIR/restore.sh"
}

show_info(){
local password=$1
local port=$2
local server_ip=$(curl -s ifconfig.me||curl -s ipinfo.io/ip||echo "YOUR_SERVER_IP")
log "Installation completed successfully!"
echo "
┌─────────────────────────────────────────────┐
│            Shadowsocks Server Info          │
├─────────────────────────────────────────────┤
│ Server: $server_ip                 │
│ Port: $port                              │
│ Password: $password    │
│ Method: aes-256-gcm                         │
│ Config: $CONFIG_FILE         │
├─────────────────────────────────────────────┤
│ Service: systemctl status shadowsocks-server │
│ Logs: journalctl -u shadowsocks-server      │
│ Backup: $BACKUP_DIR/backup.sh        │
│ Restore: $BACKUP_DIR/restore.sh      │
└─────────────────────────────────────────────┘
"
}

main(){
[[ $EUID -eq 0 ]]||err "Must run as root"
log "Starting Shadowsocks installation"
ubuntu_ver=$(detect_ubuntu)
password=$(genpass)
port=$(genport)
install_deps
install_shadowsocks "$ubuntu_ver"
create_config "$password" "$port"
setup_service
setup_firewall "$port"
create_backup
create_restore
show_info "$password" "$port"
log "Installation completed successfully"
}

if [[ "${BASH_SOURCE[0]:-$0}" == "${0}" ]]; then
main "$@"
fi