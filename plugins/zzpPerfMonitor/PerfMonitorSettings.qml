import QtQuick
import qs.Common
import qs.Modules.Plugins

PluginSettings {
    id: root

    pluginId: "zzpPerfMonitor"

    Column {
        width: parent.width
        spacing: Theme.spacingL

        StyledText {
            text: "性能监控 (CPU/内存/GPU)"
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Bold
            color: Theme.surfaceText
        }

        StyledText {
            text: "在栏上实时显示 CPU / 内存 / GPU 占用，点击展开三仪表盘面板。GPU 数据来自 nvidia-smi。"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceTextMedium
            width: parent.width
            wrapMode: Text.WordWrap
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.outlineVariant
        }

        ToggleSetting {
            settingKey: "showCpu"
            label: "显示 CPU"
            description: "在栏上和面板中显示 CPU 占用"
            defaultValue: true
        }

        ToggleSetting {
            settingKey: "showMem"
            label: "显示内存"
            description: "在栏上和面板中显示内存占用"
            defaultValue: true
        }

        ToggleSetting {
            settingKey: "showGpu"
            label: "显示 GPU"
            description: "使用 nvidia-smi 读取 GPU 占用与显存；无 NVIDIA GPU 时自动显示 --"
            defaultValue: true
        }
    }

    function saveValue(key, value) {
        if (pluginService) {
            pluginService.savePluginData(root.pluginId, key, value);
        }
    }

    function loadValue(key, defaultValue) {
        if (pluginService) {
            return pluginService.loadPluginData(root.pluginId, key, defaultValue);
        }
        return defaultValue;
    }
}
