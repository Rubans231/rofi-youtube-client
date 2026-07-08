#!/usr/bin/env bash
# search.sh — Sub-module for query scraping, deep browsing, and unified video actions

# Hard-ensure matching paths within the subshell scope (Fully portable via $HOME)
SEARCHED_HIST="$HOME/.cache/RofiYoutube/searched_history.txt"
ALL_PLAYED_HIST="$HOME/.cache/RofiYoutube/all_played_history.txt"
PLAYLIST_HIST="$HOME/.cache/RofiYoutube/playlist_history.txt"

query=$("${ROFI_NAV[@]}" -p "YouTube Search" -theme-str 'entry { placeholder: "Type search query (Left Arrow goes Back)..."; }')
if [ $? -eq 10 ] || [ -z "$query" ]; then
  return
fi

# ==============================================================================
# MAIN SEARCH PAGINATION LOOP
# ==============================================================================
search_limit=30
while true; do
  notify-send "Search Engine" "Querying YouTube securely (Fetching $search_limit results)..." -i notification-audio-play

  raw_results=$(yt-dlp "ytsearch$search_limit:$query" \
    --user-agent "$BROWSER_UA" \
    --cookies "$COOKIE_PATH" \
    --flat-playlist \
    --print "%(title)s ➔ %(url)s" \
    --no-warnings 2>/dev/null | grep -E '(watch\?v=|/channel/|/c/|/@|playlist\?list=)')

  if [ -z "$raw_results" ]; then
    notify-send "Search Error" "YouTube rejected scraping or no valid items found." -i notification-message-im
    return
  fi

  # Prioritize channels to the absolute top of the menu list
  detected_channels=$(echo -e "$raw_results" | grep -E '(➔ .*\/channel\/|➔ .*\/@|➔ .*\/c\/)')
  detected_videos=$(echo -e "$raw_results" | grep -v -E '(➔ .*\/channel\/|➔ .*\/@|➔ .*\/c\/)')
  search_results=$(echo -e "${detected_channels}\n${detected_videos}" | grep -v '^$')

  first_video_url=$(echo -e "$search_results" | grep 'watch?v=' | head -n 1 | sed -n 's/.* ➔ \(http.*\)/\1/p')
  is_music=false

  if [ -n "$first_video_url" ]; then
    video_category=$(yt-dlp --user-agent "$BROWSER_UA" --cookies "$COOKIE_PATH" --print "%(categories)s" --no-warnings "$first_video_url" 2>/dev/null | head -n 1)
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
# UNIFIED ROUTER & BACK-TRACKING ENGINE
# ==============================================================================
orig_url=""
orig_title=""

while true; do
  if [[ "$url" == *"/channel/"* ]] || [[ "$url" == *"/@"* ]] || [[ "$url" == *"/c/"* ]]; then
    cat_options="🎥 Latest Uploads\n🩳 Shorts\n🔴 Live Streams\n📁 Playlists"
    category_choice=$(echo -e "$cat_options" | "${ROFI_NAV[@]}" -p "$title_extracted Tabs" -theme-str 'entry { placeholder: "Select channel tab category (Left Arrow goes Back)..."; }')

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
        --cookies "$COOKIE_PATH" \
        --flat-playlist \
        --playlist-end "$channel_limit" \
        --print "%(title)s ➔ %(url)s" \
        --no-warnings 2>/dev/null)

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

      selected_ch_index=$(echo -e "$channel_menu_data" | "${ROFI_NAV[@]}" -format i -p "$title_extracted" -theme-str 'entry { placeholder: "Select item to play (Left Arrow returns to tabs)..."; }')

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

      # FIXED: Changed from break 2 to a standard break. Exits the list view and drops directly into the action menu down below.
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
    channel_info=$(yt-dlp --print "%(uploader)s ➔ %(channel_url)s" --no-warnings "$url" 2>/dev/null | head -n 1)
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
    yt-dlp --user-agent "$BROWSER_UA" --cookies "$COOKIE_PATH" -P "$HOME/Downloads" "$url" &
    url=""
    return
  else
    break
  fi
done

# ==============================================================================
# HISTORICAL ENGINE TRACKING LOGSET
# ==============================================================================
if [ -n "$url" ]; then
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
