import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.Common
import qs.Modules.DankBar.Widgets
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

// Circular album-cover media pill. Shows the current track's artwork
// (MPRIS, including browser media sessions like music.163.com) with a live
// Cava spectrum along the lower arc while playing. Hovering the cover fades
// in a play/pause control. Hides entirely when no media player is active.
// Left click        -> play / pause (whole cover is the hit target)
// Right click       -> DankDash media tab
PluginComponent {
    id: root

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool playerAvailable: activePlayer !== null
    readonly property bool hoverPreview: MprisController.isFirefoxYoutubeHoverPreview(activePlayer)
    readonly property bool isPlaying: playerAvailable && activePlayer.playbackState === MprisPlaybackState.Playing && !hoverPreview

    // Resolved art (remote covers are downloaded to the image cache by
    // TrackArtService), falling back to the live MPRIS url.
    readonly property string rawArtUrl: {
        const p = activePlayer;
        if (!p)
            return "";
        if (p.trackArtUrl)
            return p.trackArtUrl;
        const m = p.metadata;
        return m && m["mpris:artUrl"] ? m["mpris:artUrl"].toString() : "";
    }
    readonly property string coverSource: TrackArtService.resolvedArtUrl || rawArtUrl

    // Hold the last successfully loaded cover so the art never blanks out
    // between tracks while the player is still active.
    property string lastValidArt: ""
    readonly property string displayedArt: {
        const src = root.coverSource;
        if (src !== "")
            return src;
        return root.playerAvailable ? root.lastValidArt : "";
    }

    readonly property int coverSize: Theme.barIconSize(barThickness, 8, barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)

    onDisplayedArtChanged: {
        if (displayedArt === "")
            lastValidArt = "";
    }

    function togglePlaying() {
        if (root.activePlayer)
            root.activePlayer.togglePlaying();
    }

    pillRightClickAction: () => Quickshell.execDetached(["dms", "ipc", "call", "dash", "toggle", "media"])

    component CoverArt: ClippingRectangle {
        id: coverRoot

        radius: width / 2
        color: Theme.primaryHover
        border.color: Theme.outlineMedium
        border.width: 1

        Image {
            id: art

            anchors.fill: parent
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            smooth: true
            mipmap: true
            sourceSize.width: Math.max(width * 2, 128)
            sourceSize.height: Math.max(height * 2, 128)
            visible: status === Image.Ready
            source: root.displayedArt
            onStatusChanged: {
                if (status === Image.Ready && source !== "")
                    root.lastValidArt = source;
            }
        }

        // Placeholder while no cover has loaded.
        DankIcon {
            name: "music_note"
            size: Math.round(coverRoot.width * 0.5)
            color: Theme.primary
            anchors.centerIn: parent
            visible: art.status !== Image.Ready
        }

        // Live Cava spectrum along the lower arc of the cover while playing.
        // A dark backdrop keeps the bars readable on light cover art.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(coverRoot.width * 0.06)
            width: Math.round(coverRoot.width * 0.74)
            height: Math.round(coverRoot.width * 0.34)
            radius: height / 2
            color: Qt.rgba(0, 0, 0, 0.40)
            visible: root.isPlaying && art.status === Image.Ready
        }

        AudioVisualization {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(coverRoot.width * 0.10)
            width: Math.round(coverRoot.width * 0.62)
            height: Math.round(coverRoot.width * 0.24)
            maxBarHeight: height
            barColor: "#ffffff"
            idleIconName: ""
            visible: root.isPlaying && art.status === Image.Ready
        }

        // Hover scrim + play/pause control (visual only; the MouseArea below
        // owns clicks and hover so the hit target is the whole cover).
        Rectangle {
            id: scrim

            anchors.fill: parent
            radius: width / 2
            color: Qt.rgba(0, 0, 0, 0.42)
            opacity: hoverArea.containsMouse && root.playerAvailable ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Rectangle {
                width: Math.round(coverRoot.width * 0.62)
                height: width
                radius: width / 2
                color: Qt.rgba(1, 1, 1, 0.18)
                border.color: Qt.rgba(1, 1, 1, 0.35)
                border.width: 1
                anchors.centerIn: parent

                DankIcon {
                    name: root.isPlaying ? "pause" : "play_arrow"
                    size: Math.round(parent.width * 0.58)
                    color: "#ffffff"
                    anchors.centerIn: parent
                }
            }
        }

        MouseArea {
            id: hoverArea

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            enabled: root.playerAvailable
            cursorShape: Qt.PointingHandCursor
            onClicked: root.togglePlaying()
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: root.playerAvailable ? root.coverSize : 0
            implicitHeight: root.playerAvailable ? root.coverSize : 0
            opacity: root.playerAvailable ? 1 : 0

            Behavior on implicitWidth {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Behavior on implicitHeight {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            CoverArt {
                width: root.coverSize
                height: root.coverSize
                anchors.centerIn: parent
                visible: root.playerAvailable
            }
        }
    }

    horizontalBarPill: Component {
        Item {
            implicitWidth: root.playerAvailable ? root.coverSize + Theme.spacingS + 120 : 0
            implicitHeight: root.playerAvailable ? root.coverSize : 0
            opacity: root.playerAvailable ? 1 : 0

            Behavior on implicitWidth {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingS
                visible: root.playerAvailable

                CoverArt {
                    width: root.coverSize
                    height: root.coverSize
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    width: 120

                    StyledText {
                        width: parent.width
                        text: root.activePlayer?.trackTitle || ""
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        color: Theme.widgetTextColor
                        elide: Text.ElideRight
                        visible: root.activePlayer?.trackTitle !== ""
                    }

                    StyledText {
                        width: parent.width
                        text: root.activePlayer?.trackArtist || ""
                        font.pixelSize: Theme.barTextSize(root.barThickness, (root.barConfig?.fontScale ?? 1) * 0.82, root.barConfig?.maximizeWidgetText)
                        color: Theme.widgetTextColor
                        opacity: 0.72
                        elide: Text.ElideRight
                        visible: root.activePlayer?.trackArtist !== ""
                    }
                }
            }
        }
    }
}
