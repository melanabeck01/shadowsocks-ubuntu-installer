#!/bin/bash
# Shadowsocks Installation Verification Script

echo "🔍 Verifying Shadowsocks installation..."

# Check service status
if systemctl is-active --quiet shadowsocks-server; then
    echo "✅ Service is running"
    port=$(grep server_port /etc/shadowsocks-libev/config.json | cut -d: -f2 | tr -d ' ",')
    echo "📡 Listening on port: $port"
else
    echo "❌ Service is not running"
    exit 1
fi

# Check firewall rules
if ufw status | grep -q "$port"; then
    echo "✅ Firewall configured"
else
    echo "⚠️  Firewall may need configuration"
fi

# Check config file
if [[ -f "/etc/shadowsocks-libev/config.json" ]]; then
    echo "✅ Configuration file exists"
    echo "🔐 Method: $(grep method /etc/shadowsocks-libev/config.json | cut -d: -f2 | tr -d ' ",')"
else
    echo "❌ Configuration file missing"
    exit 1
fi

# Check backup tools
if [[ -x "/opt/shadowsocks-backup/backup.sh" ]]; then
    echo "✅ Backup tools available"
else
    echo "⚠️  Backup tools missing"
fi

echo "✨ Verification complete!"