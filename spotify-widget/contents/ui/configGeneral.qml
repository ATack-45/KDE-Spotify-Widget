import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: generalConfigPage

    // cfg_ properties are automatically synced with main.xml config keys
    property alias cfg_clientId:     clientIdField.text
    property alias cfg_clientSecret: clientSecretField.text
    property alias cfg_refreshToken: refreshTokenField.text

    spacing: Kirigami.Units.smallSpacing

    Kirigami.FormLayout {
        Layout.fillWidth: true

        QQC2.TextField {
            id: clientIdField
            Kirigami.FormData.label: "Client ID:"
            Layout.fillWidth: true
            placeholderText: "Paste your Spotify Client ID here"
        }

        QQC2.TextField {
            id: clientSecretField
            Kirigami.FormData.label: "Client Secret:"
            Layout.fillWidth: true
            placeholderText: "Paste your Spotify Client Secret here"
            echoMode: TextInput.Password
        }

        QQC2.TextField {
            id: refreshTokenField
            Kirigami.FormData.label: "Refresh Token:"
            Layout.fillWidth: true
            placeholderText: "Run setup_auth.py, then paste token here"
        }
    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        type: Kirigami.MessageType.Information
        visible: true
        text: "Run <b>python3 setup_auth.py</b> in a terminal to get your refresh token. " +
              "Make sure to add <b>http://localhost:8888/callback</b> as a Redirect URI " +
              "in your Spotify Developer Dashboard app settings first."
    }
}
