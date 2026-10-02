import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

// Merged clock + date + weather bar widget, styled after the stock DMS clock
// (stacked digit pairs, hairline divider, accent-colored date) with the
// stock weather look (icon + temperature) appended below.
// Left click  -> DankDash overview tab (calendar), same as the old clock.
// Right click -> DankDash weather tab, same as the old weather widget.
PluginComponent {
    id: root

    // 2026-10-02：显式 visible 绑定，保证 DMS 的部件"隐藏/显示"（WidgetHost 里 restoreMode
    // 为 RestoreBinding 的 Binding）在恢复时回到本绑定 → 隐藏后再显示能正常回到栏上。
    // （effectiveVisible 恒为 true：这些插件未配置 visibilityCommand）
    visible: root.effectiveVisible

    // 旧写法已注释：pillClickAction 会被悬浮控制器在悬浮时误触发（悬浮=打开概览页且不自动消失）。
    // 改为在 pill 内容里用 MouseArea 处理点击，行为不变。
    // pillClickAction: () => Quickshell.execDetached(["dms", "ipc", "call", "dash", "toggle", "overview"])
    // pillRightClickAction: () => Quickshell.execDetached(["dms", "ipc", "call", "dash", "toggle", "weather"])

    // 旧版 IPC 打开方式已注释：现统一走 openDashTab（同一个 DankDash 弹窗，支持悬浮跟踪）
    // function openOverview() {
    //     Quickshell.execDetached(["dms", "ipc", "call", "dash", "toggle", "overview"])
    // }
    //
    // function openWeather() {
    //     Quickshell.execDetached(["dms", "ipc", "call", "dash", "toggle", "weather"])
    // }

    property var vPillRoot: null
    property var hPillRoot: null

    // 2026-10-02：点击改回 BasePill 标准通路（内置组件同款），由 BasePill 的 MouseArea 在
    // 真实点击时转发到这两个回调。早先注释里担心的"悬浮时被误触发"来自基类
    // triggerHoverPopout，而本文件已覆写它（见下方），误触发路径不存在。
    // 内容里自绘 hoverEnabled 的 MouseArea 会截走 hover 事件（BasePill 深色反馈消失、
    // 悬浮命中区异常），已弃用——见下方注释块。
    pillClickAction: () => root.openOverview()
    pillRightClickAction: () => root.openWeather()

    /* 旧版（2026-10-02 12:13–12:45）：内容内自绘 MouseArea 处理点击+悬浮。
     * 弃用原因：hoverEnabled 的 MouseArea 位于 BasePill 的 mouseArea（z:-1）之上，
     * 会吃掉 hover 事件 → 深色反馈消失；且控件几何被其影响（见 pill 内的说明）。
     * 恢复方法：删掉上面两行 pillClickAction/pillRightClickAction，取消本注释块。
    component PillClickArea: MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true

        // 悬浮弹出 DankDash 面板（用自身 MouseArea 检测，覆盖整块组件；
        // 移开后的自动消失交给 PopoutManager 的悬浮跟踪）
        onContainsMouseChanged: {
            if (containsMouse)
                root.openDashTab("overview", true);
        }

        onClicked: mouse => mouse.button === Qt.RightButton ? root.openWeather() : root.openOverview()
    }
    */

    // ---------- time ----------
    property date now: new Date()

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    readonly property real textSize: Theme.barTextSize(barThickness, barConfig?.fontScale, barConfig?.maximizeWidgetText)
    // 2026-10-02：单元格宽 0.6→0.68（内置 Clock 为 0.6）。0.6 时 16px 字号的数字几乎占满
    // 单元格、相邻数字贴在一起显得挤；加宽后字距更透气，数字本身不缩小。
    readonly property real digitWidth: Math.round(textSize * 0.68)
    readonly property int iconSize: Theme.barIconSize(barThickness, -6, barConfig?.maximizeWidgetIcons, barConfig?.iconScale)

    readonly property string hoursText: {
        const h = root.now.getHours();
        if (SettingsData.use24HourClock)
            return String(h).padStart(2, "0");
        const h12 = h === 0 ? 12 : (h > 12 ? h - 12 : h);
        return SettingsData.padHours12Hour ? String(h12).padStart(2, "0") : String(h12);
    }
    readonly property string minutesText: String(root.now.getMinutes()).padStart(2, "0")

    readonly property string ampmText: {
        if (SettingsData.use24HourClock)
            return "";
        return root.now.getHours() >= 12 ? " PM" : " AM";
    }

    // vertical mode always pads to two digits so the cells stay aligned
    readonly property string hoursTextPadded: {
        const h = root.now.getHours();
        if (SettingsData.use24HourClock)
            return String(h).padStart(2, "0");
        const h12 = h === 0 ? 12 : (h > 12 ? h - 12 : h);
        return String(h12).padStart(2, "0");
    }

    // 日期顺序（2026-10-02：对齐 DMS「时间与天气」设置）：
    // 每部件 clockDateOrder > 全局 clockDateFormat > locale（内置同规则）
    readonly property bool dateFirst: {
        if (widgetData?.clockDateOrder !== undefined)
            return widgetData.clockDateOrder === "dateFirst";
        const f = SettingsData.clockDateFormat;
        if (f && f.length > 0)
            return f.indexOf("d") >= 0 && (f.indexOf("M") < 0 || f.indexOf("d") < f.indexOf("M"));
        const fmt = I18n.locale().dateFormat(Locale.ShortFormat);
        return fmt.indexOf("d") < fmt.indexOf("M");
    }

    // 秒 / 紧凑模式 / 温度单位（全部来自 DMS 设置，内置同款）
    readonly property string secondsText: String(root.now.getSeconds()).padStart(2, "0")
    readonly property bool showSeconds: SettingsData.showSeconds === true
    readonly property bool compactMode: widgetData?.clockCompactMode !== undefined ? widgetData.clockCompactMode : SettingsData.clockCompactMode
    readonly property string dateMonth: String(root.now.getMonth() + 1).padStart(2, "0")
    readonly property string dateDay: String(root.now.getDate()).padStart(2, "0")
    readonly property string datePairA: root.dateFirst ? root.dateDay : root.dateMonth
    readonly property string datePairB: root.dateFirst ? root.dateMonth : root.dateDay
    readonly property string dateFlat: root.dateFirst ? (root.dateDay + "-" + root.dateMonth) : (root.dateMonth + "-" + root.dateDay)

    // 横向布局的日期：DMS 设置了「日期格式」时按它渲染（内置同规则），否则用数字短格式
    readonly property string dateText: {
        if (SettingsData.clockDateFormat && SettingsData.clockDateFormat.length > 0)
            return root.now.toLocaleDateString(I18n.locale(), SettingsData.clockDateFormat);
        return root.dateFlat;
    }

    // ---------- weather ----------
    readonly property bool weatherOn: SettingsData.weatherEnabled
    readonly property bool weatherReady: WeatherService.weather?.available ?? false
    readonly property string weatherIcon: WeatherService.getWeatherIcon(WeatherService.weather?.wCode ?? 0)
    readonly property string weatherTempShort: root.weatherReady ? String(SettingsData.useFahrenheit ? WeatherService.weather.tempF : WeatherService.weather.temp) : "--"
    readonly property string weatherTempFull: root.weatherReady ? WeatherService.currentTempText(false) : "--"

    Component.onCompleted: WeatherService.addRef()
    Component.onDestruction: WeatherService.removeRef()

    // one split-flap style digit cell, fixed width to avoid jitter
    component DigitCell: StyledText {
        required property string value
        text: value
        font.pixelSize: root.textSize
        color: Theme.widgetTextColor
        width: root.digitWidth
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignBottom
    }

    // ---------- bar pills ----------
    // 悬浮面板 = DMS 的 DankDash 弹窗（概览页）——与点击打开的是同一个面板。
    // 通过 PopoutManager.requestHoverPopout 挂进悬浮机制：移开组件和面板即自动消失。
    // （旧的自绘天气小面板已按"注释不删除"原则移到本文件末尾注释块）

    // 2026-10-02 修复：DankDash 弹窗处于"关闭动画中"时，PopoutManager 对 hover 请求会因
    // `_isPopoutPresented()` 把 isClosing 也算作已展示而直接吞掉（不调用 _openPopout）→
    // 悬浮面板不弹（典型场景：从其他组件的悬浮面板移到本组件）。点击路径用 shouldBeVisible
    // 判断所以不受影响。对策：检测 isClosing，等关闭动画结束再请求（短重试）。
    property string _pendingTab: ""
    property bool _pendingHover: false
    property string _pendingTrigger: ""
    property int _pendingRetries: 0

    Timer {
        id: _dashRetryTimer

        interval: 120
        onTriggered: root.openDashTabNow(root._pendingTab, root._pendingHover, root._pendingTrigger, root._pendingRetries)
    }

    function openDashTab(tabId, hover, widgetHostId) {
        const loader = PopoutService.dankDashPopoutLoader;
        if (!loader)
            return;
        loader.active = true;
        Qt.callLater(() => root.openDashTabNow(tabId, hover, widgetHostId, 12));
    }

    function openDashTabNow(tabId, hover, widgetHostId, retries) {
        const dash = PopoutService.dankDashPopout;
        if (!dash)
            return;
        if (dash.isClosing && retries > 0) {
            root._pendingTab = tabId;
            root._pendingHover = hover;
            root._pendingTrigger = widgetHostId;
            root._pendingRetries = retries - 1;
            _dashRetryTimer.restart();
            return;
        }
        dash.requestTab(tabId);
        const pill = root.isVertical ? root.vPillRoot : root.hPillRoot;
        if (!pill)
            return;
        const globalPos = pill.mapToItem(null, 0, 0);
        const screen = root.parentScreen || Screen;
        const barPosition = root.axis?.edge === "left" ? 2 : (root.axis?.edge === "right" ? 3 : (root.axis?.edge === "top" ? 0 : 1));
        const pos = SettingsData.getPopupTriggerPosition(globalPos, screen, root.barThickness, pill.width, root.barSpacing, barPosition, root.barConfig);
        dash.setTriggerPosition(pos.x, pos.y, pos.width, root.section, screen, barPosition, root.barThickness, root.barSpacing, root.barConfig);
        if (hover)
            PopoutManager.requestHoverPopout(dash, undefined, widgetHostId || root.pluginId);
        else
            PopoutManager.requestPopout(dash, undefined, root.pluginId);
    }

    // 覆写基类：悬浮控制器悬停时会调用本函数 → 弹出 DankDash 概览页
    function triggerHoverPopout(widgetHostId) {
        root.openDashTab("overview", true, widgetHostId);
    }

    function openOverview() {
        root.openDashTab("overview", false);
    }

    function openWeather() {
        root.openDashTab("weather", false);
    }

    verticalBarPill: Component {
        Item {
            id: vPillItem

            // ⚠ 2026-10-02：内容根必须是带显式 implicit 尺寸的 Item（内置 Clock.qml 同款写法）。
            // 旧版直接把 Column 作为内容根：Column(positioner) 的 implicit 尺寸只读、自动计算，
            // 在 Loader 托管下会塌缩为 0/0 → BasePill 算出的可视高度只剩左右内边距（42×13），
            // 深色反馈和悬浮命中区都只剩一小条。旧结构见 git 历史 @ cc20a5c。
            implicitWidth: root.widgetThickness
            implicitHeight: vPillColumn.implicitHeight

            Component.onCompleted: root.vPillRoot = vPillItem

            Column {
                id: vPillColumn

                width: parent.width
                spacing: 0

                Row {
                    spacing: 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    DigitCell { value: root.hoursTextPadded.charAt(0) }
                    DigitCell { value: root.hoursTextPadded.charAt(1) }
                }

                // 2026-10-02：小时/分钟两组之间加 2px 小间距，避免四位数字糊成一块
                Item {
                    width: 1
                    height: 2
                }

                Row {
                    spacing: 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    DigitCell { value: root.minutesText.charAt(0) }
                    DigitCell { value: root.minutesText.charAt(1) }
                }

                // 2026-10-02：DMS 设置「显示秒」时补第三组数字（内置竖向同款；默认关闭，外观不变）
                Item {
                    width: 1
                    height: 2
                    visible: root.showSeconds
                }

                Row {
                    spacing: 0
                    visible: root.showSeconds
                    anchors.horizontalCenter: parent.horizontalCenter
                    DigitCell { value: root.secondsText.charAt(0) }
                    DigitCell { value: root.secondsText.charAt(1) }
                }

                Item {
                    width: root.digitWidth * 2
                    height: Theme.spacingM
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        width: parent.width * 0.6
                        height: 1
                        color: Theme.outlineButton
                        anchors.centerIn: parent
                    }
                }

                Row {
                    spacing: 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    DigitCell { value: root.datePairA.charAt(0); color: Theme.primary }
                    DigitCell { value: root.datePairA.charAt(1); color: Theme.primary }
                }

                Row {
                    spacing: 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    DigitCell { value: root.datePairB.charAt(0); color: Theme.primary }
                    DigitCell { value: root.datePairB.charAt(1); color: Theme.primary }
                }

                // 2026-10-02：日期与天气之间补一条同款分隔线（用户要求，规格与时间/日期分隔线一致）
                Item {
                    width: root.digitWidth * 2
                    height: Theme.spacingM
                    visible: root.weatherOn
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        width: parent.width * 0.6
                        height: 1
                        color: Theme.outlineButton
                        anchors.centerIn: parent
                    }
                }

                Item {
                    width: 1
                    height: Theme.spacingS
                    visible: root.weatherOn
                }

                DankIcon {
                    name: root.weatherIcon
                    size: root.iconSize
                    color: Theme.widgetIconColor
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.weatherOn
                }

                StyledText {
                    text: root.weatherTempShort
                    font.pixelSize: root.textSize
                    color: Theme.widgetTextColor
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.weatherOn
                }
            }
        }
    }

    horizontalBarPill: Component {
        Item {
            id: hPillItem

            // 与竖排同理（2026-10-02）：内容根用带显式 implicit 尺寸的 Item 包裹。
            implicitWidth: hPillRow.implicitWidth
            implicitHeight: root.widgetThickness

            Component.onCompleted: root.hPillRoot = hPillItem

            Row {
                id: hPillRow

                spacing: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    text: root.hoursText + ":" + root.minutesText + (root.showSeconds ? ":" + root.secondsText : "") + root.ampmText
                    font.pixelSize: root.textSize
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "•"
                    visible: !root.compactMode
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.outlineButton
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: root.dateText
                    visible: !root.compactMode
                    font.pixelSize: root.textSize
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    width: Theme.spacingS
                    height: 1
                    visible: root.weatherOn
                }

                DankIcon {
                    name: root.weatherIcon
                    size: root.iconSize
                    color: Theme.widgetIconColor
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.weatherOn
                }

                StyledText {
                    text: root.weatherTempFull
                    font.pixelSize: root.textSize
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.weatherOn
                }
            }
        }
    }

    // 临时诊断代码已于 2026-10-02 移除（定位结束后清理）。如再需调试，参考 AGENTS.md
    // 「调试手段」一节：Quickshell.Io 的 Process 写 /tmp 文件（插件里 console.log 会被吞）。
}

/* ─────────────────────────────────────────────────────────────────────────────
 * 旧版自绘天气悬浮小面板（2026-10-02，已被 DankDash 概览悬浮面板取代）。
 * 如需恢复：把下面整段作为 popoutContent: Component { ... } 放回插件根。
 *     // 悬浮面板：时间 + 日期 + 当前天气（与其他组件的悬浮面板机制一致，移开自动消失）
 *     popoutWidth: 220
 *     popoutHeight: 190
 * 
 *     popoutContent: Component {
 *         Item {
 *             // PluginPopout 将面板高度绑定到根 Item 的 implicitHeight，必须显式给出
 *             implicitHeight: panelColumn.implicitHeight + Theme.spacingM * 2
 * 
 *             Column {
 *                 id: panelColumn
 * 
 *                 anchors.left: parent.left
 *                 anchors.right: parent.right
 *                 anchors.top: parent.top
 *                 anchors.margins: Theme.spacingM
 *                 spacing: 8
 * 
 *                 StyledText {
 *                     text: root.hoursText + ":" + root.minutesText + root.ampmText
 *                     font.pixelSize: 32
 *                     color: Theme.primary
 *                     anchors.horizontalCenter: parent.horizontalCenter
 *                 }
 * 
 *                 StyledText {
 *                     text: Qt.formatDate(root.now, "yyyy年M月d日 dddd")
 *                     font.pixelSize: 12
 *                     color: Theme.surfaceVariantText
 *                     anchors.horizontalCenter: parent.horizontalCenter
 *                 }
 * 
 *                 Rectangle {
 *                     width: parent.width * 0.4
 *                     height: 1
 *                     color: Theme.outlineButton
 *                     anchors.horizontalCenter: parent.horizontalCenter
 *                     visible: root.weatherOn
 *                 }
 * 
 *                 Row {
 *                     spacing: 10
 *                     anchors.horizontalCenter: parent.horizontalCenter
 *                     visible: root.weatherOn && root.weatherReady
 * 
 *                     DankIcon {
 *                         name: root.weatherIcon
 *                         size: 26
 *                         color: Theme.primary
 *                         anchors.verticalCenter: parent.verticalCenter
 *                     }
 * 
 *                     StyledText {
 *                         text: root.weatherTempFull
 *                         font.pixelSize: 16
 *                         color: Theme.surfaceText
 *                         anchors.verticalCenter: parent.verticalCenter
 *                     }
 * 
 *                     StyledText {
 *                         text: WeatherService.getWeatherCondition(WeatherService.weather.wCode)
 *                         font.pixelSize: 12
 *                         color: Theme.surfaceVariantText
 *                         anchors.verticalCenter: parent.verticalCenter
 *                     }
 *                 }
 *             }
 *         }
 *     }
 * 
 *
 * ───────────────────────────────────────────────────────────────────────────── */
