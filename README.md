*Disclaimer: This repository has lots of AI generated code. part of this project is me expirimenting with usage of AI in software developmnet to learn its behavior, capabilities, and limitations so I can more effectively integrate AI into my development without loosing quality or understanding of the project*

# KDE Spotify Widget

A KDE Plasma 6 desktop widget that acts as a Spotify miniplayer — shows the currently playing track, album art, playback controls, and a playlist selector, without needing the Spotify desktop app open.

![Plasma 6](https://img.shields.io/badge/KDE_Plasma-6-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- Album art, track name, and artist display
- Play/Pause, Skip Next, Skip Previous controls
- Progress bar with timestamps (ticks smoothly between API polls)
- Playlist selector — load your playlists and play any of them instantly
- Auto token refresh — stays authenticated without any manual intervention

> **Note:** Playback control requires a **Spotify Premium** account.

---

## Prerequisites

- KDE Plasma 6
- Python 3 (stdlib only — no pip installs needed) for the one-time setup
- A [Spotify Developer app](https://developer.spotify.com/dashboard) (free to create)

---

## Setup

### Step 1 — Create a Spotify Developer App

1. Go to [developer.spotify.com/dashboard](https://developer.spotify.com/dashboard) and log in
2. Click **Create app**, give it any name, select **Web API**
3. In the app settings, add the following as a **Redirect URI**:
   ```
   http://localhost:8888/callback
   ```
4. Save and note your **Client ID** and **Client Secret**

### Step 2 — Get a Refresh Token

Run the one-time setup script from the repo root:

```bash
python3 setup_auth.py
```

It will:
1. Ask for your Client ID and Client Secret
2. Open a browser to the Spotify login/authorization page
3. Catch the callback automatically on localhost
4. Print your **Refresh Token**

Copy the printed refresh token — you'll paste it into the widget config.

### Step 3 — Install the Widget

```bash
kpackagetool6 --install spotify-widget/
```

To update an existing installation:

```bash
kpackagetool6 --upgrade spotify-widget/
```

Then restart Plasma if the widget doesn't appear immediately:

```bash
plasmashell --replace &
```

### Step 4 — Add and Configure the Widget

1. Right-click your desktop → **Add Widgets**
2. Search for **Spotify Widget** and drag it onto the desktop
3. Right-click the widget → **Configure Spotify Widget...**
4. In the **General** tab, fill in:
   - **Client ID** — from your Spotify Developer app
   - **Client Secret** — from your Spotify Developer app
   - **Refresh Token** — from `setup_auth.py`
5. Click **OK**

The widget will start showing your currently playing track within a couple of seconds.

---

## Usage

| Control | Action |
|---|---|
| ⏮ | Skip to previous track |
| ⏯ | Play / Pause |
| ⏭ | Skip to next track |
| Playlist dropdown | Select a playlist to play it immediately |
| 🔄 (refresh icon) | Reload your playlist list |

The widget polls Spotify every 2 seconds to keep the display up to date.

---

## Uninstall

```bash
kpackagetool6 --remove org.kde.plasma.spotifywidget
```

---

## File Structure

```
spotify-widget/
├── metadata.json                  # Plasma 6 package manifest
├── contents/
│   ├── config/
│   │   ├── main.xml               # KConfig schema (stores credentials)
│   │   └── config.qml             # Registers the settings page
│   └── ui/
│       ├── main.qml               # Widget UI and Spotify API logic
│       └── configGeneral.qml      # Credentials configuration dialog
setup_auth.py                      # One-time OAuth2 PKCE setup helper
```

---

## Troubleshooting

**Widget shows "Not playing" even though Spotify is running**
- Make sure Spotify is actively playing on a device (phone, browser, or desktop app)
- The Spotify API only reports playback when something is actively playing or paused mid-track

**Playback controls don't work**
- Spotify Premium is required for API playback control
- Check that your credentials are entered correctly in the widget config

**"Configure widget" warning appears**
- You haven't entered your credentials yet — right-click → Configure

**Token expires / widget stops updating**
- The widget handles token refresh automatically; if it stops, right-click → Configure and re-paste your refresh token, then click OK to reinitialize

**Playlists dropdown is empty**
- Click the 🔄 refresh button next to the dropdown to reload your playlists
