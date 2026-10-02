import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

// 联想拯救者性能调节面板（参考 johnfanv2/LenovoLegionLinux，功能集对照
// LenovoLegionToolkit-Team/LenovoLegionToolkit 移植；2026-10-02 重构）：
//  - 顶部仪表盘：CPU（占用/频率/温度/功耗 RAPL）、GPU（占用/频率/温度/功耗）、风扇转速、电池
//  - 性能模式：低功耗 / 均衡 / 性能（powerprofilesctl → platform_profile，免 root）
//  - 电源开关：电池养护（ideapad）、USB 常供电、CPU Boost（免密助手）
//  - 风扇曲线：读/写 10 个速度点（hwmon legion_hwmon pwm1_auto_point*_pwm，0-100%，
//    EC 会按 RPM 表量化）+ 安静/均衡/性能预设；**实测可写生效**
//  - 刷新率：eDP-1 60/240Hz、DP-2 60/120/180Hz（niri msg output）
//  - 键盘背光 / Fn 锁
//  - 已移除：功耗墙 PL1/PL2/cTGP 控件（2026-10-02 用户确认用不上，原实现见 git 历史）、
//    「性能拉满」max-power（本机 EC 有硬断电风险，上游已移除该档位）
//  - 本机实测不可写：fan_fullspeed / cpu_temperature_limit / ideapad fan_mode（EC 忽略）
// 悬浮或点击栏上的图标打开面板；状态每 5 秒轮询一次，操作后 0.5 秒刷新。
PluginComponent {
    id: root

    // 2026-10-02：显式 visible 绑定，保证 DMS 的部件"隐藏/显示"（WidgetHost 里 restoreMode
    // 为 RestoreBinding 的 Binding）在恢复时回到本绑定 → 隐藏后再显示能正常回到栏上。
    // （effectiveVisible 恒为 true：这些插件未配置 visibilityCommand）
    visible: root.effectiveVisible

    popoutWidth: 268
    popoutHeight: 640

    // ── 基础状态（轮询刷新） ──
    property string profile: "balanced"
    property real cpuTemp: 0
    property real nvmeTemp: 0
    property int kbdBrightness: -1
    property bool fnLock: false
    property string edpRate: "60.000"
    property string dpRate: "59.951"
    property string platformProfile: "balanced"
    property bool conservation: false
    property bool usbCharging: true
    property bool cpuBoost: true
    property string batteryStatus: ""
    property int batteryHealth: 0
    property int batteryCycles: 0
    property real batteryW: 0

    // ── 仪表盘状态 ──
    property real cpuUsage: -1          // -1 = 数据不足（需要两次 /proc/stat 采样）
    property real cpuFreq: 0            // GHz（cpuinfo_avg_freq）
    property real cpuPower: 0           // W（RAPL 能量差，经免密助手读取）
    property real _prevCpuTotal: -1
    property real _prevCpuIdle: -1
    property real _raplPrev: -1         // µJ
    property real _raplPrevMs: 0
    property real gpuUsage: -1
    property real gpuTemp: 0
    property real gpuPower: 0
    property int gpuClock: 0
    property int fanRpm1: 0
    property int fanRpm2: 0
    readonly property bool legionReady: fanRpm1 > 0

    // ── 风扇曲线（10 个速度点，0-100；EC 会按 RPM 表量化，读回值可能有小差异） ──
    property var fanCurve: []
    readonly property var fanPresets: ({
            "quiet": [0, 0, 0, 5, 5, 10, 15, 20, 25, 30],
            "balanced": [5, 10, 15, 20, 25, 30, 40, 50, 60, 70],
            "perf": [15, 25, 35, 45, 55, 65, 75, 85, 95, 100]
        })

    function statusText(s) {
        switch (s) {
        case "Charging":
            return "充电中";
        case "Discharging":
            return "放电中";
        case "Not charging":
            return "未充电";
        case "Full":
            return "已充满";
        default:
            return s;
        }
    }

    // 以 sysfs 的 platform_profile 为准；ppd 只用于切换（其档位名是 power-saver 等）
    readonly property bool isPerformance: platformProfile === "performance"
    readonly property int edpRateInt: Math.round(parseFloat(edpRate) || 60)
    readonly property int dpRateInt: Math.round(parseFloat(dpRate) || 60)

    function rateEqual(a, b) {
        return Math.abs(parseFloat(a) - b) < 0.6;
    }

    function runAction(cmd) {
        actionProc.command = ["sh", "-c", cmd];
        actionProc.running = true;
        requery.restart();
    }

    function setProfile(p) {
        runAction("powerprofilesctl set " + p);
    }

    function setConservation(v) {
        runLed("conservation " + (v ? 1 : 0));
    }

    function setUsbCharging(v) {
        runLed("usb " + (v ? 1 : 0));
    }

    function setCpuBoost(v) {
        runLed("boost " + (v ? 1 : 0));
    }

    function setMode(output, mode) {
        runAction("niri msg output " + output + " mode " + mode);
    }

    function applyFanPreset(name) {
        const c = root.fanPresets[name];
        if (!c)
            return;
        runLed("fancurve '" + c.join(" ") + "'");
    }

    /* 已移除（2026-10-02，用户确认功耗墙用不上）：PL1/PL2/cTGP 步进控制与对应状态
     * （pl1/pl2/ctgp 属性、pl1Step/pl2Step/ctgpStep、助手 pl1/pl2/ctgp 子命令、查询段）。
     * 恢复：见 git 历史中本文件 2026-10-02 第二阶段版本；助手脚本子命令仍在。
     * 另：setProfileMax()（platform_profile=max-power）因本机 EC 硬断电风险被移除（同上）。
     */

    // 需要 root 的硬件写入：优先走 sudoers NOPASSWD 白名单（免密），未配置时回退 pkexec（弹密码框）。
    // 白名单条目只认脚本路径不认参数，所以新增子命令无需改 sudoers（脚本内已严格校验参数）。
    // 回退判断用 `sudo -n -l <脚本>`（只检查权限、免密且不执行），避免"脚本存在但写入失败"时误弹密码框。
    readonly property string ledHelper: "/home/zzp/.local/bin/zzp-legion-led"

    function runLed(args) {
        runAction("if sudo -n -l " + ledHelper + " >/dev/null 2>&1; then sudo -n " + ledHelper + " " + args + " 2>/dev/null; else pkexec " + ledHelper + " " + args + "; fi");
    }

    function setLed(kind, value) {
        runLed(kind + " " + value);
    }

    // ── 状态查询（段落顺序决定解析下标，勿随意调整） ──
    // 0 ppd / 1 输出 / 2 CPU温 / 3 硬盘温 / 4 背光 / 5 Fn锁 / 6 platform_profile /
    // 7 电池养护+USB / 8 CPU Boost / 9 GPU / 10 电池 / 11 CPU频率+stat / 12 风扇转速 / 13 风扇曲线
    Process {
        id: queryProc

        command: ["sh", "-c", "IDEA=/sys/devices/pci0000:00/0000:00:14.3/PNP0C09:00/VPC2004:00; powerprofilesctl get; echo ===; niri msg outputs | grep -E '^Output |Current mode'; echo ===; for h in /sys/class/hwmon/hwmon*; do [ \"$(cat $h/name 2>/dev/null)\" = k10temp ] && cat $h/temp1_input 2>/dev/null; done; echo ===; for h in /sys/class/hwmon/hwmon*; do [ \"$(cat $h/name 2>/dev/null)\" = nvme ] && cat $h/temp1_input 2>/dev/null && break; done; echo ===; cat /sys/class/leds/platform::kbd_backlight/brightness 2>/dev/null; echo ===; cat /sys/class/leds/platform::fnlock/brightness 2>/dev/null; echo ===; cat /sys/firmware/acpi/platform_profile; echo ===; cat $IDEA/conservation_mode; cat $IDEA/usb_charging; echo ===; cat /sys/devices/system/cpu/cpufreq/boost; echo ===; nvidia-smi --query-gpu=temperature.gpu,power.draw,clocks.gr,utilization.gpu --format=csv,noheader,nounits 2>/dev/null; echo ===; cat /sys/class/power_supply/BAT0/cycle_count 2>/dev/null; cat /sys/class/power_supply/BAT0/energy_full 2>/dev/null; cat /sys/class/power_supply/BAT0/energy_full_design 2>/dev/null; cat /sys/class/power_supply/BAT0/power_now 2>/dev/null; cat /sys/class/power_supply/BAT0/status 2>/dev/null; echo ===; cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_avg_freq 2>/dev/null; grep '^cpu ' /proc/stat; echo ===; for h in /sys/class/hwmon/hwmon*; do [ \"$(cat $h/name 2>/dev/null)\" = legion_hwmon ] && { cat $h/fan1_input 2>/dev/null; cat $h/fan2_input 2>/dev/null; for i in 1 2 3 4 5 6 7 8 9 10; do cat $h/pwm1_auto_point${i}_pwm 2>/dev/null; done; }; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.split("===\n");
                if (parts[0] !== undefined && parts[0].trim() !== "")
                    root.profile = parts[0].trim();
                const out = parts[1] || "";
                let cur = "";
                const rates = {};
                for (const line of out.split("\n")) {
                    const mo = line.match(/^Output ".*" \((.+)\)/);
                    if (mo) {
                        cur = mo[1];
                        continue;
                    }
                    const mm = line.match(/Current mode: \S+ @ (\S+)/);
                    if (mm && cur)
                        rates[cur] = mm[1];
                }
                if (rates["eDP-1"] !== undefined)
                    root.edpRate = rates["eDP-1"];
                if (rates["DP-2"] !== undefined)
                    root.dpRate = rates["DP-2"];
                const cpu = parseInt(parts[2]);
                if (!isNaN(cpu) && cpu > 0)
                    root.cpuTemp = cpu / 1000;
                const nvme = parseInt(parts[3]);
                if (!isNaN(nvme) && nvme > 0)
                    root.nvmeTemp = nvme / 1000;
                const bl = parseInt(parts[4]);
                if (!isNaN(bl))
                    root.kbdBrightness = bl;
                const fn = parseInt(parts[5]);
                if (!isNaN(fn))
                    root.fnLock = fn === 1;
                if (parts[6] !== undefined && parts[6].trim() !== "")
                    root.platformProfile = parts[6].trim();
                const pwr = (parts[7] || "").trim().split("\n");
                if (pwr[0] !== undefined && pwr[0].trim() !== "")
                    root.conservation = pwr[0].trim() === "1";
                if (pwr[1] !== undefined && pwr[1].trim() !== "")
                    root.usbCharging = pwr[1].trim() === "1";
                const bst = parseInt(parts[8]);
                if (!isNaN(bst))
                    root.cpuBoost = bst === 1;
                const gpu = (parts[9] || "").trim().split(",");
                if (gpu.length >= 4) {
                    const gt = parseFloat(gpu[0]);
                    const gp = parseFloat(gpu[1]);
                    const gc = parseFloat(gpu[2]);
                    const gu = parseFloat(gpu[3]);
                    if (!isNaN(gt) && gt > 0)
                        root.gpuTemp = gt;
                    if (!isNaN(gp) && gp > 0)
                        root.gpuPower = gp;
                    if (!isNaN(gc) && gc > 0)
                        root.gpuClock = Math.round(gc);
                    if (!isNaN(gu))
                        root.gpuUsage = Math.round(gu);
                }
                const bat = (parts[10] || "").trim().split("\n");
                const cyc = parseInt(bat[0]);
                const ef = parseFloat(bat[1]);
                const efd = parseFloat(bat[2]);
                const pw = parseFloat(bat[3]);
                if (!isNaN(cyc))
                    root.batteryCycles = cyc;
                if (!isNaN(ef) && !isNaN(efd) && efd > 0)
                    root.batteryHealth = Math.round(ef / efd * 100);
                if (!isNaN(pw))
                    root.batteryW = Math.round(pw / 100000) / 10;
                if (bat[4] !== undefined && bat[4].trim() !== "")
                    root.batteryStatus = bat[4].trim();
                // CPU 频率 + /proc/stat 采样（占用率用两次采样的差值算）
                const cf = (parts[11] || "").trim().split("\n");
                const freq = parseInt(cf[0]);
                if (!isNaN(freq) && freq > 0)
                    root.cpuFreq = freq / 1000000;
                const stat = (cf[1] || "").trim().split(/\s+/);
                if (stat.length >= 6 && stat[0] === "cpu") {
                    let total = 0;
                    for (let i = 1; i < stat.length; i++)
                        total += parseInt(stat[i]) || 0;
                    const idle = (parseInt(stat[4]) || 0) + (parseInt(stat[5]) || 0);
                    if (root._prevCpuTotal >= 0 && total > root._prevCpuTotal) {
                        const dTotal = total - root._prevCpuTotal;
                        const dIdle = idle - root._prevCpuIdle;
                        root.cpuUsage = Math.round(Math.max(0, Math.min(1, 1 - dIdle / dTotal)) * 100);
                    }
                    root._prevCpuTotal = total;
                    root._prevCpuIdle = idle;
                }
                // 风扇转速 + 曲线（legion_hwmon：先 2 行转速，再 10 行曲线点）
                const fan = (parts[12] || "").trim().split("\n").map(v => parseInt(v));
                if (fan.length >= 2 && !isNaN(fan[0])) {
                    root.fanRpm1 = fan[0] || 0;
                    root.fanRpm2 = fan[1] || 0;
                    const pts = [];
                    for (let i = 2; i < fan.length && pts.length < 10; i++) {
                        if (!isNaN(fan[i]))
                            pts.push(fan[i]);
                    }
                    if (pts.length === 10)
                        root.fanCurve = pts;
                }
            }
        }
    }

    // RAPL（CPU 包功耗）：energy_uj 仅 root 可读 → 经免密助手；用两次采样差算瓦数
    Process {
        id: raplProc

        command: ["sh", "-c", "sudo -n " + root.ledHelper + " rapl 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseFloat(this.text);
                const now = Date.now();
                if (isNaN(v) || v <= 0)
                    return;
                if (root._raplPrev > 0 && now > root._raplPrevMs) {
                    const dt = (now - root._raplPrevMs) / 1000;
                    const w = (v - root._raplPrev) / 1000000 / dt;
                    if (w >= 0 && w < 300)
                        root.cpuPower = Math.round(w);
                }
                root._raplPrev = v;
                root._raplPrevMs = now;
            }
        }
    }

    Process {
        id: actionProc

        command: []
    }

    Timer {
        interval: 500
        running: false
        repeat: false
        id: requery

        onTriggered: {
            queryProc.running = true;
            raplProc.running = true;
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            queryProc.running = true;
            raplProc.running = true;
        }
    }

    // ── 复用组件 ──
    // 等宽分段控件：填满整行、按钮等宽（根治此前各行宽度不齐/左右边距不一致的问题）
    component SegmentRow: Row {
        id: seg

        property var items: []
        property var onPick: null

        spacing: 6
        readonly property real segWidth: Math.max(40, (width - spacing * Math.max(0, items.length - 1)) / Math.max(1, items.length))

        Repeater {
            model: seg.items

            Rectangle {
                required property var modelData
                required property int index

                width: seg.segWidth
                height: 30
                radius: 15
                color: modelData.selected ? Theme.primary : Theme.primaryHover

                StyledText {
                    anchors.centerIn: parent
                    text: modelData.label
                    font.pixelSize: 12
                    color: modelData.selected ? Theme.background : Theme.widgetTextColor
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (seg.onPick)
                            seg.onPick(index);
                    }
                }
            }
        }
    }

    // 仪表盘用量条（0-1）
    component UsageBar: Item {
        property real pct: 0

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 5
            radius: height / 2
            color: Theme.withAlpha(Theme.primary, 0.18)
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * Math.max(0, Math.min(1, parent.pct))
            height: 5
            radius: height / 2
            color: parent.pct >= 0 ? Theme.primary : "transparent"
        }
    }

    component SectionCaption: StyledText {
        text: ""
        font.pixelSize: 11
        color: Theme.surfaceVariantText
    }

    // 仪表盘一行：标签 + 用量条 + 数值文本
    component DashRow: Row {
        id: dashRow

        property string label: ""
        property real pct: -1
        property string value: ""

        width: parent.width
        spacing: 8

        StyledText {
            width: 30
            text: dashRow.label
            font.pixelSize: 11
            color: Theme.surfaceVariantText
        }

        UsageBar {
            width: Math.max(24, dashRow.width - 30 - 8 - 132 - 8)
            height: 16
            pct: dashRow.pct < 0 ? 0 : dashRow.pct / 100
        }

        StyledText {
            width: 132
            horizontalAlignment: Text.AlignRight
            text: dashRow.value
            font.pixelSize: 11
            color: Theme.widgetTextColor
            elide: Text.ElideRight
        }
    }

    popoutContent: Component {
        Item {
            // PluginPopout 将面板高度绑定到根 Item 的 implicitHeight，必须显式给出
            implicitHeight: panelColumn.implicitHeight + Theme.spacingM * 2

            Column {
                id: panelColumn

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingM
                spacing: 10

                StyledText {
                    text: "拯救者性能"
                    font.pixelSize: 15
                    color: Theme.surfaceText
                }

                // ── 顶部仪表盘（2026-10-02：监控值上移，用户要求） ──
                SectionCaption {
                    text: "状态总览"
                }

                Rectangle {
                    width: parent.width
                    height: dashColumn.implicitHeight + Theme.spacingM * 2
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceText, 0.06)

                    Column {
                        id: dashColumn

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.spacingM
                        spacing: 8

                        DashRow {
                            label: "CPU"
                            pct: root.cpuUsage
                            value: (root.cpuUsage >= 0 ? root.cpuUsage + "%" : "--") + " · " + (root.cpuFreq > 0 ? root.cpuFreq.toFixed(2) + "G" : "--") + " · " + Math.round(root.cpuTemp) + "°C · " + (root.cpuPower > 0 ? root.cpuPower + "W" : "--")
                        }

                        DashRow {
                            label: "GPU"
                            pct: root.gpuUsage
                            value: (root.gpuUsage >= 0 ? root.gpuUsage + "%" : "--") + " · " + (root.gpuClock > 0 ? root.gpuClock + "M" : "--") + " · " + Math.round(root.gpuTemp) + "°C · " + root.gpuPower.toFixed(1) + "W"
                        }

                        StyledText {
                            width: parent.width
                            text: "风扇 " + root.fanRpm1 + " / " + root.fanRpm2 + " RPM" + (root.batteryHealth > 0 ? "   ·   电池 " + root.batteryHealth + "% · 循环 " + root.batteryCycles + (root.batteryW > 0 ? " · " + root.batteryW.toFixed(1) + "W" : "") : "")
                            font.pixelSize: 11
                            color: Theme.surfaceVariantText
                            elide: Text.ElideRight
                        }
                    }
                }

                // ── 性能模式 ──
                SectionCaption {
                    text: "性能模式（power-profiles-daemon / platform_profile）"
                }

                SegmentRow {
                    width: parent.width
                    items: [
                        {
                            label: "低功耗",
                            selected: root.platformProfile === "low-power"
                        },
                        {
                            label: "均衡",
                            selected: root.platformProfile === "balanced"
                        },
                        {
                            label: "性能",
                            selected: root.platformProfile === "performance"
                        }
                    ]
                    onPick: i => root.setProfile(i === 0 ? "power-saver" : (i === 1 ? "balanced" : "performance"))
                }

                // CPU Boost（单开关一行）
                SegmentRow {
                    width: parent.width
                    items: [{
                            label: root.cpuBoost ? "CPU Boost：开" : "CPU Boost：关",
                            selected: root.cpuBoost
                        }]
                    onPick: i => root.setCpuBoost(!root.cpuBoost)
                }

                Item {
                    width: 1
                    height: 2
                }

                // ── 刷新率 ──
                SectionCaption {
                    text: "刷新率 · 内屏 eDP-1（2560×1600）"
                }

                SegmentRow {
                    width: parent.width
                    items: [
                        {
                            label: "60Hz",
                            selected: root.rateEqual(root.edpRate, 60)
                        },
                        {
                            label: "240Hz",
                            selected: root.rateEqual(root.edpRate, 240)
                        }
                    ]
                    onPick: i => root.setMode("eDP-1", i === 0 ? "2560x1600@60.000" : "2560x1600@240.002")
                }

                Item {
                    width: 1
                    height: 2
                }

                SectionCaption {
                    text: "刷新率 · 外屏 DP-2（2560×1440）"
                }

                SegmentRow {
                    width: parent.width
                    items: [
                        {
                            label: "60Hz",
                            selected: root.rateEqual(root.dpRate, 60)
                        },
                        {
                            label: "120Hz",
                            selected: root.rateEqual(root.dpRate, 120)
                        },
                        {
                            label: "180Hz",
                            selected: root.rateEqual(root.dpRate, 180)
                        }
                    ]
                    onPick: i => root.setMode("DP-2", i === 0 ? "2560x1440@59.951" : (i === 1 ? "2560x1440@120.000" : "2560x1440@180.000"))
                }

                Item {
                    width: 1
                    height: 2
                }

                // ── 键盘背光 / Fn 锁 ──
                SectionCaption {
                    text: "键盘背光（fn+空格 亦可用）"
                }

                SegmentRow {
                    width: parent.width
                    items: [
                        {
                            label: "关",
                            selected: root.kbdBrightness === 0
                        },
                        {
                            label: "低",
                            selected: root.kbdBrightness === 1
                        },
                        {
                            label: "高",
                            selected: root.kbdBrightness === 2
                        },
                        {
                            label: "Fn锁",
                            selected: root.fnLock
                        }
                    ]
                    onPick: i => {
                        if (i < 3)
                            root.setLed("bl", i);
                        else
                            root.setLed("fnlock", root.fnLock ? 0 : 1);
                    }
                }

                Item {
                    width: 1
                    height: 2
                }

                // ── 电池与接口 ──
                SectionCaption {
                    text: "电池与接口（ideapad EC）"
                }

                SegmentRow {
                    width: parent.width
                    items: [
                        {
                            label: root.conservation ? "电池养护 开" : "电池养护 关",
                            selected: root.conservation
                        },
                        {
                            label: root.usbCharging ? "USB常供电 开" : "USB常供电 关",
                            selected: root.usbCharging
                        }
                    ]
                    onPick: i => {
                        if (i === 0)
                            root.setConservation(!root.conservation);
                        else
                            root.setUsbCharging(!root.usbCharging);
                    }
                }

                // ── 风扇曲线（LenovoLegionLinux，实测可写） ──
                Item {
                    width: 1
                    height: 2
                    visible: root.legionReady
                }

                SectionCaption {
                    visible: root.legionReady
                    text: "风扇曲线（LenovoLegionLinux · 10 档速度点）"
                }

                Rectangle {
                    width: parent.width
                    height: 52
                    visible: root.legionReady
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceText, 0.06)

                    Canvas {
                        id: curveCanvas

                        anchors.fill: parent
                        anchors.margins: 4

                        Connections {
                            target: root

                            function onFanCurveChanged() {
                                curveCanvas.requestPaint();
                            }
                        }

                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            const n = root.fanCurve.length;
                            if (n < 2)
                                return;
                            const pad = 4;
                            const w = width - pad * 2;
                            const h = height - pad * 2;
                            ctx.strokeStyle = Theme.withAlpha(Theme.surfaceText, 0.12);
                            ctx.lineWidth = 1;
                            for (let g = 0; g <= 4; g++) {
                                const y = pad + h * g / 4;
                                ctx.beginPath();
                                ctx.moveTo(pad, y);
                                ctx.lineTo(pad + w, y);
                                ctx.stroke();
                            }
                            const px = i => pad + w * i / (n - 1);
                            const py = v => pad + h * (1 - Math.max(0, Math.min(100, v)) / 100);
                            ctx.strokeStyle = Theme.primary;
                            ctx.lineWidth = 2;
                            ctx.beginPath();
                            for (let i = 0; i < n; i++) {
                                if (i === 0)
                                    ctx.moveTo(px(i), py(root.fanCurve[i]));
                                else
                                    ctx.lineTo(px(i), py(root.fanCurve[i]));
                            }
                            ctx.stroke();
                            ctx.fillStyle = Theme.primary;
                            for (let i = 0; i < n; i++) {
                                ctx.beginPath();
                                ctx.arc(px(i), py(root.fanCurve[i]), 2, 0, Math.PI * 2);
                                ctx.fill();
                            }
                        }
                    }
                }

                SegmentRow {
                    width: parent.width
                    visible: root.legionReady
                    items: [
                        {
                            label: "安静",
                            selected: false
                        },
                        {
                            label: "均衡",
                            selected: false
                        },
                        {
                            label: "性能",
                            selected: false
                        }
                    ]
                    onPick: i => root.applyFanPreset(i === 0 ? "quiet" : (i === 1 ? "balanced" : "perf"))
                }

                StyledText {
                    width: parent.width
                    visible: root.legionReady
                    text: "曲线为各温度点的风扇速度（0-100%，EC 按转速表取整）；切换性能模式会套用该档默认曲线，可用预设重设。"
                    font.pixelSize: 10
                    color: Theme.surfaceVariantText
                    wrapMode: Text.Wrap
                }

                // ── 提示 ──
                StyledText {
                    width: parent.width
                    text: root.isPerformance ? "⚠ 性能模式下风扇与功耗较高，插电使用效果最佳"
                                             : "提示：独显直连 / RGB 灯效需驱动与额外工具；风扇仅曲线可调，无全速开关（本机 EC 忽略）"
                    font.pixelSize: 10
                    color: Theme.surfaceVariantText
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    // ── 栏上图标：性能模式时高亮 ──
    // 2026-10-02：内容里的 hoverEnabled MouseArea 会吃掉 BasePill 的 hover 事件（深色反馈消失），
    // 与时钟/媒体插件同样弃用——悬浮改由栏控制器调 triggerHoverPopout（基类实现，走 pluginPopout）。
    // 旧写法见 git 历史（hoverEnabled MouseArea + onContainsMouseChanged）。
    verticalBarPill: Component {
        Item {
            implicitWidth: 24
            implicitHeight: 24

            DankIcon {
                anchors.centerIn: parent
                name: "tune"
                size: Theme.barIconSize(barThickness, -4, barConfig?.maximizeWidgetIcons, barConfig?.iconScale)
                color: root.isPerformance ? Theme.primary : Theme.widgetIconColor
            }
        }
    }

    horizontalBarPill: Component {
        Item {
            implicitWidth: 24
            implicitHeight: 24

            DankIcon {
                anchors.centerIn: parent
                name: "tune"
                size: Theme.barIconSize(barThickness, -4, barConfig?.maximizeWidgetIcons, barConfig?.iconScale)
                color: root.isPerformance ? Theme.primary : Theme.widgetIconColor
            }
        }
    }

}
