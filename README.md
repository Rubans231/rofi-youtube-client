# Rofi YouTube Client

https://github.com/user-attachments/assets/6231e20c-d633-4123-ab68-c7c05f1face3

A lightweight, terminal-centric media workflow designed for Arch Linux. It combines Rofi, mpv, and yt-dlp to provide a seamless asynchronous streaming, active playback tracking, and automated profile logging experience.

## Features

* **Terminal-Centric UI:** Navigate assets and manage sessions seamlessly using `rofi`.
* **Asynchronous Streaming:** Background video and audio playback powered by `mpv` and `yt-dlp`.
* **Core Architecture:**
  * **Launcher:** Rofi (Menu selection and asset navigation)
  * **Media Engine:** mpv (Hardware-accelerated playback)
  * **Backend:** yt-dlp (Stream resolution and authentication)
  * **IPC Gateway:** socat (Space-agnostic JSON-IPC active session parsing)
 
 ## Notice

- Use of yt-dlp can result in ban of account in certain cases, please proceed with a throwaway account if possible.
- Play next(Queue) option is bugged and currently does not work.

## Documentation

* **[Core Execution Flow](RofiYoutube/core.sh)**: Master control dispatch loop, lock daemon, and command router.
* **[yt-dlp Configuration](config/yt-dlp/config)**: Centralized authentication handling User-Agents, paths, and history switches.
* **[mpv Configuration](config/mpv/)**: Houses input maps (`input.conf`) and engine rules (`mpv.conf`).
* **[Installation Script](install.sh)**: System setup script for symlinking configurations.

## Quick Start (Manual Setup)

Best for Arch Linux environments with custom terminal configurations.

### 1. **Install Prerequisites**:

   ```bash
   sudo pacman -S rofi mpv yt-dlp socat libnotify
   ```

### 2. Clone & Setup:

    git clone https://github.com/Rubans231/rofi-youtube-client.git
    cd rofi-youtube-client
    chmod +x install.sh
    ./install.sh

### 3. Configure Authentication (Cookie Export)

To prevent YouTube from triggering anti-bot verification challenges and to also get recommendation benefits along with mark watched features, you must export a valid session cookie from your browser:

   - Install an open-source cookie extraction extension in your browser (e.g., Get cookies.txt LOCALLY for Chromium/Firefox).

   - Open your browser, navigate to YouTube, and ensure you are completely logged into your account.

   - Click the extension icon and download the cookies for youtube.com in the standard Netscape cookies format.

   - Rename the downloaded file to youtube-cookies.txt and move it to your configuration directory:

    mkdir -p ~/.config/yt-dlp
    mv ~/Downloads/youtube-cookies.txt ~/.config/yt-dlp/youtube-cookies.txt

### Use:

   Launch Menu: Bind your shortcut to ~/.config/hypr/UserScripts/RofiYoutube/core.sh

   Sockets: Active IPC tracking available at /tmp/mpvsocket-*

## AUR Package

(Coming Soon)

## Troubleshooting

- If you are being blocked, then it is most likely because of expired cookies (cookies from incognito tabs last longer)
- If Automix is not pulling up a long playlist then that is also most likely because of expired cookies
