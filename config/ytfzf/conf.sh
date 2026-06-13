# Keep the external handler interface enabled
interface="ext"

# Force case-insensitivity in Rofi
external_menu() {
  rofi -dmenu -i -p "YouTube"
}

# FIXED ARGUMENTS: Clean handshake parameters passing strictly your Zen profile cookies path
url_handler_opts="--video-aspect-override=no --ytdl-raw-options=cookies=/home/robin/.config/yt-dlp/youtube-cookies.txt"
