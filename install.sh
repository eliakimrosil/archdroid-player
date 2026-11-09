#!/bin/bash
# ==============================================================================
# ArchDroid Player & Audio Subsystem Installer
# Supports standalone local installation or 1-line curl pipe:
#   curl -fsSL https://raw.githubusercontent.com/<user>/archdroid-player/main/install.sh | bash
# ==============================================================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}${BOLD}============================================================${NC}"
echo -e "${BLUE}${BOLD}         ARCHDROID AUDIO & YOUTUBE PLAYER INSTALLER         ${NC}"
echo -e "${BLUE}${BOLD}============================================================${NC}"
echo ""

# 1. Resolve source directory (whether piped from curl or run locally)
REPO_RAW_URL="https://raw.githubusercontent.com/eliakimrosil/archdroid-player/main"
TARGET_DIR="/usr/local/bin"
BIN_DIR=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
if [ -d "$SCRIPT_DIR/bin" ] && [ -f "$SCRIPT_DIR/bin/play-yt" ]; then
    BIN_DIR="$SCRIPT_DIR/bin"
    echo -e "${GREEN}✓ Found local repository source at: $SCRIPT_DIR${NC}"
else
    echo -e "${YELLOW}Piped installation detected. Fetching latest tools from GitHub...${NC}"
    TMP_DIR="$(mktemp -d /tmp/archdroid-player-install-XXXXXX)"
    trap 'rm -rf "$TMP_DIR"' EXIT
    mkdir -p "$TMP_DIR/bin"
    
    TOOLS=("play-yt" "archdroid-media-player" "archdroid-audio" "archdroid-volume" "archdroid-tts")
    for tool in "${TOOLS[@]}"; do
        echo -n "  Fetching $tool... "
        curl -fsSL "$REPO_RAW_URL/bin/$tool" -o "$TMP_DIR/bin/$tool" || {
            echo -e "${RED}FAILED${NC}"
            echo "Error downloading $tool from $REPO_RAW_URL/bin/$tool"
            exit 1
        }
        chmod +x "$TMP_DIR/bin/$tool"
        echo -e "${GREEN}OK${NC}"
    done
    BIN_DIR="$TMP_DIR/bin"
fi

# 2. Check & Install Dependencies
echo ""
echo -e "${BLUE}[1/4] Checking and installing dependencies...${NC}"
NEEDED_PKGS=()
command -v curl >/dev/null 2>&1 || NEEDED_PKGS+=("curl")
command -v yt-dlp >/dev/null 2>&1 || NEEDED_PKGS+=("yt-dlp")
command -v ffmpeg >/dev/null 2>&1 || NEEDED_PKGS+=("ffmpeg")
command -v pulseaudio >/dev/null 2>&1 || NEEDED_PKGS+=("pulseaudio")

if [ ${#NEEDED_PKGS[@]} -gt 0 ]; then
    echo "Installing missing dependencies: ${NEEDED_PKGS[*]}"
    if command -v pacman >/dev/null 2>&1; then
        pacman -Syu --noconfirm "${NEEDED_PKGS[@]}"
    else
        echo -e "${YELLOW}Warning: pacman not found. Please install manually: ${NEEDED_PKGS[*]}${NC}"
    fi
else
    echo -e "${GREEN}✓ All core dependencies (yt-dlp, ffmpeg, pulseaudio, curl) are installed.${NC}"
fi

# 3. Install Tools into /usr/local/bin and link to /usr/bin
echo ""
echo -e "${BLUE}[2/4] Installing CLI tools to $TARGET_DIR...${NC}"
mkdir -p "$TARGET_DIR" "/usr/bin"

TOOLS=("play-yt" "archdroid-media-player" "archdroid-audio" "archdroid-volume" "archdroid-tts")
for tool in "${TOOLS[@]}"; do
    cp -f "$BIN_DIR/$tool" "$TARGET_DIR/$tool"
    chmod +x "$TARGET_DIR/$tool"
    ln -sf "$TARGET_DIR/$tool" "/usr/bin/$tool"
    echo -e "  ${GREEN}✓${NC} Installed $tool -> $TARGET_DIR/$tool"
done

# 4. Configure MPV defaults if mpv is installed
echo ""
echo -e "${BLUE}[3/4] Configuring media player defaults...${NC}"
mkdir -p "/root/.config/mpv"
cat > "/root/.config/mpv/mpv.conf" << 'EOF'
vo=tct
ao=pulse,null
audio-fallback-to-null=yes
ytdl-format=bestvideo[height<=480]+bestaudio/best
msg-level=all=warn
EOF
echo -e "${GREEN}✓ Configured ~/.config/mpv/mpv.conf${NC}"

# 5. Verify ArchDroid Host Bridge & Initialize PulseAudio
echo ""
echo -e "${BLUE}[4/4] Verifying ArchDroid Host Bridge & Audio Sinks...${NC}"

API_STATUS=$(curl -s --connect-timeout 2 "http://127.0.0.1:48292/api/status" 2>/dev/null || true)
if echo "$API_STATUS" | grep -q '"status":"online"'; then
    echo -e "  ${GREEN}✓${NC} ArchDroid Host API (127.0.0.1:48292) is ONLINE"
else
    echo -e "  ${YELLOW}!${NC} ArchDroid Host API (127.0.0.1:48292) not detected (is ArchDroid running?)"
fi

if (exec 3<>/dev/tcp/127.0.0.1/48293) 2>/dev/null; then
    exec 3<&- 3>&-
    echo -e "  ${GREEN}✓${NC} Real-Time PCM AudioTrack (127.0.0.1:48293) is ONLINE"
else
    echo -e "  ${YELLOW}!${NC} Real-Time PCM AudioTrack (127.0.0.1:48293) not detected"
fi

# Set default volume to 70% if bridge is online
if command -v archdroid-volume >/dev/null 2>&1; then
    archdroid-volume music 70 >/dev/null 2>&1 || true
fi

# Initialize PulseAudio bridge
if command -v archdroid-audio >/dev/null 2>&1; then
    archdroid-audio setup-pulse >/dev/null 2>&1 || true
    echo -e "  ${GREEN}✓${NC} PulseAudio bridge configured"
fi

if command -v archdroid-toast >/dev/null 2>&1; then
    archdroid-toast "ArchDroid Player & Audio Suite Installed!" 2>/dev/null || true
fi

echo ""
echo -e "${GREEN}${BOLD}============================================================${NC}"
echo -e "${GREEN}${BOLD}                 INSTALLATION COMPLETE!                     ${NC}"
echo -e "${GREEN}${BOLD}============================================================${NC}"
echo ""
echo "Try running:"
echo "  play-yt \"calvin harris outside\"       # Stream music from YouTube"
echo "  archdroid-media-player status         # Check media player status"
echo "  archdroid-volume music 80             # Adjust Android media volume"
echo "  archdroid-tts \"Audio is ready!\"       # Test Android Text-To-Speech"
echo ""
