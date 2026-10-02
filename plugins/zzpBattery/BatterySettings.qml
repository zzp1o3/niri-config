import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

// 电池（可管理）插件的设置页（2026-10-02 新建）。
// 对应内置电池组件在栏条目菜单里的可调项（样式/百分比/时间/功率）。
// 优先级：本页设置 → 栏条目设置（如 batteryStyle=ring）→ 全局设置；默认值=当前行为。
PluginSettings {
    id: root

    pluginId: "zzpBattery"

    StyledText {
        width: parent.width
        text: "电池（可管理）"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "外观与显示项（不设置时沿用全局/栏条目设置，即当前表现）"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    SelectionSetting {
        settingKey: "batteryStyle"
        label: "样式"
        description: "图标 / 实心环 / 描边环 / 圆圈环（默认跟随栏条目里的设置）"
        defaultValue: "auto"
        options: [
            {
                label: "跟随条目设置（推荐）",
                value: "auto"
            },
            {
                label: "图标",
                value: "icon"
            },
            {
                label: "实心环",
                value: "solid"
            },
            {
                label: "描边环",
                value: "outline"
            },
            {
                label: "圆圈环",
                value: "ring"
            }
        ]
    }

    SelectionSetting {
        settingKey: "iconSize"
        label: "图标 / 环表大小"
        description: "调小可让组件更精致；对图标样式与环表（圆环）样式都生效"
        defaultValue: "0"
        options: [
            {
                label: "更小",
                value: "-6"
            },
            {
                label: "小",
                value: "-3"
            },
            {
                label: "默认",
                value: "0"
            },
            {
                label: "大",
                value: "3"
            }
        ]
    }

    ToggleSetting {
        settingKey: "showPercent"
        label: "显示电量百分比"
        description: "在组件上显示电量数字"
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "showTime"
        label: "显示剩余/充满时间"
        description: "显示电池估算时间"
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "showPowerCharging"
        label: "显示充电功率"
        description: "充电时显示功率（如 +45W）"
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "showPowerDischarging"
        label: "显示放电功率"
        description: "放电时显示功率（如 -8W）"
        defaultValue: false
    }
}
