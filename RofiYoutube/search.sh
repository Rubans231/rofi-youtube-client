#!/usr/bin/env bash
# search.sh — High-speed sub-module featuring FIFO History & Live Autocomplete with Native Ctrl+Return

# Hard-ensure matching paths within the subshell scope
SEARCHED_HIST="$HOME/.cache/RofiYoutube/searched_history.txt"
ALL_PLAYED_HIST="$HOME/.cache/RofiYoutube/all_played_history.txt"
PLAYLIST_HIST="$HOME/.cache/RofiYoutube/playlist_history.txt"

mkdir -p "$(dirname "$SEARCHED_HIST")"
touch "$SEARCHED_HIST"

# ==============================================================================
# PHASE 1: INTERACTIVE TYPING REFRESH LOOP (Native Ctrl+Return Behavior)
# ==============================================================================
query=""
while true; do
  # 1. Pull relevant rows from local 100-item FIFO history file
  local_matches=""
  if [ -n "$query" ] && [ -s "$SEARCHED_HIST" ]; then
    local_matches=$(grep -i "$query" "$SEARCHED_HIST" | head -n 3)
  elif [ -z "$query" ] && [ -s "$SEARCHED_HIST" ]; then
    local_matches=$(head -n 5 "$SEARCHED_HIST")
  fi

  # 2. Extract real-time auto-complete string arrays from the YouTube API
  api_suggestions=""
  if [ -n "$query" ]; then
    api_suggestions=$(curl -sG "https://suggestqueries.google.com/complete/search" \
      --data-urlencode "client=firefox" \
      --data-urlencode "ds=yt" \
      --data-urlencode "q=$query" 2>/dev/null |
      sed 's/\[[^,]*,\s*\[//; s/\].*//; s/"//g; s/,\s*/\n/g' | grep -v -E "^$|^$query$")
  fi

  # 3. Compile data entries cleanly into the list payload
  menu_payload=""
  [ -n "$local_matches" ] && menu_payload+="$local_matches\n"
  [ -n "$api_suggestions" ] && menu_payload+="$api_suggestions"

  # Pass current text to the filter parameter
  selection=$(echo -e "$menu_payload" | grep -v '^$' | "${ROFI_NAV[@]}" \
    -p "Search" \
    -filter "$query" \
    -theme-str 'entry { placeholder: "Type query... (Press Ctrl+Enter to search exact text immediately)"; }')

  exit_status=$?

  # 4. Strict Interception Gates
  if [ $exit_status -ne 0 ]; then
    # Catches ESC (1), Left Arrow Back (10), or any external termination signal -> abort instantly!
    return
  fi

  if [ -z "$selection" ]; then
    break # Fallback for Enter on an empty line
  elif [ "$selection" == "$query" ]; then
    # NATURALLY TRIGGERED BY CTRL+RETURN:
    # Forces Rofi to submit the raw input string exactly, matching this condition perfectly!
    break
  else
    # User selected an autocomplete item row, update state and loop back
    query="$selection"
    continue
  fi
done

final_logged_query="$query"

# ==============================================================================
# PHASE 2: MAIN HIGH-SPEED DATA SCRAPING PIPELINE (Android Client)
# ==============================================================================
search_limit=30
while true; do
  notify-send "Search Engine" "Querying YouTube securely..." -i notification-audio-play

  raw_results=$(yt-dlp "ytsearch$search_limit:$query" \
    --user-agent "$BROWSER_UA" \
    --flat-playlist \
    --print "%(title)s ➔ %(url)s" \
    --no-warnings \
    --cache-dir "$HOME/.cache/yt-dlp" \
    --extractor-args "youtube:search_sort=relevance;player_client=android,web_music" \
    --check-formats none \
    --skip-download \
    2>/dev/null | grep -E '(watch\?v=|/channel/|/c/|/@|playlist\?list=)')

  if [ -z "$raw_results" ]; then
    notify-send "Search Error" "YouTube rejected scraping or no valid items found." -i notification-message-im
    return
  fi

  detected_channels=$(echo -e "$raw_results" | grep -E '(➔ .*\/channel\/|➔ .*\/@|➔ .*\/c\/)')
  detected_videos=$(echo -e "$raw_results" | grep -v -E '(➔ .*\/channel\/|➔ .*\/@|➔ .*\/c\/)')
  search_results=$(echo -e "${detected_channels}\n${detected_videos}" | grep -v '^$')

  first_video_url=$(echo -e "$search_results" | grep 'watch?v=' | head -n 1 | sed -n 's/.* ➔ \(http.*\)/\1/p')
  is_music=false

  if [ -n "$first_video_url" ]; then
    video_category=$(yt-dlp --user-agent "$BROWSER_UA" --cache-dir "$HOME/.cache/yt-dlp" --check-formats none --skip-download --print "%(categories)s" --no-warnings "$first_video_url" 2>/dev/null | head -n 1)
    [[ "$video_category" == *"Music"* ]] && is_music=true
  fi

  if [ "$is_music" = true ]; then
    seed_video_id=$(echo "$first_video_url" | sed -n 's/.*v=\([A-Za-z0-9_-]\{11\}\).*/\1/p')
    recommendation_title="✨ [AUTOMIX] Discover ${query} Radio Station"
    recommendation_url="https://www.youtube.com/watch?v=${seed_video_id}&list=RD${seed_video_id}&start_radio=1"
    search_results="${recommendation_title} ➔ ${recommendation_url}\n${search_results}"
  fi

  rofi_titles=$(echo -e "$search_results" | sed 's/ ➔ .*//')
  total_items=$(echo -e "$search_results" | wc -l)

  if [ "$total_items" -ge "$search_limit" ]; then
    rofi_menu_data="${rofi_titles}\n🔍 Show more results..."
  else
    rofi_menu_data="$rofi_titles"
  fi

  selected_index=$(echo -e "$rofi_menu_data" | "${ROFI_NAV[@]}" -format i -p "Select Item" -theme-str 'entry { placeholder: "Select track, playlist, or channel..."; }')
  if [ $? -eq 10 ] || [ -z "$selected_index" ]; then
    return
  fi

  if [ "$selected_index" -eq "$total_items" ]; then
    search_limit=$((search_limit + 30))
    continue
  fi

  matched_line=$(echo -e "$search_results" | sed -n "$((selected_index + 1))p")
  url=$(echo "$matched_line" | sed 's/.* ➔ //')
  title_extracted=$(echo "$matched_line" | sed 's/ ➔ .*//')
  break
done

# ==============================================================================
# PHASE 3: UNIFIED ROUTER & BACK-TRACKING ENGINE
# ==============================================================================
orig_url=""
orig_title=""

while true; do
  if [[ "$url" == *"/channel/"* ]] || [[ "$url" == *"/@"* ]] || [[ "$url" == *"/c/"* ]]; then
    cat_options="🎥 Latest Uploads\n🩳 Shorts\n🔴 Live Streams\n📁 Playlists"
    category_choice=$(echo -e "$cat_options" | "${ROFI_NAV[@]}" -p "$title_extracted Tabs" -theme-str 'entry { placeholder: "Select channel tab category..."; }')

    if [ $? -eq 10 ] || [ -z "$category_choice" ]; then
      if [ -n "$orig_url" ]; then
        url="$orig_url"
        title_extracted="$orig_title"
        orig_url=""
        orig_title=""
        continue
      else
        return
      fi
    fi

    case "$category_choice" in
    *"Uploads"*) tab_suffix="/videos" ;;
    *"Shorts"*) tab_suffix="/shorts" ;;
    *"Live"*) tab_suffix="/live" ;;
    *"Playlists"*) tab_suffix="/playlists" ;;
    *) tab_suffix="/videos" ;;
    esac

    base_channel_url="${url%/}"
    target_browse_url="${base_channel_url}${tab_suffix}"

    channel_limit=20
    inner_back=false
    while true; do
      notify-send "Channel Browser" "Opening $category_choice feed..." -i notification-audio-play

      channel_raw=$(yt-dlp "$target_browse_url" \
        --user-agent "$BROWSER_UA" \
        --flat-playlist \
        --playlist-end "$channel_limit" \
        --print "%(title)s ➔ %(url)s" \
        --no-warnings \
        --cache-dir "$HOME/.cache/yt-dlp" \
        --check-formats none \
        --skip-download \
        2>/dev/null)

      if [ -z "$channel_raw" ]; then
        notify-send "Browser Error" "No items found inside the $category_choice tab directory." -i notification-message-im
        break
      fi

      channel_titles=$(echo -e "$channel_raw" | sed 's/ ➔ .*//')
      total_ch_items=$(echo -e "$channel_raw" | wc -l)

      if [ "$total_ch_items" -ge "$channel_limit" ]; then
        channel_menu_data="${channel_titles}\n🔍 Show more results..."
      else
        channel_menu_data="$channel_titles"
      fi

      selected_ch_index=$(echo -e "$channel_menu_data" | "${ROFI_NAV[@]}" -format i -p "$title_extracted" -theme-str 'entry { placeholder: "Select item to play..."; }')

      if [ $? -eq 10 ] || [ -z "$selected_ch_index" ]; then
        inner_back=true
        break
      fi

      if [ "$selected_ch_index" -eq "$total_ch_items" ]; then
        channel_limit=$((channel_limit + 20))
        continue
      fi

      matched_line=$(echo -e "$channel_raw" | sed -n "$((selected_ch_index + 1))p")
      url=$(echo "$matched_line" | sed 's/.* ➔ //')
      title_extracted=$(echo "$matched_line" | sed 's/ ➔ .*//')
      break
    done

    if [ "$inner_back" = true ]; then
      continue
    fi
  fi

  # --------------------------------------------------------------------------
  # ACTION ROUTER INTERFACE
  # --------------------------------------------------------------------------
  if [[ "$title_extracted" == *"[AUTOMIX]"* ]]; then
    options="Play Mix in New Window\nPlay Mix Next (Queue)\nAppend Mix to Queue\nReplace Active Session"
  else
    options="Play in New Window\nPlay Next (Queue)\nAppend to Queue\nReplace Active Session\nVisit Channel\nSave to Liked Videos\nAdd to Manual Playlist\nDownload Video"
  fi

  choice=$(echo -e "$options" | "${ROFI_NAV[@]}" -p "Video Action" -theme-str 'entry { placeholder: "Choose playback action..."; }')
  if [ $? -eq 10 ] || [ -z "$choice" ]; then
    url=""
    return
  fi

  if [[ "$choice" == *"Visit Channel"* ]]; then
    notify-send "Channel Browser" "Resolving channel profile link..." -i notification-audio-play
    channel_info=$(yt-dlp --cache-dir "$HOME/.cache/yt-dlp" --check-formats none --skip-download --print "%(uploader)s ➔ %(channel_url)s" --no-warnings "$url" 2>/dev/null | head -n 1)
    if [ -n "$channel_info" ]; then
      orig_url="$url"
      orig_title="$title_extracted"
      title_extracted=$(echo "$channel_info" | sed 's/ ➔ .*//')
      url=$(echo "$channel_info" | sed 's/.* ➔ //')
      continue
    else
      notify-send "Browser Error" "Could not resolve a channel endpoint for this video." -i notification-message-im
      continue
    fi
  fi

  if [[ "$choice" == *"Save to Liked Videos"* ]]; then
    log_video_history "liked" "$url" "$title_extracted"
    notify-send "Liked Videos" "Saved to favorites vault!" -i notification-audio-play
    url=""
    return
  elif [[ "$choice" == *"Add to Manual Playlist"* ]]; then
    add_to_manual_playlist "$title_extracted" "$url"
    url=""
    return
  elif [[ "$choice" == *"Download Video"* ]]; then
    notify-send "Downloader" "Starting background download to ~/Downloads..." -i notification-audio-play
    yt-dlp --user-agent "$BROWSER_UA" --cache-dir "$HOME/.cache/yt-dlp" -P "$HOME/Downloads" "$url" &
    url=""
    return
  else
    break
  fi
done

# ==============================================================================
# PHASE 4: HISTORICAL LOGGING & STRICT 100-ITEM FIFO TRUNCATION
# ==============================================================================
if [ -n "$url" ]; then
  tmp_searched=$(mktemp)
  grep -v -x -F "$final_logged_query" "$SEARCHED_HIST" >"$tmp_searched" 2>/dev/null
  echo "$final_logged_query" | cat - "$tmp_searched" | head -n 100 >"$SEARCHED_HIST"
  rm -f "$tmp_searched"

  if [[ "$title_extracted" == *"[AUTOMIX]"* ]]; then
    first_title=$(echo -e "$raw_results" | head -n 1 | sed 's/ ➔ .*//')
    log_video_history "search" "$first_video_url" "$first_title"
    log_video_history "all" "$first_video_url" "$first_title"

    clean_mix_title="${query} Automix Station"
    if ! grep -qF "$recommendation_url" "$PLAYLIST_HIST"; then
      echo "$clean_mix_title ➔ $recommendation_url" | cat - "$PLAYLIST_HIST" >"${PLAYLIST_HIST}.tmp" && mv "${PLAYLIST_HIST}.tmp" "$PLAYLIST_HIST"
    fi
  else
    log_video_history "search" "$url" "$title_extracted"
    log_video_history "all" "$url" "$title_extracted"
  fi
fi
