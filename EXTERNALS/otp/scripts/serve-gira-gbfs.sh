#!/bin/bash
# Simple HTTP server to serve GIRA GBFS files
# OTP needs to fetch GBFS feeds via HTTP, not file://

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GBFS_DIR="$SCRIPT_DIR/../build/gira-gbfs"
PORT=${GIRA_GBFS_PORT:-8081}

if [ ! -d "$GBFS_DIR" ]; then
    echo "❌ GIRA GBFS directory not found: $GBFS_DIR"
    echo "   Run 'npm run gira-to-gbfs' first to generate the files"
    exit 1
fi

echo "🌐 Serving GIRA GBFS files from: $GBFS_DIR"
echo "   URL: http://localhost:$PORT"
echo "   Press Ctrl+C to stop"
echo ""

cd "$GBFS_DIR"

# Try Python 3 first, then Python 2, then Node.js http-server
# Bind to 0.0.0.0 to be accessible from Docker containers
if command -v python3 &> /dev/null; then
    python3 -m http.server "$PORT" --bind 0.0.0.0
elif command -v python &> /dev/null; then
    python -m SimpleHTTPServer "$PORT"
elif command -v npx &> /dev/null; then
    npx http-server -p "$PORT" -a 0.0.0.0 -c-1
else
    echo "❌ No HTTP server found. Please install Python 3 or Node.js"
    exit 1
fi

