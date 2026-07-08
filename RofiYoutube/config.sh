#!/usr/bin/env bash
# config.sh — Configuration adjustment parameters module

# Explicitly map path variables to ensure synchronization across scripts
UPNEXT_CONF="$HOME/.config/mpv/script-opts/youtube-upnext.conf"
VIDEO_MODE_FILE="$HOME/.cache/RofiYoutube/video_mode.txt"

# Ensure the native MPV plugin config file exists so grep doesn't crash
if [ ! -f "$UPNEXT_CONF" ]; then
  mkdir -p "$(dirname "$UPNEXT_CONF")"
  echo -e "auto_add=yes\nskip_longer_than=\"10:00\"" >"$UPNEXT_CONF"
fi

# 1. FIXED: Safely read paths from our new project cache space with a strict default fallback
video_mode_status=$(cat "$VIDEO_MODE_FILE" 2>/dev/null)
[ -z "$video_mode_status" ] && video_mode_status="video"

# Extract the current value (yes or no) directly from the native MPV conf file
autoplay_status=$(grep "^auto_add=" "$UPNEXT_CONF" | cut -d'=' -f2 | tr -d '"[:space:]')
[ -z "$autoplay_status" ] && autoplay_status="yes"

config_options="Toggle Autoplay (Current: ${autoplay_status^^})\nToggle Video Output (Current: ${video_mode_status^^})\nEdit Liked Videos Vault\nEdit Saved YouTube Mixes\nEdit Manual Playlist"
config_choice=$(echo -e "$config_options" | "${ROFI_NAV[@]}" -p "Configuration" -theme-str 'entry { placeholder: "Select configuration file or option..."; }')
[ $? -eq 10 ] || [ -z "$config_choice" ] && return

if [[ "$config_choice" == *"Toggle Autoplay"* ]]; then
  if [ "$autoplay_status" == "yes" ]; then
    sed -i 's/^auto_add=.*/auto_add=no/' "$UPNEXT_CONF"
    notify-send "Autoplay" "Disabled (auto_add=no)" -i notification-audio-play
  else
    sed -i 's/^auto_add=.*/auto_add=yes/' "$UPNEXT_CONF"
    notify-send "Autoplay" "Enabled (auto_add=yes)" -i notification-audio-play
  fi
elif [[ "$config_choice" == *"Toggle Video Output"* ]]; then
  # 2. FIXED: Writes the text straight to our clean, unified cache destination folder
  if [ "$video_mode_status" == "video" ]; then
    echo "audio" >"$VIDEO_MODE_FILE"
    notify-send "Video Output" "Switched to Audio-Only Mode (--no-video)" -i notification-audio-play
  else
    echo "video" >"$VIDEO_MODE_FILE"
    notify-send "Video Output" "Switched to Graphical Video Mode" -i notification-audio-play
  fi
elif [[ "$config_choice" == *"Edit Liked Videos"* ]]; then
  open_in_nvim "$LIKED_HIST"
elif [[ "$config_choice" == *"Edit Saved YouTube Mixes"* ]]; then
  open_in_nvim "$PLAYLIST_HIST"
elif [[ "$config_choice" == *"Edit Manual Playlist"* ]]; then
  if [ -z "$(ls -A "$MANUAL_PL_DIR" 2>/dev/null)" ]; then
    notify-send "Playlist Error" "No manual playlists exist!" -i notification-message-im
    return
  fi
  edit_targets=$(basename -a "$MANUAL_PL_DIR"/* | sed 's/\.txt//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  selected_index=$(echo -e "$edit_targets" | "${ROFI_NAV[@]}" -format i -p "Select Edit Target" -theme-str 'entry { placeholder: "Select manual playlist file to pass to nvim..."; }')
  if [ $? -ne 10 ] && [ -n "$selected_index" ]; then
    target_edit=$(basename -a "$MANUAL_PL_DIR"/* | sed -n "$((selected_index + 1))p")
    open_in_nvim "$MANUAL_PL_DIR/$target_edit"
  fi
fi
