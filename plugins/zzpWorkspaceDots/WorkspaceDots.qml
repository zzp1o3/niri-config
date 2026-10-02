import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

// macOS-style workspace dots for the bar. One dot per workspace on this
// screen: the active one is enlarged and filled with the primary color,
// occupied workspaces are solid, empty ones are dim. Click a dot to switch,
// scroll the pill to move through workspaces.
PluginComponent {
    id: root

    // 2026-10-02：显式 visible 绑定，保证 DMS 的部件"隐藏/显示"（WidgetHost 里 restoreMode
    // 为 RestoreBinding 的 Binding）在恢复时回到本绑定 → 隐藏后再显示能正常回到栏上。
    // （effectiveVisible 恒为 true：这些插件未配置 visibilityCommand）
    visible: root.effectiveVisible

    readonly property string screenName: parentScreen?.name ?? ""

    // Workspaces of this screen sorted by index; re-evaluates on every
    // NiriService workspaces/windows change.
    readonly property var workspaces: {
        const all = NiriService.allWorkspaces || [];
        const mine = all.filter(ws => ws.output === root.screenName);
        mine.sort((a, b) => (a.idx ?? 0) - (b.idx ?? 0));
        return mine;
    }

    readonly property int activeIndex: {
        const list = root.workspaces;
        for (let i = 0; i < list.length; i++)
            if (list[i].is_active)
                return i;
        return -1;
    }

    function isOccupied(ws) {
        return (NiriService.windows || []).some(win => win.workspace_id === ws.id);
    }

    function switchBy(offset) {
        const list = root.workspaces;
        const target = list[root.activeIndex + offset];
        if (target)
            NiriService.switchToWorkspace(target.id);
    }

    readonly property int dotSize: 9
    readonly property int activeDotSize: 12
    readonly property int dotGap: 6

    verticalBarPill: Component {
        Item {
            implicitWidth: root.workspaces.length > 0 ? Math.max(root.activeDotSize, root.dotSize) : 0
            implicitHeight: root.workspaces.length > 0
                            ? root.workspaces.length * root.dotSize + (root.workspaces.length - 1) * root.dotGap
                            : 0
            opacity: root.workspaces.length > 0 ? 1 : 0

            Behavior on implicitHeight {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Column {
                spacing: root.dotGap
                anchors.centerIn: parent

                Repeater {
                    model: root.workspaces

                    Rectangle {
                        id: dot

                        required property var modelData
                        required property int index

                        readonly property bool isActive: root.activeIndex === index
                        readonly property bool occupied: root.isOccupied(modelData)

                        width: isActive ? root.activeDotSize : root.dotSize
                        height: width
                        radius: width / 2
                        color: isActive ? Theme.primary
                                        : (occupied ? Theme.withAlpha(Theme.widgetTextColor, 0.55)
                                                    : Theme.withAlpha(Theme.widgetTextColor, 0.22))
                        anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            acceptedButtons: Qt.LeftButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NiriService.switchToWorkspace(dot.modelData.id)
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                acceptedButtons: Qt.NoButton
                cursorShape: Qt.PointingHandCursor

                onWheel: wheel => {
                    if (wheel.angleDelta.y > 0)
                        root.switchBy(-1);
                    else if (wheel.angleDelta.y < 0)
                        root.switchBy(1);
                    wheel.accepted = true;
                }
            }
        }
    }

    horizontalBarPill: Component {
        Item {
            implicitWidth: root.workspaces.length > 0 ? root.workspaces.length * root.dotSize + (root.workspaces.length - 1) * root.dotGap : 0
            implicitHeight: root.workspaces.length > 0 ? root.activeDotSize : 0
            opacity: root.workspaces.length > 0 ? 1 : 0

            Row {
                spacing: root.dotGap
                anchors.centerIn: parent

                Repeater {
                    model: root.workspaces

                    Rectangle {
                        id: hDot

                        required property var modelData
                        required property int index

                        readonly property bool isActive: root.activeIndex === index
                        readonly property bool occupied: root.isOccupied(modelData)

                        width: isActive ? root.activeDotSize : root.dotSize
                        height: width
                        radius: width / 2
                        color: isActive ? Theme.primary
                                        : (occupied ? Theme.withAlpha(Theme.widgetTextColor, 0.55)
                                                    : Theme.withAlpha(Theme.widgetTextColor, 0.22))
                        anchors.verticalCenter: parent ? parent.verticalCenter : undefined

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            acceptedButtons: Qt.LeftButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NiriService.switchToWorkspace(hDot.modelData.id)
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                acceptedButtons: Qt.NoButton

                onWheel: wheel => {
                    if (wheel.angleDelta.x > 0 || wheel.angleDelta.y > 0)
                        root.switchBy(-1);
                    else
                        root.switchBy(1);
                    wheel.accepted = true;
                }
            }
        }
    }
}
