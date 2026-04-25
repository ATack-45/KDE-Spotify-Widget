import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // ── Config shortcuts ────────────────────────────────────────────────────
    readonly property string clientId:     Plasmoid.configuration.clientId
    readonly property string clientSecret: Plasmoid.configuration.clientSecret
    readonly property string refreshToken: Plasmoid.configuration.refreshToken

    // ── OAuth state ─────────────────────────────────────────────────────────
    property string accessToken:    ""
    property int    tokenExpiresAt: 0   // epoch seconds

    // ── Currently-playing state ─────────────────────────────────────────────
    property string trackName:   "Not playing"
    property string artistName:  ""
    property string albumArtUrl: ""
    property int    progressMs:  0
    property int    durationMs:  1
    property bool   isPlaying:   false

    // ── Playlist state ──────────────────────────────────────────────────────
    property var playlists:            []   // [{id, name}, ...]
    property int selectedPlaylistIndex: -1

    // ── Helpers ─────────────────────────────────────────────────────────────
    function nowSeconds() {
        return Math.floor(Date.now() / 1000)
    }

    function tokenIsValid() {
        return accessToken !== "" && nowSeconds() < tokenExpiresAt - 30
    }

    function formatTime(ms) {
        var s = Math.floor(ms / 1000)
        return Math.floor(s / 60) + ":" + ("0" + (s % 60)).slice(-2)
    }

    // ── Token management ────────────────────────────────────────────────────
    function refreshAccessToken(callback) {
        if (!clientId || !clientSecret || !refreshToken) {
            console.warn("Spotify Widget: credentials not configured")
            return
        }
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "https://accounts.spotify.com/api/token")
        xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded")
        xhr.setRequestHeader("Authorization", "Basic " + Qt.btoa(clientId + ":" + clientSecret))
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200) {
                var data = JSON.parse(xhr.responseText)
                accessToken    = data.access_token
                tokenExpiresAt = nowSeconds() + data.expires_in
                if (callback) callback()
            } else {
                console.error("Spotify Widget: token refresh failed", xhr.status, xhr.responseText)
            }
        }
        xhr.send(
            "grant_type=refresh_token" +
            "&refresh_token=" + encodeURIComponent(refreshToken)
        )
    }

    // Ensures a valid token then invokes callback()
    function withToken(callback) {
        if (tokenIsValid()) {
            callback()
        } else {
            refreshAccessToken(callback)
        }
    }

    // ── Spotify API ──────────────────────────────────────────────────────────
    function fetchCurrentlyPlaying() {
        withToken(function() {
            var xhr = new XMLHttpRequest()
            xhr.open("GET", "https://api.spotify.com/v1/me/player/currently-playing")
            xhr.setRequestHeader("Authorization", "Bearer " + accessToken)
            xhr.onreadystatechange = function() {
                if (xhr.readyState !== XMLHttpRequest.DONE) return
                if (xhr.status === 200) {
                    var data = JSON.parse(xhr.responseText)
                    if (data && data.item) {
                        trackName  = data.item.name
                        artistName = data.item.artists.map(function(a) { return a.name }).join(", ")
                        progressMs = data.progress_ms || 0
                        durationMs = data.item.duration_ms || 1
                        isPlaying  = data.is_playing
                        var imgs = data.item.album && data.item.album.images
                        if (imgs && imgs.length > 0) {
                            // Prefer medium image (~300px) when available
                            albumArtUrl = imgs[imgs.length > 1 ? 1 : 0].url
                        }
                    }
                } else if (xhr.status === 204) {
                    // Nothing currently playing
                    trackName   = "Not playing"
                    artistName  = ""
                    isPlaying   = false
                    albumArtUrl = ""
                } else if (xhr.status === 401) {
                    // Token expired mid-poll — clear so next cycle forces refresh
                    accessToken = ""
                }
            }
            xhr.send()
        })
    }

    function sendPlaybackCommand(method, endpoint, body) {
        withToken(function() {
            var xhr = new XMLHttpRequest()
            xhr.open(method, "https://api.spotify.com/v1/me/player/" + endpoint)
            xhr.setRequestHeader("Authorization", "Bearer " + accessToken)
            if (body !== null) {
                xhr.setRequestHeader("Content-Type", "application/json")
                xhr.send(JSON.stringify(body))
            } else {
                xhr.send()
            }
            // Refresh state after a short delay to reflect new playback
            refreshDelay.restart()
        })
    }

    function fetchPlaylists() {
        withToken(function() {
            var xhr = new XMLHttpRequest()
            xhr.open("GET", "https://api.spotify.com/v1/me/playlists?limit=50")
            xhr.setRequestHeader("Authorization", "Bearer " + accessToken)
            xhr.onreadystatechange = function() {
                if (xhr.readyState !== XMLHttpRequest.DONE) return
                if (xhr.status === 200) {
                    var data = JSON.parse(xhr.responseText)
                    var list = []
                    for (var i = 0; i < data.items.length; i++) {
                        list.push({ id: data.items[i].id, name: data.items[i].name })
                    }
                    playlists = list
                }
            }
            xhr.send()
        })
    }

    function playPlaylist(playlistId) {
        sendPlaybackCommand("PUT", "play", { context_uri: "spotify:playlist:" + playlistId })
    }

    // ── Timers ───────────────────────────────────────────────────────────────

    // Poll currently-playing every 2 seconds
    Timer {
        id: pollTimer
        interval: 2000
        running:  root.refreshToken !== ""
        repeat:   true
        triggeredOnStart: true
        onTriggered: root.fetchCurrentlyPlaying()
    }

    // Smooth progress tick between polls
    Timer {
        interval: 1000
        running:  root.isPlaying
        repeat:   true
        onTriggered: {
            if (root.progressMs + 1000 <= root.durationMs) {
                root.progressMs += 1000
            }
        }
    }

    // Short delay after a playback command before refreshing state
    Timer {
        id: refreshDelay
        interval: 600
        repeat:   false
        onTriggered: root.fetchCurrentlyPlaying()
    }

    // ── Compact representation (panel) ───────────────────────────────────────
    compactRepresentation: RowLayout {
        spacing: 4

        Kirigami.Icon {
            source: root.isPlaying ? "media-playback-start" : "media-playback-pause"
            width:  Kirigami.Units.iconSizes.small
            height: Kirigami.Units.iconSizes.small
        }
        QQC2.Label {
            text: root.trackName
            elide: Text.ElideRight
            Layout.maximumWidth: 160
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
        }
    }

    // ── Full / desktop representation ────────────────────────────────────────
    fullRepresentation: ColumnLayout {
        id: fullView

        width:   300
        spacing: Kirigami.Units.smallSpacing

        // -- Unconfigured notice --
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type:    Kirigami.MessageType.Warning
            visible: root.refreshToken === ""
            text:    "Right-click → Configure to add your Spotify credentials."
        }

        // -- Album art --
        Item {
            Layout.alignment: Qt.AlignHCenter
            width:  280
            height: 280

            Image {
                id: albumArt
                anchors.fill: parent
                source:       root.albumArtUrl
                fillMode:     Image.PreserveAspectFit
                visible:      root.albumArtUrl !== ""
            }

            // Placeholder when no album art
            Rectangle {
                anchors.fill: parent
                color:        Kirigami.Theme.alternateBackgroundColor
                radius:       8
                visible:      root.albumArtUrl === ""

                Kirigami.Icon {
                    source: "media-optical-audio"
                    anchors.centerIn: parent
                    width:  80
                    height: 80
                    opacity: 0.4
                }
            }
        }

        // -- Track name --
        QQC2.Label {
            text:                root.trackName
            font.bold:           true
            wrapMode:            Text.WordWrap
            Layout.fillWidth:    true
            horizontalAlignment: Text.AlignHCenter
            elide:               Text.ElideRight
            maximumLineCount:    2
        }

        // -- Artist name --
        QQC2.Label {
            text:                root.artistName
            opacity:             0.7
            Layout.fillWidth:    true
            horizontalAlignment: Text.AlignHCenter
            elide:               Text.ElideRight
        }

        // -- Progress bar + timestamps --
        QQC2.ProgressBar {
            from:             0
            to:               root.durationMs
            value:            root.progressMs
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true

            QQC2.Label {
                text:      root.formatTime(root.progressMs)
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.75
            }
            Item { Layout.fillWidth: true }
            QQC2.Label {
                text:      root.formatTime(root.durationMs)
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.75
            }
        }

        // -- Playback controls --
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing:          Kirigami.Units.largeSpacing

            QQC2.ToolButton {
                icon.name: "media-skip-backward"
                onClicked: root.sendPlaybackCommand("POST", "previous", null)
            }

            QQC2.ToolButton {
                icon.name: root.isPlaying ? "media-playback-pause"
                                          : "media-playback-start"
                onClicked: {
                    if (root.isPlaying) {
                        root.sendPlaybackCommand("PUT", "pause", null)
                    } else {
                        root.sendPlaybackCommand("PUT", "play", null)
                    }
                }
            }

            QQC2.ToolButton {
                icon.name: "media-skip-forward"
                onClicked: root.sendPlaybackCommand("POST", "next", null)
            }
        }

        // -- Divider --
        Kirigami.Separator { Layout.fillWidth: true }

        // -- Playlist selector --
        RowLayout {
            Layout.fillWidth: true

            QQC2.Label {
                text:      "Playlist:"
                font.bold: true
            }

            QQC2.ComboBox {
                id:          playlistCombo
                Layout.fillWidth: true
                model:       root.playlists.map(function(p) { return p.name })
                enabled:     root.playlists.length > 0
                displayText: root.playlists.length > 0
                             ? playlistCombo.currentText
                             : "Loading..."
                onActivated: function(index) {
                    root.selectedPlaylistIndex = index
                    root.playPlaylist(root.playlists[index].id)
                }
            }

            QQC2.ToolButton {
                icon.name: "view-refresh"
                ToolTip.text: "Refresh playlists"
                ToolTip.visible: hovered
                onClicked: root.fetchPlaylists()
            }
        }

        Item { height: Kirigami.Units.smallSpacing }
    }

    // Initial setup: fetch token + playlists once credentials are available
    Component.onCompleted: {
        if (root.refreshToken !== "") {
            root.withToken(function() {
                root.fetchPlaylists()
            })
        }
    }

    // Re-initialize when credentials change in config
    Connections {
        target: Plasmoid.configuration
        function onRefreshTokenChanged() {
            if (root.refreshToken !== "") {
                root.accessToken = ""
                root.withToken(function() {
                    root.fetchPlaylists()
                })
            }
        }
    }
}
