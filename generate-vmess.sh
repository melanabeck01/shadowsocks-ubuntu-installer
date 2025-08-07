#!/bin/bash
# VMess Configuration Generator for V2Ray
# Generates base64 encoded VMess links

# Default values
DEFAULT_HOST="127.0.0.1"
DEFAULT_PORT="10086" 
DEFAULT_UUID=$(uuidgen)
DEFAULT_ALTID="0"
DEFAULT_LEVEL="0"
DEFAULT_SECURITY="auto"
DEFAULT_NETWORK="tcp"

# Get user input or use defaults
HOST=${1:-$DEFAULT_HOST}
PORT=${2:-$DEFAULT_PORT}
UUID=${3:-$DEFAULT_UUID}
ALTID=${4:-$DEFAULT_ALTID}
LEVEL=${5:-$DEFAULT_LEVEL}
SECURITY=${6:-$DEFAULT_SECURITY}
NETWORK=${7:-$DEFAULT_NETWORK}

# Generate VMess JSON config
VMESS_JSON="{
  \"v\": \"2\",
  \"ps\": \"VMess-${HOST}\",
  \"add\": \"${HOST}\",
  \"port\": \"${PORT}\",
  \"id\": \"${UUID}\",
  \"aid\": \"${ALTID}\",
  \"scy\": \"${SECURITY}\",
  \"net\": \"${NETWORK}\",
  \"type\": \"none\",
  \"host\": \"\",
  \"path\": \"\",
  \"tls\": \"\",
  \"sni\": \"\",
  \"alpn\": \"\"
}"

# Encode to base64
VMESS_LINK="vmess://$(echo -n "$VMESS_JSON" | base64 -w 0)"

echo "VMess Configuration Generated:"
echo "Host: $HOST"
echo "Port: $PORT" 
echo "UUID: $UUID"
echo "AlterId: $ALTID"
echo "Security: $SECURITY"
echo "Network: $NETWORK"
echo ""
echo "VMess Link:"
echo "$VMESS_LINK"
echo ""
echo "QR Code (install qrencode): qr \"$VMESS_LINK\""