#!/usr/bin/env bash
# config.sh — Configuration adjustment parameters module

autoplay_status=$(cat "$AUTOPLAY_FILE")
video_mode_status=$(cat "$VIDEO_MODE_FILE")

config_options="Toggle Autoplay (Current: ${autoplay_status^^})\nToggle Video Output (Current: ${video_mode_status^^})\nEdit Liked Videos Vault\nEdit Saved YouTube Mixes\nEdit Manual Playlist"
config_choice=$(echo -e "$config_options" | "${ROFI_NAV[@]}" -p "Configuration" -theme-str 'entry { placeholder: "Select configuration file or option..."; }')
[ $? -eq 10 ] || [ -z "$config_choice" ] && return

if [[ "$config_choice" == *"Toggle Autoplay"* ]]; then
  [ "$autoplay_status" == "yes" ] && echo "no" >"$AUTOPLAY_FILE" || echo "yes" >"$AUTOPLAY_FILE"
elif [[ "$config_choice" == *"Toggle Video Output"* ]]; then
  [ "$video_mode_status" == "video" ] && echo "audio" >"$VIDEO_MODE_FILE" || echo "video" >"$VIDEO_MODE_FILE"
elif [[ "$config_choice" == *"Edit Liked Videos"* ]]; then
  open_in_nvim "$LIKED_HIST"
elif [[ "$config_choice" == *"Edit Saved YouTube Mixes"* ]]; then
  open_in_nvim "$PLAYLIST_HIST"
elif [[ "$config_choice" == *"Edit Manual Playlist"* ]]; then
  [ -z "$(ls -A "$MANUAL_PL_DIR" 2>/dev/null)" ] && {
    notify-send "Playlist Error" "No manual playlists exist!" -i notification-message-im
    return
  }
  edit_targets=$(basename -a "$MANUAL_PL_DIR"/* | sed 's/\.txt//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  selected_index=$(echo -e "$edit_targets" | "${ROFI_NAV[@]}" -format i -p "Select Edit Target" -theme-str 'entry { placeholder: "Select manual playlist file to pass to nvim..."; }')
  if [ $? -ne 10 ] && [ -n "$selected_index" ]; then
    target_edit=$(basename -a "$MANUAL_PL_DIR"/* | sed -n "$((selected_index + 1))p")
    open_in_nvim "$MANUAL_PL_DIR/$target_edit"
  fi
fi
