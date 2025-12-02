#!/bin/bash

# Auto-detect Windows host IP from WSL
# This script automatically finds your Windows IP and runs Flutter with the correct backend URL

# Method 1: Get IP from default gateway (most reliable)
WINDOWS_IP=$(ip route show | grep -i default | awk '{ print $3}' | head -n 1)

# Method 2: Fallback to nameserver if gateway method fails
if [ -z "$WINDOWS_IP" ] || [ "$WINDOWS_IP" == "" ]; then
    WINDOWS_IP=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}' | head -n 1)
fi

# If still no IP found, try host.docker.internal (if available)
if [ -z "$WINDOWS_IP" ] || [ "$WINDOWS_IP" == "" ]; then
    WINDOWS_IP=$(getent hosts host.docker.internal | awk '{ print $1 }' | head -n 1)
fi

# If all methods fail, use a default or prompt user
if [ -z "$WINDOWS_IP" ] || [ "$WINDOWS_IP" == "" ]; then
    echo "⚠️  Could not auto-detect Windows IP. Please set it manually:"
    echo "   flutter run --dart-define=ROUTES_BASE_URL=http://YOUR_IP:3000 --dart-define=BASE_URL=http://YOUR_IP:3000"
    exit 1
fi

echo "🔍 Detected Windows IP: $WINDOWS_IP"
echo "🚀 Running Flutter with backend URL: http://$WINDOWS_IP:3000"
echo ""

# Run Flutter with the detected IP
flutter run \
    --dart-define=ROUTES_BASE_URL=http://$WINDOWS_IP:3000 \
    --dart-define=BASE_URL=http://$WINDOWS_IP:3000 \
    "$@"

