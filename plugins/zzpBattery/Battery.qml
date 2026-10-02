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

    // 显式 visible 绑定（DMS 显隐管理必需；effectiveVisible 恒为 true，本插件无 visibilityCommand）
    visible: root.effectiveVisible

    // 与内置一致的样式判断：每部件覆盖（栏配置里的 batteryStyle 等）优先，其次全局设置
    readonly property string styleValue: widgetData?.batteryStyle ?? SettingsData.batteryStyle ?? "icon"
    readonly property bool pillStyle: root.styleValue !== "icon"
    readonly property bool levelColors: (barConfig?.batteryColorMode ?? "theme") === "level"
    readonly property bool showPercent: SettingsData.showBatteryPercent === true
    readonly property string percentText: root.showPercent && BatteryService.batteryAvailable ? BatteryService.batteryLevel + "%" : ""

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

    // 点击 → 内置电池面板（与内置 battery 组件的行为一致）
    pillClickAction: (x, y, w, s, scr) => {
        if (root.popoutService)
            root.popoutService.toggleBattery(x, y, w, s, scr);
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: root.widgetThickness
            implicitHeight: batteryColumn.implicitHeight

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
                    text: root.percentText
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    color: Theme.widgetTextColor
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.percentText !== ""
                }
            }
        }
    }

    horizontalBarPill: Component {
        // Row 是 positioner，implicitHeight 只读 → 用 Item 包一层给显式隐式尺寸（同内置 Clock 写法）
        Item {
            implicitWidth: hRow.implicitWidth
            implicitHeight: root.widgetThickness

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
