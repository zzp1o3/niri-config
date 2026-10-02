import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

// 可被 DMS 正常管理的启动器按钮（2026-10-02 新建；内置 launcherButton 的等价替换）。
//
// 与内置逐字一致的部分：LauncherLogo 的全部绑定（含用户的自定义 logo 设置）、
// 左键打开应用抽屉（PopoutService.toggleAppDrawer）、右键 niri 概览（NiriService.toggleOverview）、
// 悬浮应用抽屉（内置走 _hoverSpecs 的 hover 路径，这里覆写 triggerHoverPopout 等价实现）。
//
// 唯一差别：根上显式 `visible: root.effectiveVisible` → DMS 的隐藏/显示能正常恢复
// （内置 launcherButton 没有 visible 绑定，隐藏后永久卡死，只能重启恢复）。
PluginComponent {
    id: root

    property var popoutService: null    // 由 WidgetHost 注入
    property var vPillRoot: null
    property var hPillRoot: null

    visible: root.effectiveVisible

    // 左键：应用抽屉（与内置一致）
    pillClickAction: (x, y, w, s, scr) => {
        if (root.popoutService)
            root.popoutService.toggleAppDrawer(x, y, w, s, scr);
    }

    // 右键：niri 概览（与内置一致）
    pillRightClickAction: () => {
        if (CompositorService.isNiri)
            NiriService.toggleOverview();
    }

    // 悬浮：应用抽屉以 hover 模式弹出（移开自动消失）。与时钟/媒体的 DankDash 悬浮同一机制。
    property string _pendingTrigger: ""
    property int _pendingRetries: 0

    Timer {
        id: _drawerRetryTimer

        interval: 120
        onTriggered: root.openDrawerNow(root._pendingTrigger, root._pendingRetries)
    }

    function triggerHoverPopout(widgetHostId) {
        const loader = PopoutService.appDrawerLoader;
        if (!loader)
            return;
        loader.active = true;
        Qt.callLater(() => root.openDrawerNow(widgetHostId, 12));
    }

    function openDrawerNow(widgetHostId, retries) {
        const drawer = PopoutService.appDrawerPopout;
        if (!drawer)
            return;
        // 同媒体/时钟插件：弹窗关闭动画中时 PopoutManager 会吞掉 hover 请求 → 稍后重试
        if (drawer.isClosing && retries > 0) {
            root._pendingTrigger = widgetHostId;
            root._pendingRetries = retries - 1;
            _drawerRetryTimer.restart();
            return;
        }
        const pill = root.isVertical ? root.vPillRoot : root.hPillRoot;
        if (!pill)
            return;
        const globalPos = pill.mapToItem(null, 0, 0);
        const screen = root.parentScreen || Screen;
        const barPosition = root.axis?.edge === "left" ? 2 : (root.axis?.edge === "right" ? 3 : (root.axis?.edge === "top" ? 0 : 1));
        const pos = SettingsData.getPopupTriggerPosition(globalPos, screen, root.barThickness, pill.width, root.barSpacing, barPosition, root.barConfig);
        drawer.setTriggerPosition(pos.x, pos.y, pos.width, root.section, screen, barPosition, root.barThickness, root.barSpacing, root.barConfig);
        PopoutManager.requestHoverPopout(drawer, undefined, widgetHostId || root.pluginId);
    }

    verticalBarPill: Component {
        Item {
            id: vPillItem

            implicitWidth: root.widgetThickness
            implicitHeight: root.widgetThickness

            Component.onCompleted: root.vPillRoot = vPillItem

            // 与内置 LauncherButton 逐字相同的绑定
            LauncherLogo {
                anchors.centerIn: parent
                mode: SettingsData.launcherLogoMode
                size: Theme.barIconSize(root.barThickness, SettingsData.launcherLogoSizeOffset, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                appsIconSize: Theme.barIconSize(root.barThickness, -4, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                appsIconColor: Theme.widgetIconColor
                colorOverride: Theme.effectiveLogoColor
                brightness: SettingsData.launcherLogoBrightness
                contrast: SettingsData.launcherLogoContrast
                customPath: SettingsData.launcherLogoCustomPath
            }
        }
    }

    horizontalBarPill: Component {
        Item {
            id: hPillItem

            implicitWidth: root.widgetThickness
            implicitHeight: root.widgetThickness

            Component.onCompleted: root.hPillRoot = hPillItem

            LauncherLogo {
                anchors.centerIn: parent
                mode: SettingsData.launcherLogoMode
                size: Theme.barIconSize(root.barThickness, SettingsData.launcherLogoSizeOffset, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                appsIconSize: Theme.barIconSize(root.barThickness, -4, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                appsIconColor: Theme.widgetIconColor
                colorOverride: Theme.effectiveLogoColor
                brightness: SettingsData.launcherLogoBrightness
                contrast: SettingsData.launcherLogoContrast
                customPath: SettingsData.launcherLogoCustomPath
            }
        }
    }
}
