import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

// 可被 DMS 正常管理的电池组件（2026-10-02 新建）。
//
// 背景：DMS 内置 `battery` 组件在设置界面做"隐藏 → 显示"后无法恢复上栏。原因：
// 部件显隐由 WidgetHost 里一条 `restoreMode: Binding.RestoreBinding` 的 Binding 控制，
// 恢复时只有"属性原本就有绑定"才能被还原；内置 Battery.qml 的 visible 是字面量
// （`visible: true`），所以隐藏后永远回不来（实测内置 launcher/Battery 都中招）。
//
// 本插件 = 内置电池的等价替换：同样的 BatteryService 数据与 BatteryMeter 环表、
// 同样的颜色规则、点击打开同一个内置电池面板（PopoutService.toggleBattery）；
// 唯一差别是根上显式声明 `visible: root.effectiveVisible` → 可被 DMS 正常增删显隐。
PluginComponent {
    id: root

    property var popoutService: null    // 由 WidgetHost 注入
    property var vPillRoot: null        // 悬浮定位用（与其它插件同款；漏声明会导致定位静默失败）
    property var hPillRoot: null

    // 显式 visible 绑定（DMS 显隐管理必需；effectiveVisible 恒为 true，本插件无 visibilityCommand）
    visible: root.effectiveVisible

    // 与内置一致的样式判断：每部件覆盖（栏配置里的 batteryStyle 等）优先，其次全局设置
    readonly property string styleValue: {
        const v = root.pluginData.batteryStyle;
        if (v && v !== "auto")
            return v;
        return widgetData?.batteryStyle ?? SettingsData.batteryStyle ?? "icon";
    }
    readonly property bool pillStyle: root.styleValue !== "icon"
    readonly property bool levelColors: (barConfig?.batteryColorMode ?? "theme") === "level"

    // 显示项（2026-10-02：可在 DMS 设置→插件→电池（可管理）里调；未设置时回退到全局设置，
    // 与内置电池的 per-widget 选项语义一致）。优先级：插件设置 → 栏条目设置 → 全局。
    readonly property bool showPercent: (pluginData.showPercent ?? SettingsData.showBatteryPercent) === true
    readonly property bool showTime: (pluginData.showTime ?? SettingsData.showBatteryTime) === true
    readonly property bool showPowerCharging: (pluginData.showPowerCharging ?? SettingsData.showBatteryPowerCharging) === true
    readonly property bool showPowerDischarging: (pluginData.showPowerDischarging ?? SettingsData.showBatteryPowerDischarging) === true
    readonly property bool showPower: BatteryService.isCharging ? root.showPowerCharging : root.showPowerDischarging
    readonly property string displayText: {
        const parts = [];
        if (root.showPercent && BatteryService.batteryAvailable)
            parts.push(BatteryService.batteryLevel + "%");
        if (root.showTime && BatteryService.batteryAvailable) {
            const t = BatteryService.formatTimeRemaining();
            if (t)
                parts.push(t);
        }
        if (root.showPower) {
            const w = BatteryService.formatPowerRate(false);
            if (w)
                parts.push(w);
        }
        return parts.join(" ");
    }

    // 与内置逐字相同的图标颜色规则
    function iconColor() {
        if (!BatteryService.batteryAvailable)
            return Theme.widgetIconColor;
        if (root.levelColors)
            return BatteryService.levelColor;
        if (BatteryService.isLowBattery && !BatteryService.isCharging)
            return Theme.error;
        if (BatteryService.isCharging || BatteryService.isPluggedIn)
            return Theme.primary;
        return Theme.widgetIconColor;
    }

    // 点击 → 电池面板（锚定在组件上，与悬浮位置一致）。
    // 2026-10-02 修复：原走 popoutService.toggleBattery(x,y,w,s,scr)（只传 5 个定位参数，
    // 丢失 barPosition/barThickness 等栏上下文）→ 面板锚点错误（用户反馈"跟随鼠标"）。
    function barPosition() {
        return root.axis?.edge === "left" ? 2 : (root.axis?.edge === "right" ? 3 : (root.axis?.edge === "top" ? 0 : 1));
    }

    function positionBattery(pop, x, y, w, s, scr) {
        pop.setTriggerPosition(x, y, w, s, scr, root.barPosition(), root.barThickness, root.barSpacing, root.barConfig);
    }

    pillClickAction: (x, y, w, s, scr) => {
        const pop = PopoutService.batteryPopout;
        if (!pop) {
            if (root.popoutService)
                root.popoutService.toggleBattery(x, y, w, s, scr);
            return;
        }
        root.positionBattery(pop, x, y, w, s, scr);
        pop.toggle();
    }

    // 悬浮 → 电池面板以 hover 模式弹出、移开自动消失（对齐内置 battery 的悬浮行为；
    // 用户反馈"原本有面板、换掉后没有了"——之前只实现了点击）
    property string _pendingTrigger: ""
    property int _pendingRetries: 0

    Timer {
        id: _batteryRetryTimer

        interval: 120
        onTriggered: root.openBatteryNow(root._pendingTrigger, root._pendingRetries)
    }

    function triggerHoverPopout(widgetHostId) {
        const loader = PopoutService.batteryPopoutLoader;
        if (!loader)
            return;
        loader.active = true;
        Qt.callLater(() => root.openBatteryNow(widgetHostId, 12));
    }

    function openBatteryNow(widgetHostId, retries) {
        const pop = PopoutService.batteryPopout;
        if (!pop)
            return;
        // 同其它插件：弹窗关闭动画中时 PopoutManager 会吞掉 hover 请求 → 稍后重试
        if (pop.isClosing && retries > 0) {
            root._pendingTrigger = widgetHostId;
            root._pendingRetries = retries - 1;
            _batteryRetryTimer.restart();
            return;
        }
        const pill = root.isVertical ? root.vPillRoot : root.hPillRoot;
        if (!pill)
            return;
        const globalPos = pill.mapToItem(null, 0, 0);
        const screen = root.parentScreen || Screen;
        const barPosition = root.axis?.edge === "left" ? 2 : (root.axis?.edge === "right" ? 3 : (root.axis?.edge === "top" ? 0 : 1));
        const pos = SettingsData.getPopupTriggerPosition(globalPos, screen, root.barThickness, pill.width, root.barSpacing, barPosition, root.barConfig);
        pop.setTriggerPosition(pos.x, pos.y, pos.width, root.section, screen, barPosition, root.barThickness, root.barSpacing, root.barConfig);
        PopoutManager.requestHoverPopout(pop, undefined, widgetHostId || root.pluginId);
    }

    verticalBarPill: Component {
        Item {
            id: vPillItem

            implicitWidth: root.widgetThickness
            implicitHeight: batteryColumn.implicitHeight

            Component.onCompleted: root.vPillRoot = vPillItem

            Column {
                id: batteryColumn

                anchors.centerIn: parent
                spacing: 1

                DankIcon {
                    name: BatteryService.getBatteryIcon()
                    visible: !root.pillStyle
                    size: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    color: root.iconColor()
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                BatteryMeter {
                    visible: root.pillStyle
                    vertical: true
                    showNumber: false
                    meterStyle: root.styleValue
                    levelColors: root.levelColors
                    maxDiameter: root.widgetThickness - Theme.spacingXS
                    thickness: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: root.displayText
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    color: Theme.widgetTextColor
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.displayText !== ""
                }
            }
        }
    }

    horizontalBarPill: Component {
        // Row 是 positioner，implicitHeight 只读 → 用 Item 包一层给显式隐式尺寸（同内置 Clock 写法）
        Item {
            id: hPillItem

            implicitWidth: hRow.implicitWidth
            implicitHeight: root.widgetThickness

            Component.onCompleted: root.hPillRoot = hPillItem

            Row {
                id: hRow

                spacing: (root.barConfig?.noBackground ?? false) ? 1 : 2
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    name: BatteryService.getBatteryIcon()
                    visible: !root.pillStyle
                    size: Theme.barIconSize(root.barThickness, -4, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    color: root.iconColor()
                    anchors.verticalCenter: parent.verticalCenter
                }

                BatteryMeter {
                    visible: root.pillStyle
                    vertical: false
                    showNumber: false
                    meterStyle: root.styleValue
                    levelColors: root.levelColors
                    maxDiameter: root.widgetThickness - Theme.spacingXS
                    thickness: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: root.percentText
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.percentText !== ""
                }
            }
        }
    }
}
