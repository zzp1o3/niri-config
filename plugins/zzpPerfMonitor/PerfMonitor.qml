import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

// Merged live performance monitor: CPU / memory / GPU in one bar pill,
// with a dashboard popout (three ring gauges + process list shortcut).
PluginComponent {
    id: root

    // ---------- live metrics ----------
    readonly property real cpuUsage: DgopService.cpuUsage ?? 0
    readonly property real memUsage: DgopService.memoryUsage ?? 0
    readonly property real memUsedGB: (DgopService.usedMemoryMB ?? 0) / 1024
    readonly property real memTotalGB: (DgopService.totalMemoryMB ?? 0) / 1024
    readonly property real cpuTemp: DgopService.cpuTemperature ?? 0
    readonly property real cpuGHz: (DgopService.cpuFrequency ?? 0) / 1000

    property real gpuUsage: -1
    property real gpuUsageSmooth: -1
    property real gpuMemUsedMB: -1
    property real gpuMemTotalMB: -1
    property real gpuTemp: -1

    // nvidia-smi reports bursty per-frame kernels, so the raw value swings
    // wildly; show an exponential moving average instead.
    readonly property real gpuUsageDisplay: root.gpuUsage < 0 ? -1 : root.gpuUsageSmooth

    readonly property bool showCpu: pluginData.showCpu !== false
    readonly property bool showMem: pluginData.showMem !== false
    readonly property bool showGpu: pluginData.showGpu !== false

    readonly property int metricIconSize: Theme.barIconSize(barThickness, -4, barConfig?.maximizeWidgetIcons, barConfig?.iconScale)
    readonly property int metricFontSize: Theme.barTextSize(barThickness, barConfig?.fontScale, barConfig?.maximizeWidgetText)

    function usageColor(v) {
        if (v < 0)
            return Theme.surfaceVariantText;
        if (v >= 85)
            return Theme.tempDanger;
        if (v >= 60)
            return Theme.tempWarning;
        return Theme.widgetIconColor;
    }

    function cpuDetail() {
        var parts = [];
        if (cpuTemp > 0)
            parts.push(Math.round(cpuTemp) + "°C");
        if (cpuGHz > 0)
            parts.push(cpuGHz.toFixed(1) + "GHz");
        return parts.join(" · ");
    }

    function memDetail() {
        if (memTotalGB <= 0)
            return "";
        return memUsedGB.toFixed(1) + " / " + memTotalGB.toFixed(0) + " GB";
    }

    function gpuDetail() {
        if (gpuUsage < 0)
            return "不可用";
        var parts = [(gpuMemUsedMB / 1024).toFixed(1) + " / " + (gpuMemTotalMB / 1024).toFixed(0) + " GB"];
        if (gpuTemp >= 0)
            parts.push(Math.round(gpuTemp) + "°C");
        return parts.join(" · ");
    }

    Component.onCompleted: DgopService.addRef(["cpu", "memory"])
    Component.onDestruction: DgopService.removeRef(["cpu", "memory"])

    // ---------- GPU polling via nvidia-smi ----------
    Process {
        id: gpuProc
        command: ["nvidia-smi", "--query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu", "--format=csv,noheader,nounits"]
        stdout: StdioCollector {
            id: gpuOut
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.gpuUsage = -1;
                root.gpuUsageSmooth = -1;
                root.gpuMemUsedMB = -1;
                root.gpuMemTotalMB = -1;
                root.gpuTemp = -1;
            }
        }
    }

    Connections {
        target: gpuOut
        function onStreamFinished() {
            const line = (gpuOut.text || "").trim().split("\n")[0];
            const p = line.split(",").map(s => s.trim());
            if (p.length >= 4) {
                const v = parseFloat(p[0]);
                root.gpuUsage = v;
                root.gpuUsageSmooth = root.gpuUsageSmooth < 0 ? v : root.gpuUsageSmooth * 0.55 + v * 0.45;
                root.gpuMemUsedMB = parseFloat(p[1]);
                root.gpuMemTotalMB = parseFloat(p[2]);
                root.gpuTemp = parseFloat(p[3]);
            }
        }
    }

    Timer {
        interval: 1200
        repeat: true
        running: root.showGpu
        triggeredOnStart: true
        onTriggered: {
            if (!gpuProc.running)
                gpuProc.running = true;
        }
    }

    // ---------- bar pills ----------
    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS

            Row {
                visible: root.showCpu
                spacing: 2
                DankIcon {
                    name: "memory"
                    size: root.metricIconSize
                    color: root.usageColor(root.cpuUsage)
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: Math.round(root.cpuUsage) + "%"
                    font.pixelSize: root.metricFontSize
                    color: root.usageColor(root.cpuUsage)
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                visible: root.showMem
                spacing: 2
                DankIcon {
                    name: "developer_board"
                    size: root.metricIconSize
                    color: root.usageColor(root.memUsage)
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: Math.round(root.memUsage) + "%"
                    font.pixelSize: root.metricFontSize
                    color: root.usageColor(root.memUsage)
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                visible: root.showGpu
                spacing: 2
                DankIcon {
                    name: "speed"
                    size: root.metricIconSize
                    color: root.usageColor(root.gpuUsageDisplay)
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: root.gpuUsageDisplay < 0 ? "--" : Math.round(root.gpuUsageDisplay) + "%"
                    font.pixelSize: root.metricFontSize
                    color: root.usageColor(root.gpuUsageDisplay)
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            Column {
                visible: root.showCpu
                spacing: 1
                anchors.horizontalCenter: parent.horizontalCenter

                DankIcon {
                    name: "memory"
                    size: root.metricIconSize
                    color: root.usageColor(root.cpuUsage)
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                NumericText {
                    isMonospace: false
                    text: Math.round(root.cpuUsage)
                    reserveText: "100"
                    font.pixelSize: root.metricFontSize
                    color: root.usageColor(root.cpuUsage)
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Column {
                visible: root.showMem
                spacing: 1
                anchors.horizontalCenter: parent.horizontalCenter

                DankIcon {
                    name: "developer_board"
                    size: root.metricIconSize
                    color: root.usageColor(root.memUsage)
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                NumericText {
                    isMonospace: false
                    text: Math.round(root.memUsage)
                    reserveText: "100"
                    font.pixelSize: root.metricFontSize
                    color: root.usageColor(root.memUsage)
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Column {
                visible: root.showGpu
                spacing: 1
                anchors.horizontalCenter: parent.horizontalCenter

                DankIcon {
                    name: "speed"
                    size: root.metricIconSize
                    color: root.usageColor(root.gpuUsageDisplay)
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                NumericText {
                    isMonospace: false
                    text: root.gpuUsageDisplay < 0 ? "--" : Math.round(root.gpuUsageDisplay)
                    reserveText: "100"
                    font.pixelSize: root.metricFontSize
                    color: root.usageColor(root.gpuUsageDisplay)
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    // ---------- popout dashboard ----------
    // Height is auto-managed by PluginPopout from the content's implicitHeight.
    popoutWidth: 560
    popoutHeight: 560

    popoutContent: Component {
        PopoutComponent {
            id: pc
            headerText: "性能监控"
            showCloseButton: true

            property string searchText: ""
            property string processFilter: "all"

            // 关闭面板时重置筛选与搜索（与官方进程弹窗行为一致）
            Connections {
                target: pc.parentPopout
                function onShouldBeVisibleChanged() {
                    if (pc.parentPopout && !pc.parentPopout.shouldBeVisible) {
                        processFilterGroup.currentIndex = 0;
                        pc.processFilter = "all";
                        pc.searchText = "";
                    }
                }
            }

            Column {
                id: content
                width: parent.width
                topPadding: Theme.spacingS
                spacing: Theme.spacingM

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacingL

                    ArcGauge {
                        visible: root.showCpu
                        ringSize: 74
                        value: root.cpuUsage
                        accent: Theme.primary
                        label: "CPU"
                        detail: root.cpuDetail()
                    }

                    ArcGauge {
                        visible: root.showMem
                        ringSize: 74
                        value: root.memUsage
                        accent: Theme.secondary
                        label: "内存"
                        detail: root.memDetail()
                    }

                    ArcGauge {
                        visible: root.showGpu
                        ringSize: 74
                        value: root.gpuUsageDisplay
                        accent: Theme.tertiary
                        label: "GPU"
                        detail: root.gpuDetail()
                    }
                }

                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingS

                    DankButtonGroup {
                        id: processFilterGroup
                        Layout.minimumWidth: implicitWidth
                        model: ["全部", "用户", "系统"]
                        currentIndex: 0
                        checkEnabled: false
                        buttonHeight: Math.round(Theme.fontSizeSmall * 2.4)
                        minButtonWidth: 0
                        buttonPadding: Theme.spacingM
                        textSize: Theme.fontSizeSmall
                        onSelectionChanged: (index, selected) => {
                            if (!selected)
                                return;
                            currentIndex = index;
                            switch (index) {
                            case 0:
                                pc.processFilter = "all";
                                return;
                            case 1:
                                pc.processFilter = "user";
                                return;
                            case 2:
                                pc.processFilter = "system";
                                return;
                            }
                        }
                    }

                    DankTextField {
                        Layout.fillWidth: true
                        placeholderText: "搜索进程…"
                        leftIconName: "search"
                        showClearButton: true
                        text: pc.searchText
                        onTextChanged: pc.searchText = text
                    }
                }

                ProcListView {
                    width: parent.width
                    height: 320
                    searchText: pc.searchText
                    processFilter: pc.processFilter
                    active: pc.parentPopout ? (pc.parentPopout.shouldBeVisible ?? false) : false
                    popoutRef: pc.parentPopout
                }
            }
        }
    }
}
