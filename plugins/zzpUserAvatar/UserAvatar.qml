import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

// User avatar pill for the bar. Shows the AccountsService profile image
// (same source as the control-center header / overview user card); falls
// back to a person icon when no image is set or the file fails to load.
//
// The pill also registers itself as the bar window's controlCenterButtonRef,
// so the stock `dms ipc call control-center toggle` path (Mod+Shift+C) keeps
// working without the blank-rendering in-tree controlCenterButton widget,
// and the control center popout anchors to this pill.
// Left click  -> control center (barWindow.triggerControlCenter, same as IPC)
// Right click -> DankDash overview tab (user info card)
PluginComponent {
    id: root

    // 2026-10-02：显式 visible 绑定，保证 DMS 的部件"隐藏/显示"（WidgetHost 里 restoreMode
    // 为 RestoreBinding 的 Binding）在恢复时回到本绑定 → 隐藏后再显示能正常回到栏上。
    // （effectiveVisible 恒为 true：这些插件未配置 visibilityCommand）
    visible: root.effectiveVisible

    // 旧写法已注释：pillClickAction 会被悬浮控制器在悬浮时误触发（悬浮=弹控制中心且不自动消失）。
    // 点击改为 pill 内容里的 MouseArea 处理，行为不变。
    // pillClickAction: () => {
    //     const win = root.blurBarWindow;
    //     if (win && win.triggerControlCenter)
    //         win.triggerControlCenter();
    // }
    pillRightClickAction: () => Quickshell.execDetached(["dms", "ipc", "call", "dash", "toggle", "overview"])

    // Icon-scale-based sizing: the content-area formula (widgetThickness -
    // horizontalPadding*2) collapses to 0 with widgetPadding >= 15, which is
    // also why the stock ControlCenterButton renders blank in vertical bars.
    readonly property int avatarSize: Theme.barIconSize(barThickness, 4, barConfig?.maximizeWidgetIcons, barConfig?.iconScale)

    property var _barWindow: null

    function registerControlCenterRef() {
        const win = root.blurBarWindow;
        if (!win || win.controlCenterButtonRef === undefined)
            return;
        _barWindow = win;
        win.controlCenterButtonRef = root;
    }

    onBlurBarWindowChanged: registerControlCenterRef()
    Component.onCompleted: registerControlCenterRef()
    Component.onDestruction: {
        if (_barWindow && _barWindow.controlCenterButtonRef === root)
            _barWindow.controlCenterButtonRef = null;
    }

    readonly property string profileSource: {
        let p = PortalService.profileImage;
        if (!p || p === "")
            p = PortalService.systemProfileImage;
        if (!p || p === "")
            return "";
        return p.startsWith("/") ? "file://" + p : p;
    }

    component AvatarImage: Rectangle {
        id: av

        property string source

        radius: width / 2
        color: Theme.primaryHover
        border.color: Theme.outlineMedium
        border.width: 1

        ClippingRectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: width / 2
            color: "transparent"

            Image {
                id: img

                anchors.fill: parent
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                smooth: true
                mipmap: true
                sourceSize.width: Math.max(width * 2, 128)
                sourceSize.height: Math.max(height * 2, 128)
                visible: status === Image.Ready
                source: av.source
            }
        }

        DankIcon {
            name: "person"
            size: Math.round(av.width * 0.62)
            color: Theme.surfaceVariantText
            anchors.centerIn: parent
            visible: av.source === "" || img.status === Image.Error
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: root.avatarSize
            implicitHeight: root.avatarSize

            AvatarImage {
                source: root.profileSource
                width: root.avatarSize
                height: root.avatarSize
                anchors.centerIn: parent
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const win = root.blurBarWindow;
                    if (win && win.triggerControlCenter)
                        win.triggerControlCenter();
                }
            }
        }
    }

    horizontalBarPill: Component {
        Item {
            implicitWidth: root.avatarSize
            implicitHeight: root.avatarSize

            AvatarImage {
                source: root.profileSource
                width: root.avatarSize
                height: root.avatarSize
                anchors.centerIn: parent
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const win = root.blurBarWindow;
                    if (win && win.triggerControlCenter)
                        win.triggerControlCenter();
                }
            }
        }
    }
}
