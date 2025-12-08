#!/bin/bash

# Quick script to restart just the backend service
# Useful when you only changed backend config

set -e

echo "🔄 Restarting backend service..."

cd "$(dirname "$0")/.." || exit

# Restart just the backend container
docker-compose restart backend

echo "✅ Backend restarted!"
echo ""
echo "To view logs: docker-compose logs -f backend"

