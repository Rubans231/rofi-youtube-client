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

# Storage layout targets
HISTORY_DIR="$HOME/.cache/ytfzf"
PLAYLIST_HIST="$HISTORY_DIR/playlist_history.txt"
SEARCHED_HIST="$HISTORY_DIR/searched_history.txt"
ALL_PLAYED_HIST="$HISTORY_DIR/all_played_history.txt"
LIKED_HIST="$HISTORY_DIR/liked_history.txt"
MANUAL_PL_DIR="$HISTORY_DIR/manual_playlists"
AUTOPLAY_FILE="$HISTORY_DIR/autoplay_toggle.txt"
VIDEO_MODE_FILE="$HISTORY_DIR/video_mode.txt"

mkdir -p "$HISTORY_DIR" "$MANUAL_PL_DIR"
touch "$PLAYLIST_HIST" "$SEARCHED_HIST" "$ALL_PLAYED_HIST" "$LIKED_HIST"
[ -f "$AUTOPLAY_FILE" ] || echo "yes" >"$AUTOPLAY_FILE"
[ -f "$VIDEO_MODE_FILE" ] || echo "video" >"$VIDEO_MODE_FILE"

# Core Navigation Array: Disables default char-stepping to map Left and Right arrows globally
ROFI_NAV=(rofi -dmenu -no-show-icons -kb-move-char-back "" -kb-move-char-forward "" -kb-custom-1 Left -kb-custom-2 Right)

# EXACT COMMAND TARGETS: Universal Identity Variables
COOKIE_PATH="$HOME/.config/yt-dlp/youtube-cookies.txt"
BROWSER_UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, Gecko) Chrome/120.0.0.0 Safari/537.36"

# ==============================================================================
# Helper Engines: M3U Compiler, Asynchronous Logger, & Terminal Spawner
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

add_to_manual_playlist() {
  local v_title="$1" local v_url="$2"
  if [ -z "$(ls -A "$MANUAL_PL_DIR" 2>/dev/null)" ]; then
    notify-send "Playlist Error" "No manual playlists exist yet!" -i notification-message-im
    return 1
  fi

  local pl_titles
  pl_titles=$(basename -a "$MANUAL_PL_DIR"/* | sed 's/\.txt//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  local selected_index
  selected_index=$(echo -e "$pl_titles" | "${ROFI_NAV[@]}" -format i -p "Choose Playlist" -theme-str 'entry { placeholder: "Select target manual playlist..."; }')
  [ $? -eq 10 ] || [ -z "$selected_index" ] && return 1

  local pl_choice
  pl_choice=$(basename -a "$MANUAL_PL_DIR"/* | sed -n "$((selected_index + 1))p")
  echo "$v_title ➔ $v_url" >>"$MANUAL_PL_DIR/$pl_choice"
  notify-send "Playlist Manager" "Added track to: ${pl_choice%.txt}" -i notification-audio-play
}

open_in_nvim() {
  local target_path="$1"
  for term in alacritty kitty foot xterm konsole gnome-terminal; do
    if command -v "$term" &>/dev/null; then
      $term -e nvim "$target_path" &
      return 0
    fi
  done
  notify-send "Editor Error" "No compatible terminal found to launch nvim!" -i notification-message-im
}

# ==============================================================================
# Main Unified State Machine Loop
# ==============================================================================
while true; do
  active_file=""
  placeholder=""
  is_liked=false
  url=""
  choice=""
  selected_video=""

  main_options="Search YouTube\nPlaylist & Mix Manager\nVideo History Vault\nPlaylist Config"
  main_choice=$(echo -e "$main_options" | "${ROFI_NAV[@]}" -p "YouTube Menu" -theme-str 'entry { placeholder: "Choose YouTube Mode..."; }')
  if [ $? -eq 10 ] || [ -z "$main_choice" ]; then exit 0; fi

  # ----------------------------------------------------------------------------
  # PATH A: Direct Search Pipeline
  # ----------------------------------------------------------------------------
  if [[ "$main_choice" == *"Search YouTube"* ]]; then
    query=$("${ROFI_NAV[@]}" -p "YouTube Search" -theme-str 'entry { placeholder: "Type search query (Left Arrow goes Back)..."; }')
    if [ $? -eq 10 ] || [ -z "$query" ]; then continue; fi

    notify-send "Search Engine" "Querying YouTube securely..." -i notification-audio-play

    # Formats native endpoints for videos, channels, and playlists, filtering out broken items
    search_results=$(yt-dlp "ytsearch20:$query" \
      --user-agent "$BROWSER_UA" \
      --cookies "$COOKIE_PATH" \
      --flat-playlist \
      --print "%(title)s ➔ %(url)s" \
      --no-warnings 2>/dev/null | grep -E '(watch\?v=[A-Za-z0-9_-]{11}$|/channel/UC[A-Za-z0-9_-]{22}$|playlist\?list=PL[A-Za-z0-9_-]{32}$)')

    if [ -z "$search_results" ]; then
      notify-send "Search Error" "YouTube rejected scraping or no valid items found." -i notification-message-im
      continue
    fi

    # Restored wide Japanese space replacement 's/ //g' to safeguard layout spacing
    rofi_titles=$(echo -e "$search_results" | sed 's/ ➔ .*//' | sed 's/【/[/g; s/】/]/g; s/ //g; s/^[[:space:]]*//;s/[[:space:]]*$//')

    selected_index=$(echo -e "$rofi_titles" | "${ROFI_NAV[@]}" -format i -p "Select Item" -theme-str 'entry { placeholder: "Select track or link (Left Arrow goes Back)..."; }')
    if [ $? -eq 10 ] || [ -z "$selected_index" ]; then continue; fi

    matched_line=$(echo -e "$search_results" | sed -n "$((selected_index + 1))p")
    url=$(echo "$matched_line" | sed 's/.* ➔ //')
    title_extracted=$(echo "$matched_line" | sed 's/ ➔ .*//' | sed 's/【/[/g; s/】/]/g; s/ //g; s/^[[:space:]]*//;s/[[:space:]]*$//')

    options="Play in New Window\nPlay Next (Queue)\nAppend to Queue\nReplace Active Session\nSave to Liked Videos\nAdd to Manual Playlist\nDownload Video"
    choice=$(echo -e "$options" | "${ROFI_NAV[@]}" -p "Video Action" -theme-str 'entry { placeholder: "Choose playback action..."; }')
    if [ $? -eq 10 ] || [ -z "$choice" ]; then continue; fi

    if [[ "$choice" == *"Save to Liked Videos"* ]]; then
      log_video_history "liked" "$url" "$title_extracted"
      notify-send "Liked Videos" "Saved to favorites vault!" -i notification-audio-play
      continue
    elif [[ "$choice" == *"Add to Manual Playlist"* ]]; then
      add_to_manual_playlist "$title_extracted" "$url"
      continue
    elif [[ "$choice" == *"Download Video"* ]]; then
      notify-send "Downloader" "Starting background download to ~/Downloads..." -i notification-audio-play
      yt-dlp --user-agent "$BROWSER_UA" --cookies "$COOKIE_PATH" -P "~/Downloads" "$url" &
      continue
    fi
    log_video_history "search" "$url" "$title_extracted" &
    log_video_history "all" "$url" "$title_extracted" &

  # ----------------------------------------------------------------------------
  # PATH B: Playlist & Mix Manager
  # ----------------------------------------------------------------------------
  elif [[ "$main_choice" == *"Playlist & Mix Manager"* ]]; then
    while true; do
      mix_options="Select Saved YouTube Mix\nPaste New YouTube Mix\nManual Playlists"
      mix_choice=$(echo -e "$mix_options" | "${ROFI_NAV[@]}" -p "Playlist Manager" -theme-str 'entry { placeholder: "Select playlist database option..."; }')
      if [ $? -eq 10 ] || [ -z "$mix_choice" ]; then break; fi

      if [[ "$mix_choice" == *"Select Saved YouTube Mix"* ]]; then
        if [ ! -s "$PLAYLIST_HIST" ]; then
          notify-send "YouTube Error" "No mix history found!" -i notification-message-im
          continue
        fi

        mix_titles=$(cat "$PLAYLIST_HIST" | sed 's/ ➔ .*//' | sed 's/【/[/g; s/】/]/g; s/ //g; s/^[[:space:]]*//;s/[[:space:]]*$//')
        selected_index=$(echo -e "$mix_titles" | "${ROFI_NAV[@]}" -format i -p "YouTube Mixes" -theme-str 'entry { placeholder: "Select a saved online mix..."; }')
        if [ $? -eq 10 ] || [ -z "$selected_index" ]; then continue; fi

        selected_line=$(cat "$PLAYLIST_HIST" | sed -n "$((selected_index + 1))p")
        options="Play in New Window\nPlay Playlist in Reverse\nPlay Playlist Shuffled\nPlay Next (Queue)\nAppend to Queue\nReplace Active Session\nPin / Unpin Playlist\nRemove Playlist\nMove Line Up\nMove Line Down"
        choice=$(echo -e "$options" | "${ROFI_NAV[@]}" -p "Playlist Action" -theme-str 'entry { placeholder: "Choose action for saved mix..."; }')
        if [ $? -eq 10 ] || [ -z "$choice" ]; then continue; fi
        mix_url=$(echo "$selected_line" | sed 's/.* ➔ //')

        if [[ "$choice" == *"Pin / Unpin Playlist"* ]]; then
          if [[ "$selected_line" == "\[PIN\] "* ]]; then new_line=$(echo "$selected_line" | sed 's/^\[PIN\] //'); else new_line="[PIN] $selected_line"; fi
          awk -v old="$selected_line" -v new="$new_line" '{if ($0 == old) print new; else print}' "$PLAYLIST_HIST" >"$HISTORY_DIR/tmp" && mv "$HISTORY_DIR/tmp" "$PLAYLIST_HIST"
          (
            grep '^\[PIN\]' "$PLAYLIST_HIST"
            grep -v '^\[PIN\]' "$PLAYLIST_HIST"
          ) >"$HISTORY_DIR/tmp_sort" && mv "$HISTORY_DIR/tmp_sort" "$PLAYLIST_HIST"
          continue
        elif [[ "$choice" == *"Remove Playlist"* ]]; then
          grep -v -F "$selected_line" "$PLAYLIST_HIST" >"$HISTORY_DIR/tmp" && mv "$HISTORY_DIR/tmp" "$PLAYLIST_HIST"
          continue
        elif [[ "$choice" == *"Move Line Up"* || "$choice" == *"Move Line Down"* ]]; then
          line_num=$(grep -n -F "$selected_line" "$PLAYLIST_HIST" | head -n1 | cut -d: -f1)
          total_lines=$(wc -l <"$PLAYLIST_HIST")
          if [[ "$choice" == *"Move Line Up"* && $line_num -gt 1 ]]; then
            l1=$((line_num - 1)) l2=$line_num
            awk -v l1="$l1" -v l2="$l2" 'NR==l1 {line1=$0; next} NR==l2 {print $0; print line1; next} {print}' "$PLAYLIST_HIST" >"$HISTORY_DIR/tmp" && mv "$HISTORY_DIR/tmp" "$PLAYLIST_HIST"
          elif [[ "$choice" == *"Move Line Down"* && $line_num -lt $total_lines ]]; then
            l1=$line_num l2=$((line_num + 1))
            awk -v l1="$l1" -v l2="$l2" 'NR==l1 {line1=$0; next} NR==l2 {print $0; print line1; next} {print}' "$PLAYLIST_HIST" >"$HISTORY_DIR/tmp" && mv "$HISTORY_DIR/tmp" "$PLAYLIST_HIST"
          fi
          continue
        fi
        url="$mix_url"
        break

      elif [[ "$mix_choice" == *"Paste New YouTube Mix"* ]]; then
        clip=$(wl-paste 2>/dev/null)
        if [[ "$clip" =~ ^http ]]; then
          mix_selection=$(echo -e "Use Copied Link (${clip:0:30}...)\nEnter URL Manually" | "${ROFI_NAV[@]}" -p "Select Source" -theme-str 'entry { placeholder: "Choose link source entry point..."; }')
          if [ $? -eq 10 ] || [ -z "$mix_selection" ]; then continue; fi
          [[ "$mix_selection" == *"Use Copied Link"* ]] && mix_url="$clip" || mix_url=$("${ROFI_NAV[@]}" -p "Paste Mix Link:" -theme-str 'entry { placeholder: "Paste raw mix URL here..."; }')
        else mix_url=$("${ROFI_NAV[@]}" -p "Paste Mix Link:" -theme-str 'entry { placeholder: "Paste raw mix URL here..."; }'); fi
        if [ $? -eq 10 ] || [ -z "$mix_url" ]; then continue; fi
        playlist_name=$("${ROFI_NAV[@]}" -p "Name Mix" -theme-str 'entry { placeholder: "Assign a custom name for reference..."; }')
        if [ $? -eq 10 ] || [ -z "$playlist_name" ]; then continue; fi
        echo "$playlist_name ➔ $mix_url" | cat - "$PLAYLIST_HIST" >"$HISTORY_DIR/tmp_hist" && mv "$HISTORY_DIR/tmp_hist" "$PLAYLIST_HIST"
        (
          grep '^\[PIN\]' "$PLAYLIST_HIST"
          grep -v '^\[PIN\]' "$PLAYLIST_HIST"
        ) >"$HISTORY_DIR/tmp_sort" && mv "$HISTORY_DIR/tmp_sort" "$PLAYLIST_HIST"
        url="$mix_url"
        break

      elif [[ "$mix_choice" == *"Manual Playlists"* ]]; then
        while true; do
          manual_options="View / Play Playlist\nCreate New Playlist\nDelete Playlist"
          manual_choice=$(echo -e "$manual_options" | "${ROFI_NAV[@]}" -p "Playlists Manager" -theme-str 'entry { placeholder: "Manage manual custom playlists..."; }')
          if [ $? -eq 10 ] || [ -z "$manual_choice" ]; then break; fi

          if [[ "$manual_choice" == *"Create New Playlist"* ]]; then
            new_pl=$("${ROFI_NAV[@]}" -p "New Playlist Name" -theme-str 'entry { placeholder: "Type name for new custom playlist..."; }')
            if [ $? -ne 10 ] && [ -n "$new_pl" ]; then
              touch "$MANUAL_PL_DIR/$new_pl.txt"
              notify-send "Manual Playlist" "Created empty playlist: $new_pl" -i notification-audio-play
            fi
            continue
          elif [[ "$manual_choice" == *"Delete Playlist"* ]]; then
            if [ -z "$(ls -A "$MANUAL_PL_DIR" 2>/dev/null)" ]; then
              notify-send "Playlist Error" "No manual playlists exist!" -i notification-message-im
              continue
            fi

            pl_names=$(basename -a "$MANUAL_PL_DIR"/* | sed 's/\.txt//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            selected_index=$(echo -e "$pl_names" | "${ROFI_NAV[@]}" -format i -p "Delete Playlist" -theme-str 'entry { placeholder: "Select manual playlist to permanently destroy..."; }')
            if [ $? -ne 10 ] && [ -n "$selected_index" ]; then
              target_del=$(basename -a "$MANUAL_PL_DIR"/* | sed -n "$((selected_index + 1))p")
              rm -f "$MANUAL_PL_DIR/$target_del"
              notify-send "Manual Playlist" "Deleted playlist: ${target_del%.txt}" -i notification-message-im
            fi
            continue
          elif [[ "$manual_choice" == *"View / Play Playlist"* ]]; then
            if [ -z "$(ls -A "$MANUAL_PL_DIR" 2>/dev/null)" ]; then
              notify-send "Playlist Error" "No manual playlists exist!" -i notification-message-im
              continue
            fi

            pl_targets=$(basename -a "$MANUAL_PL_DIR"/* | sed 's/\.txt//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            selected_index=$(echo -e "$pl_targets" | "${ROFI_NAV[@]}" -format i -p "Open Playlist" -theme-str 'entry { placeholder: "Select manual playlist to load..."; }')
            if [ $? -eq 10 ] || [ -z "$selected_index" ]; then continue; fi

            target_file=$(basename -a "$MANUAL_PL_DIR"/* | sed -n "$((selected_index + 1))p")
            active_file="$MANUAL_PL_DIR/$target_file"
            placeholder="Custom Playlist: ${target_file%.txt}..."
            is_liked=true
            break 2
          fi
        done
      fi
    done

  # ----------------------------------------------------------------------------
  # PATH C: Video History Vault
  # ----------------------------------------------------------------------------
  elif [[ "$main_choice" == *"Video History Vault"* ]]; then
    vault_choice=$(echo -e "Liked Videos Vault\nManually Searched History\nAll Played Video History" | "${ROFI_NAV[@]}" -p "History Vault" -theme-str 'entry { placeholder: "Select history log segment..."; }')
    if [ $? -eq 10 ] || [ -z "$vault_choice" ]; then continue; fi
    if [[ "$vault_choice" == *"Liked Videos"* ]]; then
      active_file="$LIKED_HIST"
      placeholder="Filter liked videos vault..."
      is_liked=true
    elif [[ "$vault_choice" == *"Manually Searched"* ]]; then
      active_file="$SEARCHED_HIST"
      placeholder="Filter manual searches..."
      is_liked=false
    else
      active_file="$ALL_PLAYED_HIST"
      placeholder="Filter complete video history..."
      is_liked=false
    fi

  # ----------------------------------------------------------------------------
  # PATH D: Playlist Config & Neovim Editor Core
  # ----------------------------------------------------------------------------
  elif [[ "$main_choice" == *"Playlist Config"* ]]; then
    autoplay_status=$(cat "$AUTOPLAY_FILE")
    video_mode_status=$(cat "$VIDEO_MODE_FILE")

    config_options="Toggle Autoplay (Current: ${autoplay_status^^})\nToggle Video Output (Current: ${video_mode_status^^})\nEdit Liked Videos Vault\nEdit Saved YouTube Mixes\nEdit Manual Playlist"
    config_choice=$(echo -e "$config_options" | "${ROFI_NAV[@]}" -p "Configuration" -theme-str 'entry { placeholder: "Select configuration file or option..."; }')
    if [ $? -eq 10 ] || [ -z "$config_choice" ]; then continue; fi

    if [[ "$config_choice" == *"Toggle Autoplay"* ]]; then
      [ "$autoplay_status" == "yes" ] && echo "no" >"$AUTOPLAY_FILE" || echo "yes" >"$AUTOPLAY_FILE"
      continue
    elif [[ "$config_choice" == *"Toggle Video Output"* ]]; then
      [ "$video_mode_status" == "video" ] && echo "audio" >"$VIDEO_MODE_FILE" || echo "video" >"$VIDEO_MODE_FILE"
      continue
    elif [[ "$config_choice" == *"Edit Liked Videos"* ]]; then
      open_in_nvim "$LIKED_HIST"
      continue
    elif [[ "$config_choice" == *"Edit Saved YouTube Mixes"* ]]; then
      open_in_nvim "$PLAYLIST_HIST"
      continue
    elif [[ "$config_choice" == *"Edit Manual Playlist"* ]]; then
      if [ -z "$(ls -A "$MANUAL_PL_DIR" 2>/dev/null)" ]; then
        notify-send "Playlist Error" "No manual playlists exist!" -i notification-message-im
        continue
      fi

      edit_targets=$(basename -a "$MANUAL_PL_DIR"/* | sed 's/\.txt//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      selected_index=$(echo -e "$edit_targets" | "${ROFI_NAV[@]}" -format i -p "Select Edit Target" -theme-str 'entry { placeholder: "Select manual playlist file to pass to nvim..."; }')
      if [ $? -ne 10 ] && [ -n "$selected_index" ]; then
        target_edit=$(basename -a "$MANUAL_PL_DIR"/* | sed -n "$((selected_index + 1))p")
        open_in_nvim "$MANUAL_PL_DIR/$target_edit"
      fi
      continue
    fi
  fi

  # ----------------------------------------------------------------------------
  # Unified Text File Actions Step
  # ----------------------------------------------------------------------------
  if [ -n "$active_file" ]; then
    while true; do
      if [ ! -s "$active_file" ]; then
        notify-send "Vault Empty" "This tracking file is currently empty!" -i notification-message-im
        continue 2
      fi

      file_titles=$(cat "$active_file" | sed 's/ ➔ .*//' | sed 's/【/[/g; s/】/]/g; s/ //g; s/^[[:space:]]*//;s/[[:space:]]*$//')
      selected_index=$(echo -e "$file_titles" | "${ROFI_NAV[@]}" -format i -p "Entries" -theme-str "entry { placeholder: \"$placeholder\"; }")
      if [ $? -eq 10 ] || [ -z "$selected_index" ]; then continue 2; fi

      selected_video=$(cat "$active_file" | sed -n "$((selected_index + 1))p")

      if [ "$is_liked" = true ]; then
        options="Play Selected Playlist Here\nPlay Playlist in Reverse\nPlay Playlist Shuffled\nPlay Next (Single Track)\nAppend Single to Queue\nPin / Unpin Item\nRemove From List\nMove Line Up\nMove Line Down\nCopy to Manual Playlist\nDownload Video"
      else
        options="Play in New Window\nPlay Next (Queue)\nAppend to Queue\nReplace Active Session\nRemove From History\nSave to Liked Videos\nAdd to Manual Playlist\nDownload Video"
      fi

      choice=$(echo -e "$options" | "${ROFI_NAV[@]}" -p "Actions" -theme-str 'entry { placeholder: "Choose execution step..."; }')
      if [ $? -eq 10 ] || [ -z "$choice" ]; then continue; fi

      url=$(echo "$selected_video" | sed 's/.* ➔ //')
      title_part=$(echo "$selected_video" | sed 's/ ➔ .*//' | sed 's/^\[PIN\] //')

      if [[ "$choice" == *"Pin / Unpin Item"* ]]; then
        if [[ "$selected_video" == "\[PIN\] "* ]]; then new_line=$(echo "$selected_video" | sed 's/^\[PIN\] //'); else new_line="[PIN] $selected_video"; fi
        awk -v old="$selected_video" -v new="$new_line" '{if ($0 == old) print new; else print}' "$active_file" >"$HISTORY_DIR/tmp" && mv "$HISTORY_DIR/tmp" "$active_file"
        (
          grep '^\[PIN\]' "$active_file"
          grep -v '^\[PIN\]' "$active_file"
        ) >"$HISTORY_DIR/tmp_sort" && mv "$HISTORY_DIR/tmp_sort" "$active_file"
        continue
      elif [[ "$choice" == *"Remove From"* ]]; then
        grep -v -F "$selected_video" "$active_file" >"$HISTORY_DIR/tmp" && mv "$HISTORY_DIR/tmp" "$active_file"
        continue
      elif [[ "$choice" == *"Move Line Up"* || "$choice" == *"Move Line Down"* ]]; then
        line_num=$(grep -n -F "$selected_video" "$active_file" | head -n1 | cut -d: -f1)
        total_lines=$(wc -l <"$active_file")
        if [[ "$choice" == *"Move Line Up"* && $line_num -gt 1 ]]; then
          l1=$((line_num - 1)) l2=$line_num
          awk -v l1="$l1" -v l2="$l2" 'NR==l1 {line1=$0; next} NR==l2 {print $0; print line1; next} {print}' "$active_file" >"$HISTORY_DIR/tmp" && mv "$HISTORY_DIR/tmp" "$active_file"
        elif [[ "$choice" == *"Move Line Down"* && $line_num -lt $total_lines ]]; then
          l1=$line_num l2=$((line_num + 1))
          awk -v l1="$l1" -v l2="$l2" 'NR==l1 {line1=$0; next} NR==l2 {print $0; print line1; next} {print}' "$active_file" >"$HISTORY_DIR/tmp" && mv "$HISTORY_DIR/tmp" "$active_file"
        fi
        continue
      elif [[ "$choice" == *"Save to Liked"* ]]; then
        log_video_history "liked" "$url" "$title_part"
        notify-send "Liked Videos" "Saved track to favorites vault!" -i notification-audio-play
        continue
      elif [[ "$choice" == *"Manual Playlist"* ]]; then
        add_to_manual_playlist "$title_part" "$url"
        continue
      elif [[ "$choice" == *"Download Video"* ]]; then
        notify-send "Downloader" "Starting background download to ~/Downloads..." -i notification-audio-play
        yt-dlp --user-agent "$BROWSER_UA" --cookies "$COOKIE_PATH" -P "~/Downloads" "$url" &
        continue
      fi
      log_video_history "all" "$url" "$title_part" &
      break
    done
  fi

  # ----------------------------------------------------------------------------
  # Core MPV Socket Connection & Pipeline Execution Matrix
  # ----------------------------------------------------------------------------
  if [ -n "$url" ] && [ -n "$choice" ]; then
    sockets=()
    for sock in /tmp/mpvsocket-*; do
      [ -S "$sock" ] || continue
      kill -0 "${sock##*-}" 2>/dev/null && sockets+=("$sock") || rm -f "$sock"
    done

    mpv_video_flag=""
    [ "$(cat "$VIDEO_MODE_FILE")" == "audio" ] && mpv_video_flag="--no-video"

    MPV_UA_OPT="--user-agent=$BROWSER_UA"

    # FIXED: Re-mapped options array into sequential append flags to resolve syntax splitting issues
    MPV_COOKIES="--ytdl-raw-options=yes-playlist= --ytdl-raw-options-append=cookies=$COOKIE_PATH --ytdl-raw-options-append=mark-watched="

    if [ ${#sockets[@]} -eq 0 ] && [[ "$choice" == *"Append"* || "$choice" == *"Play Next"* || "$choice" == *"Replace"* ]]; then
      notify-send "YouTube Error" "No active session found! Opening separately." -i notification-message-im
      setsid env WAYLAND_DISPLAY="$WAYLAND_DISPLAY" DISPLAY="$DISPLAY" mpv --input-ipc-server="/tmp/mpvsocket-$$" "$MPV_UA_OPT" $MPV_COOKIES $mpv_video_flag "$url" >/dev/null 2>&1 &
      exit 0
    elif [ ${#sockets[@]} -eq 1 ]; then
      target_socket="${sockets[0]}"
    elif [ ${#sockets[@]} -gt 1 ]; then
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

    autoplay_flag="youtube_upnext-auto_add=yes"
    [ "$(cat "$AUTOPLAY_FILE")" == "no" ] && autoplay_flag="youtube_upnext-auto_add=no"

    case "$choice" in
    *"Play Selected Playlist Here"*)
      line_num=$(grep -n -F "$selected_video" "$active_file" | head -n1 | cut -d: -f1)
      compile_m3u "$active_file" "/tmp/rofi_mpv_playlist.m3u"
      setsid env WAYLAND_DISPLAY="$WAYLAND_DISPLAY" DISPLAY="$DISPLAY" mpv --input-ipc-server="/tmp/mpvsocket-$$" "$MPV_UA_OPT" $MPV_COOKIES $mpv_video_flag --script-opts="$autoplay_flag" --playlist-start=$((line_num - 1)) "/tmp/rofi_mpv_playlist.m3u" >/dev/null 2>&1 &
      notify-send "Playlist Player" "Loading local playlist..." -i notification-audio-play
      ;;
    *"Play Playlist in Reverse"*)
      line_num=$(grep -n -F "$selected_video" "$active_file" | head -n1 | cut -d: -f1)
      total_lines=$(wc -l <"$active_file")
      tac "$active_file" >"/tmp/rofi_reversed.txt"
      compile_m3u "/tmp/rofi_reversed.txt" "/tmp/rofi_mpv_playlist.m3u"
      setsid env WAYLAND_DISPLAY="$WAYLAND_DISPLAY" DISPLAY="$DISPLAY" mpv --input-ipc-server="/tmp/mpvsocket-$$" "$MPV_UA_OPT" $MPV_COOKIES $mpv_video_flag --script-opts="$autoplay_flag" --playlist-start=$((total_lines - line_num)) "/tmp/rofi_mpv_playlist.m3u" >/dev/null 2>&1 &
      notify-send "Playlist Player" "Loading reversed local playlist..." -i notification-audio-play
      ;;
    *"Play Playlist Shuffled"*)
      compile_m3u "$active_file" "/tmp/rofi_mpv_playlist.m3u"
      setsid env WAYLAND_DISPLAY="$WAYLAND_DISPLAY" DISPLAY="$DISPLAY" mpv --input-ipc-server="/tmp/mpvsocket-$$" "$MPV_UA_OPT" $MPV_COOKIES $mpv_video_flag --script-opts="$autoplay_flag" --shuffle "/tmp/rofi_mpv_playlist.m3u" >/dev/null 2>&1 &
      notify-send "Playlist Player" "Loading randomized local playlist..." -i notification-audio-play
      ;;
    *"Play in New Window"*)
      setsid env WAYLAND_DISPLAY="$WAYLAND_DISPLAY" DISPLAY="$DISPLAY" mpv --input-ipc-server="/tmp/mpvsocket-$$" "$MPV_UA_OPT" $MPV_COOKIES $mpv_video_flag "$url" >/dev/null 2>&1 &
      notify-send "YouTube Player" "Opening track window instance" -i notification-audio-play
      ;;
    *"Append to Queue"*)
      echo '{"command": ["loadfile", "'"$url"'", "append"]}' | socat - UNIX-CONNECT:"$target_socket"
      notify-send "YouTube Queue" "Appended to end of stream!" -i notification-audio-play
      ;;
    *"Play Next"*)
      if [ -S "$target_socket" ]; then
        echo '{"command": ["loadfile", "'"$url"'", "append-play"]}' | socat - UNIX-CONNECT:"$target_socket"
        notify-send "YouTube Queue" "Inserted track to play next!" -i notification-audio-play
      else
        setsid env WAYLAND_DISPLAY="$WAYLAND_DISPLAY" DISPLAY="$DISPLAY" mpv --input-ipc-server="/tmp/mpvsocket-$$" "$MPV_UA_OPT" $MPV_COOKIES $mpv_video_flag "$url" >/dev/null 2>&1 &
        notify-send "YouTube Queue" "Queue empty. Initializing playback engine!" -i notification-audio-play
      fi
      ;;
    *"Replace Active Session"*)
      [ -n "$target_socket" ] && echo '{"command": ["quit"]}' | socat - UNIX-CONNECT:"$target_socket" 2>/dev/null
      sleep 0.5
      setsid env WAYLAND_DISPLAY="$WAYLAND_DISPLAY" DISPLAY="$DISPLAY" mpv --input-ipc-server="/tmp/mpvsocket-$$" "$MPV_UA_OPT" $MPV_COOKIES $mpv_video_flag "$url" >/dev/null 2>&1 &
      notify-send "YouTube Player" "Session reset and track loaded!" -i notification-audio-play
      ;;
    esac
  fi
done
