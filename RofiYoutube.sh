#!/usr/bin/env bash

# Storage layout targets
HISTORY_DIR="$HOME/.cache/ytfzf"
PLAYLIST_HIST="$HISTORY_DIR/playlist_history.txt"
SEARCHED_HIST="$HISTORY_DIR/searched_history.txt"
ALL_PLAYED_HIST="$HISTORY_DIR/all_played_history.txt"
LIKED_HIST="$HISTORY_DIR/liked_history.txt"
MANUAL_PL_DIR="$HISTORY_DIR/manual_playlists"
AUTOPLAY_FILE="$HISTORY_DIR/autoplay_toggle.txt"

mkdir -p "$HISTORY_DIR" "$MANUAL_PL_DIR"
touch "$PLAYLIST_HIST" "$SEARCHED_HIST" "$ALL_PLAYED_HIST" "$LIKED_HIST"
[ -f "$AUTOPLAY_FILE" ] || echo "yes" >"$AUTOPLAY_FILE"

# Core Navigation Array: Disables default char-stepping to map Left and Right arrows globally
ROFI_NAV=(rofi -dmenu -no-show-icons -kb-move-char-back "" -kb-move-char-forward "" -kb-custom-1 Left -kb-custom-2 Right)

# ==============================================================================
# Helper Engines: M3U Compiler, Asynchronous Logger, & Terminal Spawner
# ==============================================================================
compile_m3u() {
  local src_file="$1" local out_m3u="$2"
  echo "#EXTM3U" >"$out_m3u"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "#EXTINF:-1,$(echo "$line" | sed 's/ ➔ .*//' | sed 's/^📌 //')" >>"$out_m3u"
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
    video_title=$(yt-dlp --print "%(title)s" --no-warnings "$video_url" 2>/dev/null | head -n 1)
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
  local pl_choice
  pl_choice=$(basename -a "$MANUAL_PL_DIR"/* | sed 's/\.txt//' | "${ROFI_NAV[@]}" -p "📂 Choose Playlist" -theme-str 'entry { placeholder: "Select target manual playlist..."; }')
  [ $? -eq 10 ] || [ -z "$pl_choice" ] && return 1
  echo "$v_title ➔ $v_url" >>"$MANUAL_PL_DIR/$pl_choice.txt"
  notify-send "Playlist Manager" "Added track to: $pl_choice" -i notification-audio-play
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
  # Clear transient routing paths at the top of each loop state reset
  active_file=""
  placeholder=""
  is_liked=false
  url=""
  choice=""
  selected_video=""

  main_options="󰎕 Search YouTube\n🎵 Playlist & Mix Manager\n📜 Video History Vault\n⚙️ Playlist Config"
  main_choice=$(echo -e "$main_options" | "${ROFI_NAV[@]}" -p "󰚗 YouTube Menu" -theme-str 'entry { placeholder: "󰚗 Choose YouTube Mode..."; }')
  if [ $? -eq 10 ] || [ -z "$main_choice" ]; then exit 0; fi

  # ----------------------------------------------------------------------------
  # PATH A: Standard YouTube Search
  # ----------------------------------------------------------------------------
  if [[ "$main_choice" == *"Search YouTube"* ]]; then
    query=$("${ROFI_NAV[@]}" -p "󰎕 YouTube Search" -theme-str 'entry { placeholder: "󰎕 Type search query (Left Arrow goes Back)..."; }')
    if [ $? -eq 10 ] || [ -z "$query" ]; then continue; fi

    url=$(YTFZF_EXTMENU="rofi -dmenu -i -no-show-icons -kb-move-char-back '' -kb-move-char-forward '' -kb-custom-1 Left -kb-custom-2 Right -theme-str 'entry { placeholder: \"󱎕 Select video track...\"; }'" ytfzf -D -L "$query")
    if [ -z "$url" ]; then continue; fi

    options="󰐊 Play in New Window\n⏭️ Play Next (Queue)\n󰎕 Append to Queue\n󰓦 Replace Active Session\n❤️ Save to Liked Videos\n📂 Add to Manual Playlist\n📥 Download Video"
    choice=$(echo -e "$options" | "${ROFI_NAV[@]}" -p "󰚗 Video Action" -theme-str 'entry { placeholder: "󰚗 Choose playback action..."; }')
    if [ $? -eq 10 ] || [ -z "$choice" ]; then continue; fi

    title_extracted=$(yt-dlp --print "%(title)s" --no-warnings "$url" 2>/dev/null | head -n 1)
    [ -z "$title_extracted" ] && title_extracted="Video Track (${url##*=})"

    if [[ "$choice" == *"Save to Liked Videos"* ]]; then
      log_video_history "liked" "$url" "$title_extracted"
      notify-send "Liked Videos" "Saved to favorites vault!" -i notification-audio-play
      continue
    elif [[ "$choice" == *"Add to Manual Playlist"* ]]; then
      add_to_manual_playlist "$title_extracted" "$url"
      continue
    elif [[ "$choice" == *"Download Video"* ]]; then
      notify-send "Downloader" "Starting background download to ~/Downloads..." -i notification-audio-play
      yt-dlp -P "~/Downloads" "$url" &
      continue
    fi
    log_video_history "search" "$url" "$title_extracted" &
    log_video_history "all" "$url" "$title_extracted" &

  # ----------------------------------------------------------------------------
  # PATH B: Playlist & Mix Manager (Nesting Fix Implemented)
  # ----------------------------------------------------------------------------
  elif [[ "$main_choice" == *"Playlist & Mix Manager"* ]]; then
    while true; do
      # Ergonomic, beautifully organized parent level interface layer
      mix_options="📋 Select Saved YouTube Mix\n➕ Paste New YouTube Mix\n📂 Manual Playlists"
      mix_choice=$(echo -e "$mix_options" | "${ROFI_NAV[@]}" -p "🎵 Playlist Manager" -theme-str 'entry { placeholder: "🎵 Select playlist database option..."; }')
      if [ $? -eq 10 ] || [ -z "$mix_choice" ]; then break; fi

      if [[ "$mix_choice" == *"Select Saved YouTube Mix"* ]]; then
        if [ ! -s "$PLAYLIST_HIST" ]; then
          notify-send "YouTube Error" "No mix history found!" -i notification-message-im
          continue
        fi
        selected_line=$(cat "$PLAYLIST_HIST" | "${ROFI_NAV[@]}" -p "📋 YouTube Mixes" -theme-str 'entry { placeholder: "📋 Select a saved online mix..."; }')
        if [ $? -eq 10 ] || [ -z "$selected_line" ]; then continue; fi
        options="󰐊 Play in New Window\n🔄 Play in Reverse\n🔀 Play Shuffled\n⏭️ Play Next (Queue)\n󰎕 Append to Queue\n󰓦 Replace Active Session\n📌 Pin / Unpin Playlist\n❌ Remove Playlist\n🔼 Move Line Up\n🔽 Move Line Down"
        choice=$(echo -e "$options" | "${ROFI_NAV[@]}" -p "󰚗 Playlist Action" -theme-str 'entry { placeholder: "󰚗 Choose action for saved mix..."; }')
        if [ $? -eq 10 ] || [ -z "$choice" ]; then continue; fi
        mix_url=$(echo "$selected_line" | sed 's/.* ➔ //')
        if [[ "$choice" == *"Pin / Unpin Playlist"* ]]; then
          if [[ "$selected_line" == 📌* ]]; then new_line=$(echo "$selected_line" | sed 's/^📌 //'); else new_line="📌 $selected_line"; fi
          awk -v old="$selected_line" -v new="$new_line" '{if ($0 == old) print new; else print}' "$PLAYLIST_HIST" >"$HISTORY_DIR/tmp" && mv "$HISTORY_DIR/tmp" "$PLAYLIST_HIST"
          (
            grep '^📌' "$PLAYLIST_HIST"
            grep -v '^📌' "$PLAYLIST_HIST"
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
          mix_selection=$(echo -e "📋 Use Copied Link (${clip:0:30}...)\n⌨️ Enter URL Manually" | "${ROFI_NAV[@]}" -p "🔗 Select Source" -theme-str 'entry { placeholder: "🔗 Choose link source entry point..."; }')
          if [ $? -eq 10 ] || [ -z "$mix_selection" ]; then continue; fi
          [[ "$mix_selection" == *"Use Copied Link"* ]] && mix_url="$clip" || mix_url=$("${ROFI_NAV[@]}" -p "⌨️ Paste Mix Link:" -theme-str 'entry { placeholder: "⌨️ Paste raw mix URL here..."; }')
        else mix_url=$("${ROFI_NAV[@]}" -p "⌨️ Paste Mix Link:" -theme-str 'entry { placeholder: "⌨️ Paste raw mix URL here..."; }'); fi
        if [ $? -eq 10 ] || [ -z "$mix_url" ]; then continue; fi
        playlist_name=$("${ROFI_NAV[@]}" -p "󰚗 Name Mix" -theme-str 'entry { placeholder: "󰚗 Assign a custom name for reference..."; }')
        if [ $? -eq 10 ] || [ -z "$playlist_name" ]; then continue; fi
        echo "$playlist_name ➔ $mix_url" | cat - "$PLAYLIST_HIST" >"$HISTORY_DIR/tmp_hist" && mv "$HISTORY_DIR/tmp_hist" "$PLAYLIST_HIST"
        (
          grep '^📌' "$PLAYLIST_HIST"
          grep -v '^📌' "$PLAYLIST_HIST"
        ) >"$HISTORY_DIR/tmp_sort" && mv "$HISTORY_DIR/tmp_sort" "$PLAYLIST_HIST"
        url="$mix_url"
        break

      # NEW: Clean nested sub-menu layer that completely matches your intent
      elif [[ "$mix_choice" == *"Manual Playlists"* ]]; then
        while true; do
          manual_options="📁 View / Play Playlist\n🆕 Create New Playlist\n❌ Delete Playlist"
          manual_choice=$(echo -e "$manual_options" | "${ROFI_NAV[@]}" -p "📂 Playlists Manager" -theme-str 'entry { placeholder: "📂 Manage manual custom playlists..."; }')
          if [ $? -eq 10 ] || [ -z "$manual_choice" ]; then break; fi # Pops smoothly back to mix loop level

          if [[ "$manual_choice" == *"Create New Playlist"* ]]; then
            new_pl=$("${ROFI_NAV[@]}" -p "🆕 New Playlist Name" -theme-str 'entry { placeholder: "Type name for new custom playlist..."; }')
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
            del_pl=$(basename -a "$MANUAL_PL_DIR"/* | sed 's/\.txt//' | "${ROFI_NAV[@]}" -p "❌ Delete Playlist" -theme-str 'entry { placeholder: "Select manual playlist to permanently destroy..."; }')
            if [ $? -ne 10 ] && [ -n "$del_pl" ]; then
              rm -f "$MANUAL_PL_DIR/$del_pl.txt"
              notify-send "Manual Playlist" "Deleted playlist: $del_pl" -i notification-message-im
            fi
            continue
          elif [[ "$manual_choice" == *"View / Play Playlist"* ]]; then
            if [ -z "$(ls -A "$MANUAL_PL_DIR" 2>/dev/null)" ]; then
              notify-send "Playlist Error" "No manual playlists exist!" -i notification-message-im
              continue
            fi
            pl_target=$(basename -a "$MANUAL_PL_DIR"/* | sed 's/\.txt//' | "${ROFI_NAV[@]}" -p "📁 Open Playlist" -theme-str 'entry { placeholder: "Select manual playlist to load..."; }')
            if [ $? -eq 10 ] || [ -z "$pl_target" ]; then continue; fi
            active_file="$MANUAL_PL_DIR/$pl_target.txt"
            placeholder="📁 Custom Playlist: $pl_target..."
            is_liked=true
            break 2 # Escapes out to the global text processor block
          fi
        done
      fi
    done

  # ----------------------------------------------------------------------------
  # PATH C: Video History Vault
  # ----------------------------------------------------------------------------
  elif [[ "$main_choice" == *"Video History Vault"* ]]; then
    vault_choice=$(echo -e "❤️ Liked Videos Vault\n🔍 Manually Searched History\n📱 All Played Video History" | "${ROFI_NAV[@]}" -p "📜 History Vault" -theme-str 'entry { placeholder: "📜 Select history log segment..."; }')
    if [ $? -eq 10 ] || [ -z "$vault_choice" ]; then continue; fi
    if [[ "$vault_choice" == *"Liked Videos"* ]]; then
      active_file="$LIKED_HIST"
      placeholder="❤️ Filter liked videos vault..."
      is_liked=true
    elif [[ "$vault_choice" == *"Manually Searched"* ]]; then
      active_file="$SEARCHED_HIST"
      placeholder="🔍 Filter manual searches..."
      is_liked=false
    else
      active_file="$ALL_PLAYED_HIST"
      placeholder="📱 Filter complete video history..."
      is_liked=false
    fi

  # ----------------------------------------------------------------------------
  # PATH D: Playlist Config & Neovim Editor Core
  # ----------------------------------------------------------------------------
  elif [[ "$main_choice" == *"Playlist Config"* ]]; then
    autoplay_status=$(cat "$AUTOPLAY_FILE")
    config_options="🔄 Toggle Autoplay (Current: ${autoplay_status^^})\n❤️ Edit Liked Videos Vault\n📋 Edit Saved YouTube Mixes\n📂 Edit Manual Playlist"
    config_choice=$(echo -e "$config_options" | "${ROFI_NAV[@]}" -p "⚙️ Configuration" -theme-str 'entry { placeholder: "⚙️ Select configuration file or option..."; }')
    if [ $? -eq 10 ] || [ -z "$config_choice" ]; then continue; fi

    if [[ "$config_choice" == *"Toggle Autoplay"* ]]; then
      [ "$autoplay_status" == "yes" ] && echo "no" >"$AUTOPLAY_FILE" || echo "yes" >"$AUTOPLAY_FILE"
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
      edit_pl=$(basename -a "$MANUAL_PL_DIR"/* | sed 's/\.txt//' | "${ROFI_NAV[@]}" -p "📂 Select Edit Target" -theme-str 'entry { placeholder: "Select manual playlist file to pass to nvim..."; }')
      [ $? -ne 10 ] && [ -n "$edit_pl" ] && open_in_nvim "$MANUAL_PL_DIR/$edit_pl.txt"
      continue
    fi
  fi

  # ----------------------------------------------------------------------------
  # Unified Text File Actions Step (Triggers seamlessly if active_file is loaded)
  # ----------------------------------------------------------------------------
  if [ -n "$active_file" ]; then
    while true; do
      if [ ! -s "$active_file" ]; then
        notify-send "Vault Empty" "This tracking file is currently empty!" -i notification-message-im
        continue 2
      fi
      selected_video=$(cat "$active_file" | "${ROFI_NAV[@]}" -p "📜 Entries" -theme-str "entry { placeholder: \"$placeholder\"; }")
      if [ $? -eq 10 ] || [ -z "$selected_video" ]; then continue 2; fi

      if [ "$is_liked" = true ]; then
        options="󰐊 Play Selected Playlist Here\n🔄 Play Playlist in Reverse\n🔀 Play Playlist Shuffled\n⏭️ Play Next (Single Track)\n󰎕 Append Single to Queue\n📌 Pin / Unpin Item\n❌ Remove From List\n🔼 Move Line Up\n🔽 Move Line Down\n📂 Copy to Manual Playlist\n📥 Download Video"
      else
        options="󰐊 Play in New Window\n⏭️ Play Next (Queue)\n󰎕 Append to Queue\n󰓦 Replace Active Session\n❌ Remove From History\n❤️ Save to Liked Videos\n📂 Add to Manual Playlist\n📥 Download Video"
      fi

      choice=$(echo -e "$options" | "${ROFI_NAV[@]}" -p "󰚗 Actions" -theme-str 'entry { placeholder: "󰚗 Choose execution step..."; }')
      if [ $? -eq 10 ] || [ -z "$choice" ]; then continue; fi

      url=$(echo "$selected_video" | sed 's/.* ➔ //')
      title_part=$(echo "$selected_video" | sed 's/ ➔ .*//' | sed 's/^📌 //')

      if [[ "$choice" == *"Pin / Unpin Item"* ]]; then
        if [[ "$selected_video" == 📌* ]]; then new_line=$(echo "$selected_video" | sed 's/^📌 //'); else new_line="📌 $selected_video"; fi
        awk -v old="$selected_video" -v new="$new_line" '{if ($0 == old) print new; else print}' "$active_file" >"$HISTORY_DIR/tmp" && mv "$HISTORY_DIR/tmp" "$active_file"
        (
          grep '^📌' "$active_file"
          grep -v '^📌' "$active_file"
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
        yt-dlp -P "~/Downloads" "$url" &
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

    if [ ${#sockets[@]} -eq 0 ] && [[ "$choice" == *"Append"* || "$choice" == *"Play Next"* || "$choice" == *"Replace"* ]]; then
      notify-send "YouTube Error" "No active session found! Opening separately." -i notification-message-im
      mpv "$url" &
      exit 0
    elif [ ${#sockets[@]} -eq 1 ]; then
      target_socket="${sockets[0]}"
    elif [ ${#sockets[@]} -gt 1 ]; then
      rofi_input=""
      declare -A title_to_socket
      for sock in "${sockets[@]}"; do
        title=$(echo '{ "command": ["get_property_string", "media-title"] }' | socat - "$sock" 2>/dev/null | sed -n 's/.*"data":"\(.*\)","error".*/\1/p')
        [ -z "$title" ] && title="Idle Player Instance"
        display_line="󰎕 $title (PID: ${sock##*-})"
        rofi_input+="$display_line\n"
        title_to_socket["$display_line"]="$sock"
      done
      selected_display=$(echo -e "${rofi_input%\\n}" | "${ROFI_NAV[@]}" -p "󰚗 Target Session" -theme-str 'entry { placeholder: "󰚗 Select active session instance..."; }')
      if [ $? -eq 10 ] || [ -z "$selected_display" ]; then continue; fi
      target_socket="${title_to_socket[$selected_display]}"
    fi

    autoplay_flag="youtube_upnext-auto_add=yes"
    [ "$(cat "$AUTOPLAY_FILE")" == "no" ] && autoplay_flag="youtube_upnext-auto_add=no"

    case "$choice" in
    *"Play Selected Playlist Here"*)
      line_num=$(grep -n -F "$selected_video" "$active_file" | head -n1 | cut -d: -f1)
      compile_m3u "$active_file" "/tmp/rofi_mpv_playlist.m3u"
      mpv --script-opts="$autoplay_flag" --playlist-start=$((line_num - 1)) "/tmp/rofi_mpv_playlist.m3u" &
      notify-send "Playlist Player" "Loading local block playlist..." -i notification-audio-play
      ;;
    *"Play Playlist in Reverse"*)
      line_num=$(grep -n -F "$selected_video" "$active_file" | head -n1 | cut -d: -f1)
      total_lines=$(wc -l <"$active_file")
      tac "$active_file" >"/tmp/rofi_reversed.txt"
      compile_m3u "/tmp/rofi_reversed.txt" "/tmp/rofi_mpv_playlist.m3u"
      mpv --script-opts="$autoplay_flag" --playlist-start=$((total_lines - line_num)) "/tmp/rofi_mpv_playlist.m3u" &
      notify-send "Playlist Player" "Loading reversed local playlist..." -i notification-audio-play
      ;;
    *"Play Playlist Shuffled"*)
      compile_m3u "$active_file" "/tmp/rofi_mpv_playlist.m3u"
      mpv --script-opts="$autoplay_flag" --shuffle "/tmp/rofi_mpv_playlist.m3u" &
      notify-send "Playlist Player" "Loading randomized local playlist..." -i notification-audio-play
      ;;
    *"Play in New Window"*)
      mpv "$url" &
      notify-send "YouTube Player" "Opening track in a new window" -i notification-audio-play
      ;;
    *"Append to Queue"*)
      echo '{ "command": ["loadfile", "'"$url"'", "append"] }' | socat - "$target_socket"
      notify-send "YouTube Queue" "Appended to end of stream!" -i notification-audio-play
      ;;
    *"Play Next"*)
      current_pos=$(echo '{ "command": ["get_property", "playlist-pos"] }' | socat - "$target_socket" 2>/dev/null | sed -n 's/.*"data":\([0-9]\+\).*/\1/p')
      [ -z "$current_pos" ] && current_pos=0
      echo '{ "command": ["playlist-insert", '$((current_pos + 1))', "'"$url"'"] }' | socat - "$target_socket"
      notify-send "YouTube Queue" "Inserted track to play next!" -i notification-audio-play
      ;;
    *"Replace Active Session"*)
      echo '{ "command": ["loadfile", "'"$url"'", "replace"] }' | socat - "$target_socket"
      notify-send "YouTube Player" "Loaded into active session!" -i notification-audio-play
      ;;
    esac
  fi
done
