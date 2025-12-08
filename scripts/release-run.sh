#!/bin/bash

# ===========================================
# One-Click Release Script for Linux/macOS
# Runs spin-up.sh and Flutter app
# ===========================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Parse arguments
MOCK_MODE=false
if [[ "$1" == "--mock" ]] || [[ "$1" == "-m" ]]; then
    MOCK_MODE=true
elif [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "Usage: ./release-run.sh [--mock]"
    echo ""
    echo "Options:"
    echo "  --mock, -m    Run Flutter app with mock location enabled"
    echo "  --help, -h    Show this help message"
    echo ""
    echo "Example:"
    echo "  ./release-run.sh          # Normal run"
    echo "  ./release-run.sh --mock   # Run with mock location"
    exit 0
fi

echo -e "${CYAN}========================================"
echo -e "  EcoMove - One-Click Release Runner"
echo -e "========================================${NC}"
echo ""

# Get project root (parent of scripts directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${GREEN}📁 Project root: ${PROJECT_ROOT}${NC}"
echo ""

# Check if Flutter is available
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}ERROR: Flutter is not installed or not in PATH.${NC}"
    echo -e "${YELLOW}Please install Flutter and add it to your PATH.${NC}"
    exit 1
fi

# Step 1: Run spin-up.sh
echo -e "${YELLOW}🚀 Step 1: Starting backend services...${NC}"
echo ""

cd "$PROJECT_ROOT"
bash "$SCRIPT_DIR/spin-up.sh"

if [ $? -ne 0 ]; then
    echo ""
    echo -e "${RED}ERROR: Spin-up script failed. Please check the errors above.${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Backend services started successfully!${NC}"
echo ""

# Step 2: Wait for services to be ready
echo -e "${YELLOW}⏳ Waiting 5 seconds for services to be ready...${NC}"
sleep 5

# Step 3: Run Flutter app
echo ""
echo -e "${YELLOW}📱 Step 2: Starting Flutter app...${NC}"
echo ""

cd "$PROJECT_ROOT/Frontend"

if [ ! -d "$PROJECT_ROOT/Frontend" ]; then
    echo -e "${RED}ERROR: Frontend directory not found.${NC}"
    exit 1
fi

if [ "$MOCK_MODE" = true ]; then
    echo -e "${MAGENTA}🎭 Running with MOCK LOCATION enabled${NC}"
    echo ""
    flutter run --dart-define=MOCK_LOCATION=true
else
    echo -e "${CYAN}📍 Running in NORMAL mode${NC}"
    echo ""
    flutter run
fi

