#!/bin/bash
# ==============================================================================
# ArchDroid Player & Audio Subsystem Uninstaller
# ==============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${RED}${BOLD}Uninstalling ArchDroid Player & Audio Subsystem...${NC}"

# Stop any active media playback
if command -v archdroid-media-player >/dev/null 2>&1; then
    archdroid-media-player stop >/dev/null 2>&1 || true
fi

TOOLS=("play-yt" "archdroid-media-player" "archdroid-audio" "archdroid-volume" "archdroid-tts")
for tool in "${TOOLS[@]}"; do
    rm -f "/usr/local/bin/$tool" "/usr/bin/$tool"
    echo -e "  ${GREEN}✓${NC} Removed $tool"
done

echo ""
echo -e "${GREEN}Uninstallation complete.${NC}"
