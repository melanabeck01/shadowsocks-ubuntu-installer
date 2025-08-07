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
kill_existing_processes() {
    log "Killing existing Shadowsocks processes"
    pkill -f "ss-server" 2>/dev/null || true
    pkill -f "shadowsocks" 2>/dev/null || true
    sleep 2
}
check_port_conflict() {
    local port=$1
    if ss -tuln | grep -q ":$port "; then
        log "Port $port is in use, finding alternative"
        for p in {8388..8398}; do
            if ! ss -tuln | grep -q ":$p "; then
                echo $p
                return
            fi
        done
        err "No available ports found"
    fi
    echo $port
}
get_ipv4() { 
    local ip
    for service in "ifconfig.me" "ipv4.icanhazip.com" "api.ipify.org" "checkip.amazonaws.com"; do
        ip=$(curl -s -4 --connect-timeout 5 "$service" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)
        [[ -n "$ip" ]] && echo "$ip" && return 0
    done
    echo "YOUR_SERVER_IP"
}

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

cleanup_services() {
    log "Cleaning up existing services"
    for service in shadowsocks-libev shadowsocks-server ss-server; do
        systemctl stop "$service" 2>/dev/null || true
        systemctl disable "$service" 2>/dev/null || true
    done
    systemctl daemon-reload
}
install_shadowsocks(){
local ubuntu_ver=$1
log "Installing shadowsocks-libev for Ubuntu $ubuntu_ver"
kill_existing_processes
cleanup_services
DEBIAN_FRONTEND=noninteractive apt update -qq
DEBIAN_FRONTEND=noninteractive apt install -y shadowsocks-libev || err "Failed to install shadowsocks-libev"
kill_existing_processes
}

create_config(){
local password=$1
local port=$2
log "Creating configuration with dual-stack support"
mkdir -p "$CONFIG_DIR"
cat>"$CONFIG_FILE"<<EOF
{
    "server":["::0","0.0.0.0"],
    "server_port":$port,
    "password":"$password",
    "timeout":300,
    "method":"aes-256-gcm",
    "mode":"tcp_and_udp",
    "fast_open":false
}
EOF
chmod 600 "$CONFIG_FILE"
}

validate_config() {
    log "Validating configuration"
    if ! /usr/bin/ss-server -c "$CONFIG_FILE" -t 2>&1 | grep -q "listening"; then
        log "Testing configuration with ss-server"
        timeout 5 /usr/bin/ss-server -c "$CONFIG_FILE" -v 2>&1 | head -10 || true
    fi
}
setup_service() {
    log "Setting up systemd service"
    kill_existing_processes
    cleanup_services
    
    # Create custom service file
    cat > /etc/systemd/system/shadowsocks-server.service << 'EOF'
[Unit]
Description=Shadowsocks Server
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=nobody
Group=nogroup
WorkingDirectory=/etc/shadowsocks-libev
ExecStart=/usr/bin/ss-server -c /etc/shadowsocks-libev/config.json -v
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
RestartSec=3
LimitNOFILE=65535
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF
    
    # Fix permissions
    chown -R nobody:nogroup "$CONFIG_DIR"
    chmod 755 "$CONFIG_DIR"
    chmod 600 "$CONFIG_FILE"
    
    validate_config
    
    systemctl daemon-reload
    systemctl enable shadowsocks-server || err "Failed to enable service"
    systemctl start shadowsocks-server || err "Failed to start service"
    sleep 5
    
    # Check service status
    if ! systemctl is-active --quiet shadowsocks-server; then
        log "Service failed to start, checking logs..."
        journalctl -u shadowsocks-server --no-pager -l -n 20
        err "Service not running"
    fi
    
    # Test connection
    local port=$(grep server_port "$CONFIG_FILE" | grep -o '[0-9]*')
    if ss -tuln | grep -q ":$port "; then
        log "Service successfully listening on port $port"
    else
        err "Service not listening on expected port $port"
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
local server_ip=$(get_ipv4)
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
port=$(check_port_conflict 8388)
log "Using port: $port"
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