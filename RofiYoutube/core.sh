#!/usr/bin/env bash

#TO DO;
#BRING BACK THE SESSION SELECT FOR CHOSING WITH SESSION TO REPLACE
#ADD A SEARCH HISTORY FEATURE WHEN IN YOUTUBE SEARCH
#A SEARCH RECOMMEND FEATURE WHEN SEARCHING FOR SMTH
#FIX THE PIN!!!

#!/usr/bin/env bash

# ==============================================================================
# ATOMIC CONCURRENCY LOCK ENGINE (Anti-Spam Shield)
# ==============================================================================
LOCKFILE="/tmp/rofi_youtube.lock"
if [ -f "$LOCKFILE" ]; then
  OLD_PID=$(cat "$LOCKFILE" 2>/dev/null)
  if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
    pkill -f "yt-dlp.*ytsearch" 2>/dev/null
    pkill rofi 2>/dev/null
    kill "$OLD_PID" 2>/dev/null
  fi
fi
echo $$ >"$LOCKFILE"
trap 'rm -f "$LOCKFILE"' EXIT

# Export absolute module path routing configurations
export MODULE_DIR="$HOME/.config/hypr/UserScripts/RofiYoutube"
export HISTORY_DIR="$HOME/.cache/RofiYoutube"
export PLAYLIST_HIST="$HISTORY_DIR/playlist_history.txt"
export PLAYLIST_LOG_HIST="$HISTORY_DIR/playlist_history_log.txt"
export SEARCHED_HIST="$HISTORY_DIR/searched_history.txt"
export ALL_PLAYED_HIST="$HISTORY_DIR/all_played_history.txt"
export LIKED_HIST="$HISTORY_DIR/liked_history.txt"
export MANUAL_PL_DIR="$HISTORY_DIR/manual_playlists"
export VIDEO_MODE_FILE="$HISTORY_DIR/video_mode.txt"

# Exact environmental dependencies configurations (Strict Zen Browser Alignment)
export BROWSER_UA="Mozilla/5.0 (X11; Linux x86_64; rv:152.0) Gecko/20100101 Firefox/152.0"
export COOKIE_PATH="$HOME/.config/yt-dlp/youtube-cookies.txt"

mkdir -p "$HISTORY_DIR" "$MANUAL_PL_DIR"
touch "$PLAYLIST_HIST" "$PLAYLIST_LOG_HIST" "$SEARCHED_HIST" "$ALL_PLAYED_HIST" "$LIKED_HIST"
[ -f "$VIDEO_MODE_FILE" ] || echo "video" >"$VIDEO_MODE_FILE"

# Core navigation arrays tracking
ROFI_NAV=(rofi -dmenu -no-show-icons -kb-move-char-back "" -kb-move-char-forward "" -kb-custom-1 Left -kb-custom-2 Right)

# ==============================================================================
# CORE WORKER ENGINES: Playlist Compilation and History Vault Logging
# ==============================================================================
compile_m3u() {
  local src_file="$1" local out_m3u="$2"
  echo "#EXTM3U" >"$out_m3u"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "#EXTINF:-1,$(echo "$line" | sed 's/ ➔ .*//' | sed 's/^\[PIN\] //')" >>"$out_m3u"
    echo "$line" | sed 's/.* ➔ //' >>"$out_m3u"
  done <"$src_file"
}

log_video_history() {
  local type="$1" local video_url="$2" local custom_title="$3" target_file=""
  case "$type" in
  "search") target_file="$SEARCHED_HIST" ;;
  "all") target_file="$ALL_PLAYED_HIST" ;;
  "liked") target_file="$LIKED_HIST" ;;
  "playlist") target_file="$PLAYLIST_LOG_HIST" ;;
  esac

  local video_title="$custom_title"
  if [ -z "$video_title" ]; then
    video_title=$(yt-dlp --cookies "$COOKIE_PATH" --user-agent "$BROWSER_UA" --print "%(title)s" --no-warnings "$video_url" 2>/dev/null | head -n 1)
    [ -z "$video_title" ] && video_title="Video Track (${video_url##*=})"
  fi

  local entry="$video_title ➔ $video_url"
  local tmpfile
  tmpfile=$(mktemp)
  grep -v -F "➔ $video_url" "$target_file" >"$tmpfile" 2>/dev/null
  echo "$entry" | cat - "$tmpfile" | head -n 100 >"$target_file"
  rm -f "$tmpfile"
}

export -f compile_m3u 2>/dev/null || true
export -f log_video_history 2>/dev/null || true

# Main Global Dispatcher Loop
while true; do
  url=""
  choice=""
  selected_video=""

  main_options="Search YouTube\nPlaylist & Mix Manager\nVideo History Vault\nPlaylist Config"
  main_choice=$(echo -e "$main_options" | "${ROFI_NAV[@]}" -p "YouTube Menu" -theme-str 'entry { placeholder: "Choose YouTube Mode..."; }')

  if [ $? -eq 10 ] || [ -z "$main_choice" ]; then exit 0; fi

  case "$main_choice" in
  *"Search YouTube"*)
    source "$MODULE_DIR/search.sh"
    ;;
  *"Playlist & Mix Manager"*)
    source "$MODULE_DIR/manager.sh"
    ;;
  *"Video History Vault"*)
    vault_choice=$(echo -e "Liked Videos Vault\nManually Searched History\nPlayed Playlists History\nAll Played Video History" | "${ROFI_NAV[@]}" -p "History Vault" -theme-str 'entry { placeholder: "Select history log segment..."; }')
    [ $? -eq 10 ] || [ -z "$vault_choice" ] && continue

    if [[ "$vault_choice" == *"Liked Videos"* ]]; then
      export active_file="$LIKED_HIST" placeholder="Filter liked videos vault..." is_liked=true
    elif [[ "$vault_choice" == *"Manually Searched"* ]]; then
      export active_file="$SEARCHED_HIST" placeholder="Filter manual searches..." is_liked=false
    elif [[ "$vault_choice" == *"Played Playlists"* ]]; then
      export active_file="$PLAYLIST_LOG_HIST" placeholder="Filter playlist history vault..." is_liked=false
    else
      export active_file="$ALL_PLAYED_HIST" placeholder="Filter complete video history..." is_liked=false
    fi
    source "$MODULE_DIR/manager.sh"
    ;;
  *"Playlist Config"*)
    source "$MODULE_DIR/config.sh"
    ;;
  esac

  # ============================================================================
  # MASTER BACKGROUND MPV EXECUTION PIPELINE
  # ============================================================================
  if [ -n "$url" ] && [ -n "$choice" ]; then
    sockets=()
    for sock in /tmp/mpvsocket-*; do
      [ -S "$sock" ] || continue
      kill -0 "${sock##*-}" 2>/dev/null && sockets+=("$sock") || rm -f "$sock"
    done

    mpv_video_flag=()
    if [ "$(cat "$VIDEO_MODE_FILE" 2>/dev/null)" == "audio" ]; then
      mpv_video_flag=("--no-video")
      YTDL_FORMAT="bestaudio/best"
    else
      mpv_video_flag=("--video=auto" "--force-window=yes")
      YTDL_FORMAT="bestvideo+bestaudio/best"
    fi

    MPV_UA_OPT="--user-agent=$BROWSER_UA"

    # Verified options pipeline format
    MPV_COOKIES="--cookies-file=$COOKIE_PATH"
    MPV_OPTS="--ytdl-raw-options=yes-playlist=,format=$YTDL_FORMAT,cookies=$COOKIE_PATH --ytdl-raw-options-append=mark-watched="

    if [ ${#sockets[@]} -eq 0 ] && [[ "$choice" == *"Append"* || "$choice" == *"Play Next"* || "$choice" == *"Replace"* ]]; then
      notify-send "YouTube Error" "No active session found! Opening separately." -i notification-message-im
      setsid env WAYLAND_DISPLAY="$WAYLAND_DISPLAY" DISPLAY="$DISPLAY" mpv --input-ipc-server="/tmp/mpvsocket-$$" "$MPV_UA_OPT" "$MPV_COOKIES" $MPV_OPTS "${mpv_video_flag[@]}" "$url" >/dev/null 2>&1 &
      continue
    elif [ ${#sockets[@]} -eq 1 ]; then
      target_socket="${sockets[0]}"
    elif [ ${#sockets[@]} -gt 1 ] && [[ "$choice" != *"Replace"* ]]; then
      rofi_input=""
      declare -A title_to_socket
      for sock in "${sockets[@]}"; do
        title=$(echo '{ "command": ["get_property_string", "media-title"] }' | socat - UNIX-CONNECT:"$sock" 2>/dev/null | head -n 1 | sed -n 's/.*"data":"\(.*\)","error".*/\1/p')
        [ -z "$title" ] && title="Idle Player Instance"
        display_line="$title (PID: ${sock##*-})"
        rofi_input+="$display_line\n"
        title_to_socket["$display_line"]="$sock"
      done
      selected_display=$(echo -e "${rofi_input%\\n}" | "${ROFI_NAV[@]}" -p "Target Session" -theme-str 'entry { placeholder: "Select active session instance..."; }')
      if [ $? -eq 10 ] || [ -z "$selected_display" ]; then continue; fi
      target_socket="${title_to_socket[$selected_display]}"
    fi

    case "$choice" in
    *"Play Selected Playlist Here"*)
      line_num=$(grep -n -F "$selected_video" "$active_file" | head -n1 | cut -d: -f1)
      source "$MODULE_DIR/manager.sh" --compile-only
      setsid env WAYLAND_DISPLAY="$WAYLAND_DISPLAY" DISPLAY="$DISPLAY" mpv --input-ipc-server="/tmp/mpvsocket-$$" "$MPV_UA_OPT" "$MPV_COOKIES" $MPV_OPTS "${mpv_video_flag[@]}" --playlist-start=$((line_num - 1)) "/tmp/rofi_mpv_playlist.m3u" >/dev/null 2>&1 &
      notify-send "Playlist Player" "Loading local playlist..." -i notification-audio-play
      ;;
    *"Play Playlist in Reverse"*)
      line_num=$(grep -n -F "$selected_video" "$active_file" | head -n1 | cut -d: -f1)
      total_lines=$(wc -l <"$active_file")
      tac "$active_file" >"/tmp/rofi_reversed.txt"
      active_file="/tmp/rofi_reversed.txt" source "$MODULE_DIR/manager.sh" --compile-only
      setsid env WAYLAND_DISPLAY="$WAYLAND_DISPLAY" DISPLAY="$DISPLAY" mpv --input-ipc-server="/tmp/mpvsocket-$$" "$MPV_UA_OPT" "$MPV_COOKIES" $MPV_OPTS "${mpv_video_flag[@]}" --playlist-start=$((total_lines - line_num)) "/tmp/rofi_mpv_playlist.m3u" >/dev/null 2>&1 &
      notify-send "Playlist Player" "Loading reversed local playlist..." -i notification-audio-play
      ;;
    *"Play Playlist Shuffled"*)
      source "$MODULE_DIR/manager.sh" --compile-only
      setsid env WAYLAND_DISPLAY="$WAYLAND_DISPLAY" DISPLAY="$DISPLAY" mpv --input-ipc-server="/tmp/mpvsocket-$$" "$MPV_UA_OPT" "$MPV_COOKIES" $MPV_OPTS "${mpv_video_flag[@]}" --shuffle "/tmp/rofi_mpv_playlist.m3u" >/dev/null 2>&1 &
      notify-send "Playlist Player" "Loading randomized local playlist..." -i notification-audio-play
      ;;
    *"Play in New Window"* | *"Play Mix in New Window"*)
      setsid env WAYLAND_DISPLAY="$WAYLAND_DISPLAY" DISPLAY="$DISPLAY" mpv --input-ipc-server="/tmp/mpvsocket-$$" "$MPV_UA_OPT" "$MPV_COOKIES" $MPV_OPTS "${mpv_video_flag[@]}" "$url" >/dev/null 2>&1 &
      notify-send "YouTube Player" "Opening track window instance" -i notification-audio-play
      ;;
    *"Append to Queue"* | *"Append Mix to Queue"*)
      echo '{"command": ["loadfile", "'"$url"'", "append"]}' | socat - UNIX-CONNECT:"$target_socket"
      notify-send "YouTube Queue" "Appended to end of stream!" -i notification-audio-play
      ;;
    *"Play Next"* | *"Play Mix Next (Queue)"*)
      if [ -S "$target_socket" ]; then
        echo '{"command": ["loadfile", "'"$url"'", "append-play"]}' | socat - UNIX-CONNECT:"$target_socket"
        notify-send "YouTube Queue" "Inserted track to play next!" -i notification-audio-play
      else
        setsid env WAYLAND_DISPLAY="$WAYLAND_DISPLAY" DISPLAY="$DISPLAY" mpv --input-ipc-server="/tmp/mpvsocket-$$" "$MPV_UA_OPT" "$MPV_COOKIES" $MPV_OPTS "${mpv_video_flag[@]}" "$url" >/dev/null 2>&1 &
        notify-send "YouTube Queue" "Queue empty. Initializing playback engine!" -i notification-audio-play
      fi
      ;;
    *"Replace Active Session"*)
      if [ ${#sockets[@]} -gt 1 ]; then
        rofi_input=""
        declare -A replace_map
        for sock in "${sockets[@]}"; do
          title=$(echo '{ "command": ["get_property_string", "media-title"] }' | socat - UNIX-CONNECT:"$sock" 2>/dev/null | head -n 1 | sed -n 's/.*"data":"\(.*\)","error".*/\1/p')
          [ -z "$title" ] && title="Idle Player Instance"
          display_line="$title (PID: ${sock##*-})"
          rofi_input+="$display_line\n"
          replace_map["$display_line"]="$sock"
        done
        selected_display=$(echo -e "${rofi_input%\\n}" | "${ROFI_NAV[@]}" -p "Select Session to Replace" -theme-str 'entry { placeholder: "Which player session should take this track?"; }')
        if [ $? -eq 10 ] || [ -z "$selected_display" ]; then continue; fi
        target_socket="${replace_map[$selected_display]}"
      else
        target_socket="${sockets[0]}"
      fi

      if [ -n "$target_socket" ]; then
        echo '{"command": ["loadfile", "'"$url"'", "replace"]}' | socat - UNIX-CONNECT:"$target_socket"
        notify-send "YouTube Player" "Track hot-swapped into active session!" -i notification-audio-play
      fi
      ;;
    esac
  fi
done
