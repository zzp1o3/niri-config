import QtQuick
import qs.Common
import qs.Widgets

// Circular ring gauge used by the performance monitor popout.
Item {
    id: root

    property real value: -1        // 0..100, negative = unavailable
    property color accent: Theme.primary
    property string label: ""
    property string detail: ""
    property real ringSize: 108

    readonly property color effColor: {
        if (root.value < 0)
            return Theme.surfaceVariantText;
        if (root.value >= 85)
            return Theme.tempDanger;
        if (root.value >= 60)
            return Theme.tempWarning;
        return root.accent;
    }

    width: ringSize
    height: ringSize + labels.implicitHeight + 8
    implicitWidth: width
    implicitHeight: height

    Canvas {
        id: ring
        width: root.ringSize
        height: root.ringSize
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const lw = 9;
            const r = width / 2 - lw / 2 - 1;
            const cx = width / 2;
            const cy = height / 2;
            ctx.lineWidth = lw;
            ctx.lineCap = "round";
            ctx.beginPath();
            ctx.arc(cx, cy, r, 0, Math.PI * 2);
            ctx.strokeStyle = Theme.withAlpha(Theme.surfaceText, 0.10).toString();
            ctx.stroke();
            if (root.value >= 0) {
                const frac = Math.max(0, Math.min(1, root.value / 100));
                if (frac > 0.003) {
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * frac);
                    ctx.strokeStyle = root.effColor.toString();
                    ctx.stroke();
                }
            }
        }
    }

    Connections {
        target: root
        function onValueChanged() {
            ring.requestPaint();
        }
        function onAccentChanged() {
            ring.requestPaint();
        }
    }

    StyledText {
        anchors.centerIn: ring
        text: root.value < 0 ? "--" : Math.round(root.value) + "%"
        font.pixelSize: Math.max(13, Math.round(root.ringSize * 0.24))
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    Column {
        id: labels
        anchors.top: ring.bottom
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 2

        StyledText {
            text: root.label
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.DemiBold
            color: Theme.surfaceText
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StyledText {
            text: root.detail
            visible: root.detail.length > 0
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
