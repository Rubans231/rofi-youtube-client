Rofi YouTube Client

A lightweight, terminal-centric media workflow designed for Arch Linux. This client leverages Rofi for asset navigation and menu selection, driving mpv and yt-dlp in the background to handle asynchronous streaming, active playback tracking, and automated profile logging.
🗺️ Table of Contents

    Key Features

    Repository Architecture

    Installation & Deployment

    Core Execution Flow

    IPC Engine & Status Bar Sync

    Configuration Manifest

🚀 Key Features

    Asynchronous IPC Gateway: Implements a space-agnostic socat JSON-IPC parser to query active media instances and smoothly hot-swap or queue live network streams.

    Waybar-Aligned Process Tracking: Eliminates detached subshell race deadlocks by mapping uniform, predictable runtime states to your desktop status panel without track-ghosting.

    Globalized Profile Hooking: Uses centralized backend configurations to reliably sync your YouTube viewing state and mark videos as watched on your personal account feed.

    Modular Automation: Segregates entry points, playlist managers, search modules, and cache paths into dedicated modular segments.

⬆️ Back to Top
📁 Repository Architecture

Click any file or directory link below to jump directly to its deployment context:

    RofiYoutube/ — Core script modules handling interface loops and selection parsing.

        RofiYoutube/core.sh — The master control dispatch loop, lock daemon, and command router.

    config/ — Tracked configuration files mirrored directly to user system runtime trees.

        config/yt-dlp/config — Centralized authentication file handling User-Agents, paths, and history switches.

        config/mpv/ — Houses input maps (input.conf) and engine rules (mpv.conf).

    install.sh — System setup script for symlinking configurations and verifying dependency packages.

    README.md — Project documentation manifest.

⬆️ Back to Top
🛠️ Installation & Deployment
1. Prerequisites

Ensure your package manager has the following core runtime utilities installed:
Bash

sudo pacman -S rofi mpv yt-dlp socat libnotify

2. Mirroring the Environment

Deploy the system configurations by executing the included installation automated helper:
Bash

git clone https://github.com/yourusername/rofi-youtube-client.git
cd rofi-youtube-client
chmod +x install.sh
./install.sh

Ensure your current browser session tokens are cleanly exported to your system environment vault path:
Plaintext

~/.config/yt-dlp/youtube-cookies.txt

⬆️ Back to Top
⚙️ Core Execution Flow
RofiYoutube
core.sh

The principal launcher loop. It handles the atomic concurrency lock engine to prevent execution spam, exposes history vaults (Liked, Searched, and Shuffled streams), and builds transient local .m3u playlists.

When a media action is selected, it evaluates active video display flags and structures your playback streams using single-line process trees:
Bash

env WAYLAND_DISPLAY="$WAYLAND_DISPLAY" DISPLAY="$DISPLAY" \
mpv --input-ipc-server="/tmp/mpvsocket-$instance_id" "$MPV_UA_OPT" ...

⬆️ Back to Top
🔗 IPC Engine & Status Bar Sync

The client creates a lightweight tracking token for each player session inside /tmp/mpvsocket-*.

When appending or swapping tracks, title metadata is parsed smoothly using a space-agnostic extraction regex that targets the native media-title property without tripping null-string fallbacks:
Bash

title=$(echo '{"command": ["get_property", "media-title"]}' | socat -t 0.3 - UNIX-CONNECT:"$sock" 2>/dev/null | head -n 1 | sed -n 's/.*"data"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

This strict single-line process mapping ensures that Waybar panels can trace window life cycles cleanly and drop references immediately upon session termination.

⬆️ Back to Top
📝 Configuration Manifest
config
yt-dlp-config

To guarantee robust session management across network threads, all tracking parameters are isolated globally within config/yt-dlp/config:
Plaintext

# Native Authentication & Profile Ledger Configuration
--cookies /home/robin/.config/yt-dlp/youtube-cookies.txt
--user-agent "Mozilla/5.0 (X11; Linux x86_64; rv:152.0) Gecko/20100101 Firefox/152.0"
--mark-watched

mpv-config

Maintains hardware decoding settings and native window layout profiles optimized for fast terminal integration.

⬆️ Back to Top
