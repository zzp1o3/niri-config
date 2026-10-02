import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

// 媒体封面插件的设置页（2026-10-02 新增）。
// DMS 设置 → 插件 → 媒体封面。所有默认值都等于原版行为，不动设置时组件表现与之前完全一致。
// 值经 pluginService.savePluginData 存入插件设置，组件侧通过 pluginData.<key> 读取。
PluginSettings {
    id: root

    pluginId: "zzpMediaCover"

    StyledText {
        width: parent.width
        text: "媒体封面"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "栏上专辑封面组件的行为选项（默认值 = 原版行为）"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    SelectionSetting {
        settingKey: "coverSize"
        label: "封面大小"
        description: "专辑封面的边长（竖排默认 24；频谱区域不受影响，仍为 20）"
        defaultValue: "24"
        options: [
            {
                label: "小（20）",
                value: "20"
            },
            {
                label: "中（24，默认）",
                value: "24"
            },
            {
                label: "大（28）",
                value: "28"
            }
        ]
    }

    ToggleSetting {
        settingKey: "revealPlayButton"
        label: "悬浮时浮现播放按钮"
        description: "鼠标悬浮组件时，封面位置浮现原版播放/暂停按钮（左键播放暂停 / 中键上一首 / 右键下一首）"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "hoverPopout"
        label: "悬浮弹出媒体面板"
        description: "鼠标悬浮组件时弹出 DankDash 媒体页，移开自动消失"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "spectrumOpensPanel"
        label: "点击频谱打开媒体面板"
        description: "点击 20×20 频谱区域时打开 DankDash 媒体页"
        defaultValue: true
    }
}
