#!/usr/bin/env bash

# ==============================================================================
# COLOR DEFINITIONS & TEXT FORMATTING
# ==============================================================================
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
APP_VERSION="v1.2.0"

# Target configurations
ROFI_TARGET_DIR="$HOME/.config/hypr/UserScripts/RofiYoutube"
YTDL_TARGET_DIR="$HOME/.config/yt-dlp"
MPV_TARGET_DIR="$HOME/.config/mpv"

# Managed file symlink targets
LINK_CORE="$ROFI_TARGET_DIR/core.sh"
LINK_YTDL="$YTDL_TARGET_DIR/config"
LINK_MPV_CONF="$MPV_TARGET_DIR/mpv.conf"
LINK_MPV_INPUT="$MPV_TARGET_DIR/input.conf"

print_header() {
  clear
  # High-density block array matching the vertical dither cascade structure
  echo -e "${BLUE}${BOLD}"
  cat <<"EOF"
  ▄████▄   ▄████▄   ██████  ██      ▄██   ▄██  ████████ 
  ██  ██  ██    ██  ██      ██       ██   ██      ██    
  █████▄  ██    ██  █████   ██        ██ ██       ██    
  ██  ██  ██    ██  ██      ██         ███        ██    
  ██  ██   ▀████▀   ██      ██          █         ██    
  ▓▓  ▓▓    ▓▓▓▓    ▓▓      ▓▓         ▓▓▓        ▓▓    
  ▒▒  ▒▒    ▒▒▒▒    ▒▒      ▒▒          ▒         ▒▒    
  ░░  ░░     ░░     ░░      ░░                    ░░    
       ▖              ▖                                 
EOF
  echo -e "         ${NC}${BOLD}{${APP_VERSION}}${BLUE} - Made for rofi-youtube-client${NC}"
  echo -e "${BLUE}${BOLD}====================================================${NC}"
  echo -e "${BLUE}${BOLD}         ROFI YOUTUBE CLIENT ENGINE MANAGER         ${NC}"
  echo -e "${BLUE}${BOLD}====================================================${NC}"
}

print_goodbye() {
  echo -e "${RED}${BOLD}"
  cat <<"EOF"
  _          _       
 | |__  _  _(_)__  __ 
 | '_ \| || | / _)/ _)
 |_.__/\_,  | \___\___)
       |___/          
EOF
  echo -e "${NC}\nExiting installer engine safely. Catch you later!\n"
}

# ==============================================================================
# CORE WORKER UTILITIES
# ==============================================================================
check_dependencies() {
  echo -e "\n${BLUE} Checking system dependencies...${NC}"
  local dependencies=("rofi" "mpv" "yt-dlp" "socat" "notify-send" "git")
  local missing=()

  for cmd in "${dependencies[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then missing+=("$cmd"); fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    echo -e "${RED}${BOLD}❌ Error: Missing tools:${NC} ${missing[*]}"
    echo -e "${YELLOW}Install them via pacman: sudo pacman -S rofi mpv yt-dlp socat libnotify git${NC}"
    exit 1
  fi
  echo -e "${GREEN}✓ All dependencies verified!${NC}"
}

safe_link() {
  local src="$1" local dest="$2"
  [ -f "$src" ] || return 0

  if [ -f "$dest" ] || [ -L "$dest" ]; then
    if [ "$(readlink -f "$dest" 2>/dev/null)" == "$src" ]; then
      echo -e "${BLUE}ℹ Already Linked:${NC} $(basename "$dest")"
      return 0
    fi
    mv "$dest" "${dest}.bak_${TIMESTAMP}"
    echo -e "${YELLOW}⇄ Backed up existing layout: $(basename "$dest")${NC}"
  fi
  ln -sf "$src" "$dest"
  echo -e "${GREEN}✓ Connected link:${NC} $dest"
}

# ==============================================================================
# ACTIONS IMPLEMENTATION
# ==============================================================================
run_install() {
  check_dependencies
  echo -e "\n${BLUE} Deploying config symlinks...${NC}"
  mkdir -p "$ROFI_TARGET_DIR" "$YTDL_TARGET_DIR" "$MPV_TARGET_DIR"

  [ -f "$REPO_DIR/RofiYoutube/core.sh" ] && chmod +x "$REPO_DIR/RofiYoutube/core.sh"
  safe_link "$REPO_DIR/RofiYoutube/core.sh" "$LINK_CORE"
  safe_link "$REPO_DIR/config/yt-dlp/config" "$LINK_YTDL"
  safe_link "$REPO_DIR/config/mpv/mpv.conf" "$LINK_MPV_CONF"
  safe_link "$REPO_DIR/config/mpv/input.conf" "$LINK_MPV_INPUT"

  if [ ! -f "$YTDL_TARGET_DIR/youtube-cookies.txt" ]; then
    echo -e "\n${YELLOW}📝 Reminder: Place your browser cookies array at:${NC}"
    echo -e "   $YTDL_TARGET_DIR/youtube-cookies.txt"
  fi
  echo -e "\n${GREEN}${BOLD}🎉 Installation completed successfully!${NC}"
}

run_uninstall() {
  echo -e "\n${RED}${BOLD} Removing client application links...${NC}"

  local targets=("$LINK_CORE" "$LINK_YTDL" "$LINK_MPV_CONF" "$LINK_MPV_INPUT")
  for target in "${targets[@]}"; do
    if [ -L "$target" ]; then
      rm "$target"
      echo -e "${GREEN}✓ Removed link:${NC} $target"
    elif [ -f "$target" ]; then
      echo -e "${YELLOW}⚠ Skipping physical file (not a symlink):${NC} $target"
    fi
  done
  echo -e "${GREEN}✓ Clean up sequence finished.${NC}"
}

run_update() {
  echo -e "\n${PURPLE} Initiating repository sync & update...${NC}"
  cd "$REPO_DIR" || exit 1

  if [ ! -d ".git" ]; then
    echo -e "${RED}❌ Error: This directory is not a git repository. Cannot update upstream.${NC}"
    return 1
  fi

  local stashed=false
  if ! git diff-index --quiet HEAD --; then
    echo -e "${YELLOW}⇄ Dirty tree state detected! Stashing your local deviations...${NC}"
    git stash push -m "Automatic script stash via installer on $TIMESTAMP"
    stashed=true
  fi

  echo -e "${BLUE} Pulling updates from master tracking branch...${NC}"
  git checkout main &>/dev/null
  if git pull origin main; then
    echo -e "${GREEN}✓ Repository pulled successfully.${NC}"
  else
    echo -e "${RED}❌ Error: Failed to pull remote updates from origin.${NC}"
  fi

  if [ "$stashed" = true ]; then
    echo -e "${PURPLE} Re-applying your personal configuration stashes...${NC}"
    if git stash pop; then
      echo -e "${GREEN}✓ Stash popped cleanly.${NC}"
    else
      echo -e "${RED}⚠ Conflict warning: Merge collision occurred while re-applying changes.${NC}"
      echo -e "${YELLOW}Please check 'git status' to resolve any manual edits.${NC}"
    fi
  fi

  run_install
}

run_reinstall() {
  echo -e "\n${YELLOW}${BOLD}⚠️  Executing a clean reinstall process...${NC}"
  run_uninstall

  echo -e "${RED} Clearing stale system locks and active player pipes...${NC}"
  pkill -9 -f "mpv.*mpvsocket" 2>/dev/null
  rm -f /tmp/rofi_youtube.lock /tmp/mpvsocket-*

  run_install
}

# ==============================================================================
# ENTRY DISPATCHER LOOP
# ==============================================================================
print_header

if [ -n "$1" ]; then
  case "$1" in
  --install) run_install ;;
  --uninstall) run_uninstall ;;
  --update) run_update ;;
  --reinstall) run_reinstall ;;
  *) echo -e "${RED}Unknown argument: $1${NC}\nUsage: $0 [--install|--uninstall|--update|--reinstall]" ;;
  esac
  exit 0
fi

echo -e "Please select an operational lifecycle strategy:\n"
echo -e "  ${BOLD}[1]${NC} ${GREEN}Install${NC}         - Set up fresh config symlinks and dependencies"
echo -e "  ${BOLD}[2]${NC} ${RED}Uninstall${NC}       - Strip managed configuration paths cleanly"
echo -e "  ${BOLD}[3]${NC} ${PURPLE}Update${NC}          - Safe auto-stash, pull changes, and re-link"
echo -e "  ${BOLD}[4]${NC} ${YELLOW}Clean Reinstall${NC} - Flush runtime locks/sockets and reset environment"
echo -e "  ${BOLD}[5]${NC} Exit"
echo -ne "\n${BOLD}Selection (1-5): ${NC}"
read -r choice

case "$choice" in
1) run_install ;;
2) run_uninstall ;;
3) run_update ;;
4) run_reinstall ;;
5)
  print_goodbye
  exit 0
  ;;
*)
  echo -e "\n${RED}Invalid selection.${NC} Aborting interface sequence."
  exit 1
  ;;
esac
