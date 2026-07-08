#!/usr/bin/env bash
# manager.sh — Handles playlist manipulation, log utilities, and file histories

# Internal execution flag for compiling local blocks without rendering nested loops
if [ "$1" == "--compile-only" ]; then
  echo "#EXTM3U" >"/tmp/rofi_mpv_playlist.m3u"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "#EXTINF:-1,$(echo "$line" | sed 's/ ➔ .*//' | sed 's/^\[PIN\] //')" >>"/tmp/rofi_mpv_playlist.m3u"
    echo "$line" | sed 's/.* ➔ //' >>"/tmp/rofi_mpv_playlist.m3u"
  done <"$active_file"
  return 0
fi

# Primary database sorting loops
if [ -n "$active_file" ]; then
  while true; do
    [ ! -s "$active_file" ] && {
      notify-send "Vault Empty" "This tracking file is empty!" -i notification-message-im
      return
    }

    file_titles=$(cat "$active_file" | sed 's/ ➔ .*//' | sed 's/【/[/g; s/】/]/g; s/^[[:space:]]*//;s/[[:space:]]*$//')
    selected_index=$(echo -e "$file_titles" | "${ROFI_NAV[@]}" -format i -p "Entries" -theme-str "entry { placeholder: \"$placeholder\"; }")
    [ $? -eq 10 ] || [ -z "$selected_index" ] && return

    selected_video=$(cat "$active_file" | sed -n "$((selected_index + 1))p")
    options=$([ "$is_liked" = true ] && echo -e "Play Selected Playlist Here\nPlay Playlist in Reverse\nPlay Playlist Shuffled\nPlay Next (Single Track)\nAppend Single to Queue\nPin / Unpin Item\nRemove From List\nMove Line Up\nMove Line Down\nCopy to Manual Playlist\nDownload Video" || echo -e "Play in New Window\nPlay Next (Queue)\nAppend to Queue\nReplace Active Session\nRemove From History\nSave to Liked Videos\nAdd to Manual Playlist\nDownload Video")

    choice=$(echo -e "$options" | "${ROFI_NAV[@]}" -p "Actions" -theme-str 'entry { placeholder: "Choose execution step..."; }')
    [ $? -eq 10 ] || [ -z "$choice" ] && continue

    url=$(echo "$selected_video" | sed 's/.* ➔ //')
    title_part=$(echo "$selected_video" | sed 's/ ➔ .*//' | sed 's/^\[PIN\] //')

    if [[ "$choice" == *"Pin / Unpin Item"* ]]; then
      [[ "$selected_video" == "\[PIN\] "* ]] && new_line=$(echo "$selected_video" | sed 's/^\[PIN\] //') || new_line="[PIN] $selected_video"
      awk -v old="$selected_video" -v new="$new_line" '{if ($0 == old) print new; else print}' "$active_file" >"$HISTORY_DIR/tmp" && mv "$HISTORY_DIR/tmp" "$active_file"
      (
        grep '^\[PIN\]' "$active_file"
        grep -v '^\[PIN\]' "$active_file"
      ) >"$HISTORY_DIR/tmp_sort" && mv "$HISTORY_DIR/tmp_sort" "$active_file"
    elif [[ "$choice" == *"Remove From"* ]]; then
      grep -v -F "$selected_video" "$active_file" >"$HISTORY_DIR/tmp" && mv "$HISTORY_DIR/tmp" "$active_file"
    elif [[ "$choice" == *"Move Line Up"* || "$choice" == *"Move Line Down"* ]]; then
      line_num=$(grep -n -F "$selected_video" "$active_file" | head -n1 | cut -d: -f1)
      total_lines=$(wc -l <"$active_file")
      if [[ "$choice" == *"Move Line Up"* && $line_num -gt 1 ]]; then
        awk -v l1="$((line_num - 1))" -v l2="$line_num" 'NR==l1 {l1_text=$0; next} NR==l2 {print $0; print l1_text; next} {print}' "$active_file" >"$HISTORY_DIR/tmp" && mv "$HISTORY_DIR/tmp" "$active_file"
      elif [[ "$choice" == *"Move Line Down"* && $line_num -lt $total_lines ]]; then
        awk -v l1="$line_num" -v l2="$((line_num + 1))" 'NR==l1 {l1_text=$0; next} NR==l2 {print $0; print l1_text; next} {print}' "$active_file" >"$HISTORY_DIR/tmp" && mv "$HISTORY_DIR/tmp" "$active_file"
      fi
    elif [[ "$choice" == *"Save to Liked"* ]]; then
      log_video_history "liked" "$url" "$title_part"
      notify-send "Liked Videos" "Saved track to favorites vault!" -i notification-audio-play
    elif [[ "$choice" == *"Manual Playlist"* || "$choice" == *"Copy to Manual"* ]]; then
      add_to_manual_playlist "$title_part" "$url"
    elif [[ "$choice" == *"Download Video"* ]]; then
      notify-send "Downloader" "Starting background download to ~/Downloads..." -i notification-audio-play
      yt-dlp --user-agent "$BROWSER_UA" --cookies "$COOKIE_PATH" -P "~/Downloads" "$url" &
    else
      [[ "$choice" != *"Play Playlist"* && "$choice" != *"Selected Playlist"* ]] && log_video_history "all" "$url" "$title_part" &
      return
    fi
  done
fi

# Navigation map layout logic for online mix tables
while true; do
  mix_options="Select Saved YouTube Mix\nPaste New YouTube Mix\nManual Playlists"
  mix_choice=$(echo -e "$mix_options" | "${ROFI_NAV[@]}" -p "Playlist Manager" -theme-str 'entry { placeholder: "Select playlist database option..."; }')
  [ $? -eq 10 ] || [ -z "$mix_choice" ] && return

  if [[ "$mix_choice" == *"Select Saved YouTube Mix"* ]]; then
    [ ! -s "$PLAYLIST_HIST" ] && {
      notify-send "YouTube Error" "No mix history found!" -i notification-message-im
      continue
    }
    mix_titles=$(cat "$PLAYLIST_HIST" | sed 's/ ➔ .*//' | sed 's/【/[/g; s/】/]/g; s/^[[:space:]]*//;s/[[:space:]]*$//')
    selected_index=$(echo -e "$mix_titles" | "${ROFI_NAV[@]}" -format i -p "YouTube Mixes" -theme-str 'entry { placeholder: "Select a saved online mix..."; }')
    [ $? -eq 10 ] || [ -z "$selected_index" ] && continue

    selected_line=$(cat "$PLAYLIST_HIST" | sed -n "$((selected_index + 1))p")
    options="Play in New Window\nPlay Playlist in Reverse\nPlay Playlist Shuffled\nPlay Next (Queue)\nAppend to Queue\nReplace Active Session\nPin / Unpin Playlist\nRemove Playlist\nMove Line Up\nMove Line Down"
    choice=$(echo -e "$options" | "${ROFI_NAV[@]}" -p "Playlist Action" -theme-str 'entry { placeholder: "Choose action for saved mix..."; }')
    [ $? -eq 10 ] || [ -z "$choice" ] && continue
    mix_url=$(echo "$selected_line" | sed 's/.* ➔ //')

    if [[ "$choice" == *"Pin / Unpin Playlist"* ]]; then
      [[ "$selected_line" == "\[PIN\] "* ]] && new_line=$(echo "$selected_line" | sed 's/^\[PIN\] //') || new_line="[PIN] $selected_line"
      awk -v old="$selected_line" -v new="$new_line" '{if ($0 == old) print new; else print}' "$PLAYLIST_HIST" >"$HISTORY_DIR/tmp" && mv "$HISTORY_DIR/tmp" "$PLAYLIST_HIST"
      (
        grep '^\[PIN\]' "$PLAYLIST_HIST"
        grep -v '^\[PIN\]' "$PLAYLIST_HIST"
      ) >"$HISTORY_DIR/tmp_sort" && mv "$HISTORY_DIR/tmp_sort" "$PLAYLIST_HIST"
    elif [[ "$choice" == *"Remove Playlist"* ]]; then
      grep -v -F "$selected_line" "$PLAYLIST_HIST" >"$HISTORY_DIR/tmp" && mv "$HISTORY_DIR/tmp" "$PLAYLIST_HIST"
    elif [[ "$choice" == *"Move Line Up"* || "$choice" == *"Move Line Down"* ]]; then
      line_num=$(grep -n -F "$selected_line" "$PLAYLIST_HIST" | head -n1 | cut -d: -f1)
      total_lines=$(wc -l <"$PLAYLIST_HIST")
      if [[ "$choice" == *"Move Line Up"* && $line_num -gt 1 ]]; then
        awk -v l1="$!((line_num - 1))" -v l2="$line_num" 'NR==l1 {l1_text=$0; next} NR==l2 {print $0; print l1_text; next} {print}' "$PLAYLIST_HIST" >"$HISTORY_DIR/tmp" && mv "$HISTORY_DIR/tmp" "$PLAYLIST_HIST"
      elif [[ "$choice" == *"Move Line Down"* && $line_num -lt $total_lines ]]; then
        awk -v l1="$line_num" -v l2="$((line_num + 1))" 'NR==l1 {l1_text=$0; next} NR==l2 {print $0; print l1_text; next} {print}' "$PLAYLIST_HIST" >"$HISTORY_DIR/tmp" && mv "$HISTORY_DIR/tmp" "$PLAYLIST_HIST"
      fi
    else
      url="$mix_url" && return
    fi
  elif [[ "$mix_choice" == *"Paste New YouTube Mix"* ]]; then
    clip=$(wl-paste 2>/dev/null)
    if [[ "$clip" =~ ^http ]]; then
      mix_selection=$(echo -e "Use Copied Link (${clip:0:30}...)\nEnter URL Manually" | "${ROFI_NAV[@]}" -p "Select Source" -theme-str 'entry { placeholder: "Choose link source entry point..."; }')
      [ $? -eq 10 ] || [ -z "$mix_selection" ] && continue
      [[ "$mix_selection" == *"Use Copied Link"* ]] && mix_url="$clip" || mix_url=$("${ROFI_NAV[@]}" -p "Paste Mix Link:" -theme-str 'entry { placeholder: "Paste raw mix URL here..."; }')
    else
      mix_url=$("${ROFI_NAV[@]}" -p "Paste Mix Link:" -theme-str 'entry { placeholder: "Paste raw mix URL here..."; }')
    fi
    [ $? -eq 10 ] || [ -z "$mix_url" ] && continue
    playlist_name=$("${ROFI_NAV[@]}" -p "Name Mix" -theme-str 'entry { placeholder: "Assign a custom name for reference..."; }')
    [ $? -eq 10 ] || [ -z "$playlist_name" ] && continue
    echo "$playlist_name ➔ $mix_url" | cat - "$PLAYLIST_HIST" >"$HISTORY_DIR/tmp_hist" && mv "$HISTORY_DIR/tmp_hist" "$PLAYLIST_HIST"
    (
      grep '^\[PIN\]' "$PLAYLIST_HIST"
      grep -v '^\[PIN\]' "$PLAYLIST_HIST"
    ) >"$HISTORY_DIR/tmp_sort" && mv "$HISTORY_DIR/tmp_sort" "$PLAYLIST_HIST"
    url="$mix_url" && choice="Play in New Window" && return
  elif [[ "$mix_choice" == *"Manual Playlists"* ]]; then
    while true; do
      manual_options="View / Play Playlist\nCreate New Playlist\nDelete Playlist"
      manual_choice=$(echo -e "$manual_options" | "${ROFI_NAV[@]}" -p "Playlists Manager" -theme-str 'entry { placeholder: "Manage manual custom playlists..."; }')
      [ $? -eq 10 ] || [ -z "$manual_choice" ] && break

      if [[ "$manual_choice" == *"Create New Playlist"* ]]; then
        new_pl=$("${ROFI_NAV[@]}" -p "New Playlist Name" -theme-str 'entry { placeholder: "Type name for new custom playlist..."; }')
        [ $? -ne 10 ] && [ -n "$new_pl" ] && {
          touch "$MANUAL_PL_DIR/$new_pl.txt"
          notify-send "Manual Playlist" "Created empty playlist: $new_pl" -i notification-audio-play
        }
      elif [[ "$manual_choice" == *"Delete Playlist"* ]]; then
        [ -z "$(ls -A "$MANUAL_PL_DIR" 2>/dev/null)" ] && {
          notify-send "Playlist Error" "No manual playlists exist!" -i notification-message-im
          continue
        }
        pl_names=$(basename -a "$MANUAL_PL_DIR"/* | sed 's/\.txt//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        selected_index=$(echo -e "$pl_names" | "${ROFI_NAV[@]}" -format i -p "Delete Playlist" -theme-str 'entry { placeholder: "Select manual playlist to permanently destroy..."; }')
        if [ $? -ne 10 ] && [ -n "$selected_index" ]; then
          target_del=$(basename -a "$MANUAL_PL_DIR"/* | sed -n "$((selected_index + 1))p")
          rm -f "$MANUAL_PL_DIR/$target_del"
          notify-send "Manual Playlist" "Deleted playlist: ${target_del%.txt}" -i notification-message-im
        fi
      elif [[ "$manual_choice" == *"View / Play Playlist"* ]]; then
        [ -z "$(ls -A "$MANUAL_PL_DIR" 2>/dev/null)" ] && {
          notify-send "Playlist Error" "No manual playlists exist!" -i notification-message-im
          continue
        }
        pl_targets=$(basename -a "$MANUAL_PL_DIR"/* | sed 's/\.txt//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        selected_index=$(echo -e "$pl_targets" | "${ROFI_NAV[@]}" -format i -p "Open Playlist" -theme-str 'entry { placeholder: "Select manual playlist to load..."; }')
        [ $? -eq 10 ] || [ -z "$selected_index" ] && continue
        target_file=$(basename -a "$MANUAL_PL_DIR"/* | sed -n "$((selected_index + 1))p")
        export active_file="$MANUAL_PL_DIR/$target_file" placeholder="Custom Playlist: ${target_file%.txt}..." is_liked=true
        break 2
      fi
    done
  fi
done
