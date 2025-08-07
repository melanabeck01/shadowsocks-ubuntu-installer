# Shadowsocks Server Installer

A comprehensive, production-ready installer script for Shadowsocks server on Ubuntu 22.04/24.04 LTS.

## Features

- ✅ **Automated Installation** - One-command setup
- ✅ **Secure Defaults** - AES-256-GCM encryption, random passwords & ports
- ✅ **Systemd Integration** - Proper service management with auto-restart
- ✅ **Firewall Configuration** - UFW rules for secure access
- ✅ **Backup & Restore** - Built-in backup/restore functionality
- ✅ **Error Handling** - Comprehensive logging and error recovery
- ✅ **Ubuntu Support** - Tested on Ubuntu 22.04 & 24.04 LTS

## Quick Install

```bash
wget -O shadowsocks-installer.sh https://raw.githubusercontent.com/YOUR_REPO/main/shadowsocks-installer.sh
chmod +x shadowsocks-installer.sh
sudo ./shadowsocks-installer.sh
```

## Requirements

- Ubuntu 22.04 LTS or Ubuntu 24.04 LTS
- Root or sudo access
- Internet connection

## What It Does

1. **System Detection** - Verifies Ubuntu version compatibility
2. **Package Installation** - Installs shadowsocks-libev and dependencies
3. **Secure Configuration** - Generates random password and port (10000-65535)
4. **Service Setup** - Creates optimized systemd service with security hardening
5. **Firewall Rules** - Configures UFW to allow shadowsocks traffic
6. **Backup Tools** - Creates backup and restore scripts

## Configuration

After installation, you'll receive:
- Server IP address
- Random secure port (10000-65535)
- 25-character random password
- AES-256-GCM encryption method

## Service Management

```bash
# Check service status
sudo systemctl status shadowsocks-server

# View logs
sudo journalctl -u shadowsocks-server -f

# Restart service
sudo systemctl restart shadowsocks-server

# Stop/start service
sudo systemctl stop shadowsocks-server
sudo systemctl start shadowsocks-server
```

## Backup & Restore

```bash
# Create backup
sudo /opt/shadowsocks-backup/backup.sh

# Restore from backup
sudo /opt/shadowsocks-backup/restore.sh /path/to/backup.tar.gz
```

## Configuration Files

- **Config**: `/etc/shadowsocks-libev/config.json`
- **Service**: `/etc/systemd/system/shadowsocks-server.service`
- **Logs**: `journalctl -u shadowsocks-server`
- **Backups**: `/opt/shadowsocks-backup/`

## Security Features

- Non-root service execution (nobody:nogroup)
- Secure systemd service with restricted permissions
- Random port allocation to avoid common scans
- Strong 25-character passwords
- AES-256-GCM encryption (AEAD cipher)
- UFW firewall integration

## Client Configuration

Use these settings in your Shadowsocks client:

```json
{
  "server": "YOUR_SERVER_IP",
  "server_port": YOUR_PORT,
  "password": "YOUR_PASSWORD",
  "method": "aes-256-gcm",
  "timeout": 300
}
```

## Troubleshooting

### Service Won't Start
```bash
sudo journalctl -u shadowsocks-server -n 50
```

### Port Already in Use
Edit `/etc/shadowsocks-libev/config.json` and change `server_port`, then restart:
```bash
sudo systemctl restart shadowsocks-server
```

### Firewall Issues
Check UFW status:
```bash
sudo ufw status
```

## Advanced Usage

### Custom Configuration
Edit `/etc/shadowsocks-libev/config.json`:
```json
{
    "server": "0.0.0.0",
    "server_port": 8388,
    "password": "your-password",
    "timeout": 300,
    "method": "aes-256-gcm",
    "fast_open": false,
    "workers": 1
}
```

### Performance Tuning
For high-traffic servers, consider:
- Increasing `workers` in config
- Using `fast_open: true` (if supported by clients)
- Adjusting kernel network parameters

## License

MIT License - Feel free to use and modify.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on Ubuntu 22.04/24.04
5. Submit a pull request

## Support

- Create an issue for bugs or feature requests
- Check logs with `journalctl -u shadowsocks-server`
- Verify configuration in `/etc/shadowsocks-libev/config.json`