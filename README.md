# Rofi YouTube Client

A lightweight, terminal-centric media workflow designed for Arch Linux. It combines Rofi, mpv, and yt-dlp to provide a seamless asynchronous streaming, active playback tracking, and automated profile logging experience.

## Features

* **Terminal-Centric UI:** Navigate assets and manage sessions seamlessly using `rofi`.
* **Asynchronous Streaming:** Background video and audio playback powered by `mpv` and `yt-dlp`.
* **Core Architecture:**
  * **Launcher:** Rofi (Menu selection and asset navigation)
  * **Media Engine:** mpv (Hardware-accelerated playback)
  * **Backend:** yt-dlp (Stream resolution and authentication)
  * **IPC Gateway:** socat (Space-agnostic JSON-IPC active session parsing)

## Documentation

* **[Core Execution Flow](RofiYoutube/core.sh)**: Master control dispatch loop, lock daemon, and command router.
* **[yt-dlp Configuration](config/yt-dlp/config)**: Centralized authentication handling User-Agents, paths, and history switches.
* **[mpv Configuration](config/mpv/)**: Houses input maps (`input.conf`) and engine rules (`mpv.conf`).
* **[Installation Script](install.sh)**: System setup script for symlinking configurations.

## Quick Start (Manual Setup)

Best for Arch Linux environments with custom terminal configurations.

1. **Install Prerequisites**:

   ```bash
   sudo pacman -S rofi mpv yt-dlp socat libnotify
   ```

## Clone & Setup:

    ```bash
    git clone [https://github.com/yourusername/rofi-youtube-client.git](https://github.com/yourusername/rofi-youtube-client.git)
    cd rofi-youtube-client
    chmod +x install.sh
    ./install.sh

## Configure Authentication: Export your browser session tokens.
    
    ```bash
    # Place your exported YouTube cookies here:
    ~/.config/yt-dlp/youtube-cookies.txt

## Use:

    Launch Menu: Bind your shortcut to ~/.config/hypr/UserScripts/RofiYoutube/core.sh

    Sockets: Active IPC tracking available at /tmp/mpvsocket-*

Quick Start (AUR Package)

(Coming Soon)
