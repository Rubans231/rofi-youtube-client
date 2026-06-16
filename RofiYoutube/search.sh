#!/usr/bin/env bash
# search.sh — Sub-module for query scraping and category verification

query=$("${ROFI_NAV[@]}" -p "YouTube Search" -theme-str 'entry { placeholder: "Type search query (Left Arrow goes Back)..."; }')
[ $? -eq 10 ] || [ -z "$query" ] && return

notify-send "Search Engine" "Querying YouTube securely..." -i notification-audio-play

raw_results=$(yt-dlp "ytsearch20:$query" \
  --user-agent "$BROWSER_UA" \
  --cookies "$COOKIE_PATH" \
  --flat-playlist \
  --print "%(title)s ➔ %(url)s" \
  --no-warnings 2>/dev/null | grep -E '(watch\?v=[A-Za-z0-9_-]{11}$|/channel/UC[A-Za-z0-9_-]{22}$|playlist\?list=PL[A-Za-z0-9_-]{32}$)')

if [ -z "$raw_results" ]; then
  notify-send "Search Error" "YouTube rejected scraping or no valid items found." -i notification-message-im
  return
fi

first_video_url=$(echo -e "$raw_results" | grep 'watch?v=' | head -n 1 | sed -n 's/.* ➔ \(http.*\)/\1/p')
is_music=false

if [ -n "$first_video_url" ]; then
  video_category=$(yt-dlp --user-agent "$BROWSER_UA" --cookies "$COOKIE_PATH" --print "%(categories)s" --no-warnings "$first_video_url" 2>/dev/null | head -n 1)
  [[ "$video_category" == *"Music"* ]] && is_music=true
fi

if [ "$is_music" = true ]; then
  seed_video_id=$(echo "$first_video_url" | sed -n 's/.*v=\([A-Za-z0-9_-]\{11\}\).*/\1/p')
  recommendation_title="✨ [AUTOMIX] Discover ${query} Radio Station"
  recommendation_url="https://www.youtube.com/watch?v=${seed_video_id}&list=RD${seed_video_id}&start_radio=1"
  search_results="${recommendation_title} ➔ ${recommendation_url}\n${raw_results}"
else
  search_results="$raw_results"
fi

rofi_titles=$(echo -e "$search_results" | sed 's/ ➔ .*//' | sed 's/【/[/g; s/】/]/g; s/^[[:space:]]*//;s/[[:space:]]*$//')

selected_index=$(echo -e "$rofi_titles" | "${ROFI_NAV[@]}" -format i -p "Select Item" -theme-str 'entry { placeholder: "Select track or link (Left Arrow goes Back)..."; }')
[ $? -eq 10 ] || [ -z "$selected_index" ] && return

matched_line=$(echo -e "$search_results" | sed -n "$((selected_index + 1))p")
url=$(echo "$matched_line" | sed 's/.* ➔ //')
title_extracted=$(echo "$matched_line" | sed 's/ ➔ .*//' | sed 's/【/[/g; s/】/]/g; s/^[[:space:]]*//;s/[[:space:]]*$//')

if [[ "$title_extracted" == *"[AUTOMIX]"* ]]; then
  options="Play Mix in New Window\nPlay Mix Next (Queue)\nAppend Mix to Queue\nReplace Active Session"
else
  options="Play in New Window\nPlay Next (Queue)\nAppend to Queue\nReplace Active Session\nSave to Liked Videos\nAdd to Manual Playlist\nDownload Video"
fi

choice=$(echo -e "$options" | "${ROFI_NAV[@]}" -p "Video Action" -theme-str 'entry { placeholder: "Choose playback action..."; }')
[ $? -eq 10 ] || [ -z "$choice" ] && {
  url=""
  return
}

# Intercept database storage options immediately
if [[ "$choice" == *"Save to Liked Videos"* ]]; then
  log_video_history "liked" "$url" "$title_extracted"
  notify-send "Liked Videos" "Saved to favorites vault!" -i notification-audio-play
  url=""
elif [[ "$choice" == *"Add to Manual Playlist"* ]]; then
  add_to_manual_playlist "$title_extracted" "$url"
  url=""
elif [[ "$choice" == *"Download Video"* ]]; then
  notify-send "Downloader" "Starting background download to ~/Downloads..." -i notification-audio-play
  yt-dlp --user-agent "$BROWSER_UA" --cookies "$COOKIE_PATH" -P "~/Downloads" "$url" &
  url=""
fi

if [[ "$title_extracted" != *"[AUTOMIX]"* && -n "$url" ]]; then
  log_video_history "search" "$url" "$title_extracted" &
  log_video_history "all" "$url" "$title_extracted" &
fi
