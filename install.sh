#!/usr/bin/env bash

# Color tokens for clean terminal reporting
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}============ YouTube Rofi-MPV Auto-Setup Engine ============${NC}"

# 1. Verify and Install Official Core Dependencies via Pacman
echo -e "\n${YELLOW}[1/4] Syncing System Repo Architectures & Dependencies...${NC}"
DEPENDENCIES=(
  "mpv"
  "rofi"
  "yt-dlp"
  "ytfzf"
  "fzf"
  "jq"
  "socat"
  "wl-clipboard"
  "libnotify"
  "neovim"
)

for pkg in "${DEPENDENCIES[@]}"; do
  if pacman -Qi "$pkg" &>/dev/null; then
    echo -e "  [${GREEN}✓${NC}] $pkg is active."
  else
    echo -e "  [${YELLOW}!${NC}] Installing missing dependency: $pkg"
    sudo pacman -S --noconfirm --needed "$pkg"
  fi
done

# 2. Build Configuration Tree Frameworks
echo -e "\n${YELLOW}[2/4] Structuring Target Config Footprints...${NC}"
HYPR_SCRIPT_DIR="$HOME/.config/hypr/UserScripts"
MPV_CONF_DIR="$HOME/.config/mpv/script-opts"
YTFZF_CONF_DIR="$HOME/.config/ytfzf"
CACHE_VAULT_DIR="$HOME/.cache/ytfzf/manual_playlists"

mkdir -p "$HYPR_SCRIPT_DIR" "$MPV_CONF_DIR" "$YTFZF_CONF_DIR" "$CACHE_VAULT_DIR"
echo -e "  [${GREEN}✓${NC}] Target directories initialized cleanly."

# 3. Deploy Main Executive Script
echo -e "\n${YELLOW}[3/4] Deploying Master Launcher Client...${NC}"
if [ -f "./RofiYoutube.sh" ]; then
  cp "./RofiYoutube.sh" "$HYPR_SCRIPT_DIR/RofiYoutube.sh"
  chmod +x "$HYPR_SCRIPT_DIR/RofiYoutube.sh"
  echo -e "  [${GREEN}✓${NC}] Script activated at: $HYPR_SCRIPT_DIR/RofiYoutube.sh"
else
  echo -e "  [${RED}✗${NC}] Failure: 'RofiYoutube.sh' not found in current directory."
  exit 1
fi

# 4. Synchronize Dotfile Configurations
echo -e "\n${YELLOW}[4/4] Syncing Media Engine Mappings & Profiles...${NC}"

# Sync input.conf
if [ -f "./config/mpv/input.conf" ]; then
  if [ -f "$HOME/.config/mpv/input.conf" ]; then
    echo -e "  [${YELLOW}!${NC}] Existing input.conf spotted. Appending shortcuts safely..."
    echo -e "\n# --- Imported Rofi Queue Mappings ---" >>"$HOME/.config/mpv/input.conf"
    cat "./config/mpv/input.conf" >>"$HOME/.config/mpv/input.conf"
  else
    cp "./config/mpv/input.conf" "$HOME/.config/mpv/input.conf"
  fi
  echo -e "  [${GREEN}✓${NC}] Queue manipulation hotkeys mapped."
fi

# Sync mpv.conf
if [ -f "./config/mpv/mpv.conf" ]; then
  cp "./config/mpv/mpv.conf" "$HOME/.config/mpv/mpv.conf"
  echo -e "  [${GREEN}✓${NC}] Core mpv playback profiles updated."
fi

# Sync youtube-upnext plugin options
if [ -f "./config/mpv/script-opts/youtube-upnext.conf" ]; then
  cp "./config/mpv/script-opts/youtube-upnext.conf" "$MPV_CONF_DIR/youtube-upnext.conf"
  echo -e "  [${GREEN}✓${NC}] Background queuing variables set up."
fi

# Sync ytfzf settings
if [ -f "./config/ytfzf/conf.sh" ]; then
  cp "./config/ytfzf/conf.sh" "$YTFZF_CONF_DIR/conf.sh"
  echo -e "  [${GREEN}✓${NC}] ytfzf terminal search settings compiled."
fi

echo -e "\n${GREEN}============ Auto-Setup Executed Successfully! ============${NC}\n"
