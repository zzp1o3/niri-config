import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.Common
import qs.Modules.DankBar.Widgets
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

// ─────────────────────────────────────────────────────────────────────────────
// 媒体组件：在内置 Media 竖排布局的基础上做最小改动。
// 原版竖排结构（逐字保留）：
//   ├── AudioVisualization 20×20 频谱（cava），点击打开 DankDash 媒体页
//   └── 24×24 播放/暂停圆钮（左键播放暂停 / 中键上一首或倒带 / 右键下一首）
// 本插件唯一改动：下面的 24×24 圆钮改为显示专辑封面，鼠标悬浮在封面上时
// 浮现原样的播放/暂停按钮（含原版的左/中/右键行为）；滚轮调音量/切歌逻辑
// 与原版逐字相同。
// 原则：功能只注释、不删除；旧版实现保留在本文件末尾的注释块里。
// ─────────────────────────────────────────────────────────────────────────────
PluginComponent {
    id: root

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool playerAvailable: activePlayer !== null
    readonly property bool hoverPreview: MprisController.isFirefoxYoutubeHoverPreview(activePlayer)
    readonly property bool isPlaying: playerAvailable && activePlayer.playbackState === MprisPlaybackState.Playing && !hoverPreview

    // 专辑封面：TrackArtService 解析（外链封面自动下载缓存），回退 MPRIS 原始 URL
    readonly property string rawArtUrl: {
        const p = activePlayer;
        if (!p)
            return "";
        if (p.trackArtUrl)
            return p.trackArtUrl;
        const m = p.metadata;
        return m && m["mpris:artUrl"] ? m["mpris:artUrl"].toString() : "";
    }
    readonly property string coverSource: TrackArtService.resolvedArtUrl || rawArtUrl

    property string lastValidArt: ""
    readonly property string displayedArt: {
        const src = root.coverSource;
        if (src !== "")
            return src;
        return root.playerAvailable ? root.lastValidArt : "";
    }

    // ⚠ 2026-10-02：这两个属性此前漏声明，导致下方 pill 内容里的
    // `root.vPillRoot = vPillItem` 静默失败（QML 赋值到不存在的属性，插件日志被吞），
    // openDashTab 里 `if (!pill) return` 永远提前返回 → 悬浮面板完全弹不出来。
    property var vPillRoot: null
    property var hPillRoot: null

    // 插件设置（DMS 设置 → 插件 → 媒体封面；见 MediaCoverSettings.qml）。
    // 未设置任何项时全部取默认值，行为与加设置页之前完全一致。
    readonly property int coverSize: {
        const v = parseInt(pluginData.coverSize);
        return (v === 20 || v === 24 || v === 28) ? v : 24;
    }
    readonly property bool revealPlayButton: pluginData.revealPlayButton !== false
    readonly property bool hoverPopoutEnabled: pluginData.hoverPopout !== false
    readonly property bool spectrumOpensPanel: pluginData.spectrumOpensPanel !== false

    // 2026-10-02：给根组件显式 visible 绑定。DMS 的部件"隐藏/显示"是通过 WidgetHost 里一条
    // Binding（when: 部件 enabled=false, property: "visible", value: false,
    // restoreMode: RestoreBinding）实现的；此处显式绑定可保证恢复时回到本绑定
    // （effectiveVisible 恒为 true，插件不设 visibilityCommand）→ 隐藏后再显示能正常回来。
    visible: root.effectiveVisible

    // ── 滚轮调音量/切歌：与内置 Media.qml 逐字相同 ──
    property real scrollAccumulatorY: 0
    property real touchpadThreshold: 100

    function handleWheel(wheelEvent) {
        if (SettingsData.audioScrollMode === "nothing")
            return;

        if (SettingsData.audioScrollMode === "volume") {
            if (!playerAvailable || !activePlayer.volumeSupported)
                return;

            wheelEvent.accepted = true;

            const deltaY = wheelEvent.angleDelta.y;
            const isMouseWheelY = Math.abs(deltaY) >= 120 && (Math.abs(deltaY) % 120) === 0;

            const currentVolume = activePlayer.volume * 100;

            let newVolume = currentVolume;
            if (isMouseWheelY) {
                if (deltaY > 0) {
                    newVolume = Math.min(100, currentVolume + SettingsData.audioWheelScrollAmount);
                } else if (deltaY < 0) {
                    newVolume = Math.max(0, currentVolume - SettingsData.audioWheelScrollAmount);
                }
            } else {
                scrollAccumulatorY += deltaY;
                if (Math.abs(scrollAccumulatorY) >= touchpadThreshold) {
                    if (scrollAccumulatorY > 0) {
                        newVolume = Math.min(100, currentVolume + 1);
                    } else {
                        newVolume = Math.max(0, currentVolume - 1);
                    }
                    scrollAccumulatorY = 0;
                }
            }

            activePlayer.volume = newVolume / 100;
        } else if (SettingsData.audioScrollMode === "song") {
            if (!activePlayer)
                return;

            wheelEvent.accepted = true;

            const deltaY = wheelEvent.angleDelta.y;
            const isMouseWheelY = Math.abs(deltaY) >= 120 && (Math.abs(deltaY) % 120) === 0;

            if (isMouseWheelY) {
                if (deltaY > 0) {
                    MprisController.previousOrRewind();
                } else {
                    MprisController.next();
                }
            } else {
                scrollAccumulatorY += deltaY;
                if (Math.abs(scrollAccumulatorY) >= touchpadThreshold) {
                    if (scrollAccumulatorY > 0) {
                        MprisController.previousOrRewind();
                    } else {
                        MprisController.next();
                    }
                    scrollAccumulatorY = 0;
                }
            }
        }
    }

    // 频谱区点击：打开 DankDash 媒体页（与原版一致，直接复用同一个弹窗以支持悬浮跟踪）
    // 旧 IPC 写法已注释：Quickshell.execDetached(["dms", "ipc", "call", "dash", "toggle", "media"])
    function openMediaPopout() {
        root.openDashTab("media", false);
    }

    // 悬浮面板 = DMS 的 DankDash 弹窗（媒体页）——点击频谱打开的就是这个面板，
    // 现在悬浮也会弹出它：通过 PopoutManager.requestHoverPopout 挂进悬浮机制，
    // 移开组件和面板即自动消失。（旧的自绘专辑面板已按"注释不删除"原则移到文件末尾）

    // 2026-10-02 修复：DankDash 弹窗处于"关闭动画中"时，PopoutManager 对 hover 请求会因
    // `_isPopoutPresented()` 把 isClosing 也算作已展示而直接吞掉（不调用 _openPopout）→
    // 悬浮面板不弹（典型场景：从时钟的悬浮面板移到媒体组件）。点击路径用 shouldBeVisible
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

    // 覆写基类：悬浮控制器悬停时会调用本函数 → 弹出 DankDash 媒体页。
    // 可用插件设置 hoverPopout 关闭悬浮弹面板（关闭后悬浮只显示深色反馈）。
    function triggerHoverPopout(widgetHostId) {
        if (!root.hoverPopoutEnabled)
            return;
        root.openDashTab("media", true, widgetHostId);
    }

    verticalBarPill: Component {
        Item {
            id: vPillItem

            // 与原版一致：无播放器时整个 pill 收起（封面边长取插件设置 coverSize，默认 24）
            implicitWidth: root.playerAvailable ? root.coverSize : 0
            implicitHeight: root.playerAvailable ? (20 + Theme.spacingXS + root.coverSize) : 0
            opacity: root.playerAvailable ? 1 : 0

            Behavior on implicitWidth {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Behavior on implicitHeight {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }

            Component.onCompleted: root.vPillRoot = vPillItem

            /* 旧版（2026-10-02 12:13–12:45）：整块 pill 自绘 hover 检测 → 打开媒体面板。
             * 弃用原因：hoverEnabled 的 MouseArea 位于 BasePill 的 mouseArea（z:-1）之上，
             * 会吃掉 hover 事件 → 深色反馈消失（且该 MouseArea 需要 root.vPillRoot 存在，
             * 当时该属性漏声明，等同于完全失效）。
             * 悬浮弹面板改走栏控制器（triggerHoverPopout），与内置组件机制一致。
             * 恢复方法：取消本注释块。
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onContainsMouseChanged: {
                    if (containsMouse)
                        root.openDashTab("media", true);
                }
            }
            */

            // 滚轮走 BasePill 的 wheel 信号转发（与内置 Media 一致）
            readonly property var _pill: {
                let p = parent;
                while (p && p.enableBackgroundHover === undefined)
                    p = p.parent;
                return p;
            }

            Connections {
                target: _pill
                function onWheel(wheelEvent) {
                    root.handleWheel(wheelEvent);
                }
            }

            /* WheelHandler 方案在此场景不触发，弃用——保留备查：
            WheelHandler {
                onWheel: event => root.handleWheel(event)
            }
            */

            Column {
                spacing: Theme.spacingXS
                anchors.centerIn: parent

                // ── 原版：20×20 频谱 / 音符，点击打开媒体弹窗 ──
                Item {
                    width: 20
                    height: 20
                    anchors.horizontalCenter: parent.horizontalCenter

                    AudioVisualization {
                        anchors.fill: parent
                        visible: CavaService.cavaAvailable && SettingsData.audioVisualizerEnabled
                    }

                    DankIcon {
                        anchors.fill: parent
                        name: "music_note"
                        size: 20
                        color: Theme.primary
                        visible: !CavaService.cavaAvailable || !SettingsData.audioVisualizerEnabled
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.spectrumOpensPanel)
                                root.openMediaPopout();
                        }
                    }
                }

                // ── 本插件的唯一改动：原 24×24 播放/暂停圆钮 → 专辑封面，悬浮时浮现原按钮 ──
                // 尺寸可由插件设置调整（coverSize，默认 24 = 原版）
                Item {
                    width: root.coverSize
                    height: root.coverSize
                    anchors.horizontalCenter: parent.horizontalCenter

                    // 封面（圆形裁剪，替换原按钮的常驻外观）
                    ClippingRectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Theme.primaryHover

                        Image {
                            id: art

                            anchors.fill: parent
                            asynchronous: true
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            mipmap: true
                            sourceSize.width: Math.max(width * 2, 64)
                            sourceSize.height: Math.max(height * 2, 64)
                            visible: status === Image.Ready
                            source: root.displayedArt
                            onStatusChanged: {
                                if (status === Image.Ready && source !== "")
                                    root.lastValidArt = source;
                            }
                        }

                        // 无封面时的占位（与原按钮同款底色 + 音符）
                        DankIcon {
                            name: "music_note"
                            size: Math.round(root.coverSize * 0.58)
                            color: Theme.primary
                            anchors.centerIn: parent
                            visible: art.status !== Image.Ready
                        }

                        // 悬浮时浮现：原版 24×24 播放/暂停按钮，外观与行为逐字保留
                        Rectangle {
                            id: originalButton

                            anchors.fill: parent
                            radius: height / 2
                            color: root.isPlaying ? Theme.primary : Theme.primaryHover
                            // 悬停浮现：跟随 BasePill 的悬浮态（本 MouseArea 不能再开 hoverEnabled）；
                            // 可用插件设置 revealPlayButton 关闭
                            opacity: (root.revealPlayButton && (vPillItem._pill ? vPillItem._pill.isMouseHovered : false)) ? 1 : 0
                            visible: opacity > 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }

                            DankIcon {
                                anchors.centerIn: parent
                                name: root.isPlaying ? "pause" : "play_arrow"
                                size: Math.round(root.coverSize * 0.58)
                                color: root.isPlaying ? Theme.background : Theme.primary
                            }
                        }
                    }

                    // 悬浮 + 点击：左键播放暂停 / 中键上一首(或倒带) / 右键下一首（原版行为）
                    MouseArea {
                        id: coverHover

                        anchors.fill: parent
                        // 2026-10-02：必须保持 false——hoverEnabled 会吃掉 BasePill 的 hover
                        // 事件（深色反馈/悬浮弹面板失效）；点击不需要 hoverEnabled。
                        hoverEnabled: false
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.playerAvailable
                        onClicked: mouse => {
                            if (!root.activePlayer)
                                return;
                            if (mouse.button === Qt.LeftButton) {
                                root.activePlayer.togglePlaying();
                            } else if (mouse.button === Qt.MiddleButton) {
                                MprisController.previousOrRewind();
                            } else if (mouse.button === Qt.RightButton) {
                                MprisController.next();
                            }
                        }
                    }
                }
            }
        }
    }

    // 横排：简化版（当前仅使用竖排栏；如需内置横排完整样式请改用内置 music 组件）
    horizontalBarPill: Component {
        Item {
            id: hPillItem

            implicitWidth: root.playerAvailable ? root.coverSize + Theme.spacingS + 120 : 0
            implicitHeight: root.playerAvailable ? root.coverSize : 0
            opacity: root.playerAvailable ? 1 : 0

            /* 旧版（2026-10-02 12:13–12:45）：整块 pill 自绘 hover 检测 → 打开媒体面板。
             * 弃用原因：hoverEnabled 的 MouseArea 位于 BasePill 的 mouseArea（z:-1）之上，
             * 会吃掉 hover 事件 → 深色反馈消失（且该 MouseArea 需要 root.vPillRoot 存在，
             * 当时该属性漏声明，等同于完全失效）。
             * 悬浮弹面板改走栏控制器（triggerHoverPopout），与内置组件机制一致。
             * 恢复方法：取消本注释块。
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onContainsMouseChanged: {
                    if (containsMouse)
                        root.openDashTab("media", true);
                }
            }
            */

            Component.onCompleted: root.hPillRoot = hPillItem

            readonly property var _pill: {
                let p = parent;
                while (p && p.enableBackgroundHover === undefined)
                    p = p.parent;
                return p;
            }

            Connections {
                target: _pill
                function onWheel(wheelEvent) {
                    root.handleWheel(wheelEvent);
                }
            }

            /* WheelHandler 方案在此场景不触发，弃用——保留备查：
            WheelHandler {
                onWheel: event => root.handleWheel(event)
            }
            */

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingS
                visible: root.playerAvailable

                Item {
                    width: root.coverSize
                    height: root.coverSize
                    anchors.verticalCenter: parent.verticalCenter

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Theme.primaryHover

                        Image {
                            id: hArt

                            anchors.fill: parent
                            asynchronous: true
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            mipmap: true
                            sourceSize.width: 64
                            sourceSize.height: 64
                            visible: status === Image.Ready
                            source: root.displayedArt
                        }

                        DankIcon {
                            name: "music_note"
                            size: Math.round(root.coverSize * 0.58)
                            color: Theme.primary
                            anchors.centerIn: parent
                            visible: hArt.status !== Image.Ready
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: root.isPlaying ? Theme.primary : Theme.primaryHover
                            // 悬停浮现：跟随 BasePill 的悬浮态（本 MouseArea 不能再开 hoverEnabled）；
                            // 可用插件设置 revealPlayButton 关闭
                            opacity: (root.revealPlayButton && (hPillItem._pill ? hPillItem._pill.isMouseHovered : false)) ? 1 : 0
                            visible: opacity > 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.shortDuration
                                    easing.type: Theme.standardEasing
                                }
                            }

                            DankIcon {
                                anchors.centerIn: parent
                                name: root.isPlaying ? "pause" : "play_arrow"
                                size: Math.round(root.coverSize * 0.58)
                                color: root.isPlaying ? Theme.background : Theme.primary
                            }
                        }
                    }

                    MouseArea {
                        id: hCoverHover

                        anchors.fill: parent
                        // 同竖排：hoverEnabled 会吃掉 BasePill 的 hover 事件，保持 false
                        hoverEnabled: false
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.playerAvailable
                        onClicked: mouse => {
                            if (!root.activePlayer)
                                return;
                            if (mouse.button === Qt.LeftButton) {
                                root.activePlayer.togglePlaying();
                            } else if (mouse.button === Qt.MiddleButton) {
                                MprisController.previousOrRewind();
                            } else if (mouse.button === Qt.RightButton) {
                                MprisController.next();
                            }
                        }
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    width: 120

                    StyledText {
                        width: parent.width
                        text: root.activePlayer?.trackTitle || ""
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        color: Theme.widgetTextColor
                        elide: Text.ElideRight
                        visible: root.activePlayer?.trackTitle !== ""
                    }

                    StyledText {
                        width: parent.width
                        text: root.activePlayer?.trackArtist || ""
                        font.pixelSize: Theme.barTextSize(root.barThickness, (root.barConfig?.fontScale ?? 1) * 0.82, root.barConfig?.maximizeWidgetText)
                        color: Theme.widgetTextColor
                        opacity: 0.72
                        elide: Text.ElideRight
                        visible: root.activePlayer?.trackArtist !== ""
                    }
                }
            }
        }
    }

    /* ─────────────────────────────────────────────────────────────────────────
     * 旧版实现一（2026-10-02 上午）：单行三按钮悬浮版
     * 悬浮浮现 上一首/播放暂停/下一首 三个圆钮；整封面点击=播放暂停。
     * ─────────────────────────────────────────────────────────────────────────
    Rectangle {
        id: scrim
        anchors.fill: parent
        radius: coverRoot.width / 2
        color: Qt.rgba(0, 0, 0, 0.45)
        opacity: coverRoot.interactive && hoverHandler.hovered && root.playerAvailable ? 1 : 0
        visible: opacity > 0

        Row {
            anchors.centerIn: parent
            spacing: Math.max(2, Math.round(coverRoot.width * 0.04))

            Rectangle {
                width: Math.round(coverRoot.width * 0.3)
                height: width
                radius: width / 2
                color: prevArea.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : "transparent"
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    name: "skip_previous"
                    size: Math.round(parent.width * 0.62)
                    color: "#ffffff"
                    anchors.centerIn: parent
                }

                MouseArea {
                    id: prevArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.PointingHandCursor
                    enabled: scrim.opacity > 0.5
                    onClicked: MprisController.previousOrRewind()
                }
            }

            Rectangle {
                width: Math.round(coverRoot.width * 0.42)
                height: width
                radius: width / 2
                color: playArea.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.12)
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    name: root.isPlaying ? "pause" : "play_arrow"
                    size: Math.round(parent.width * 0.62)
                    color: "#ffffff"
                    anchors.centerIn: parent
                }

                MouseArea {
                    id: playArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.PointingHandCursor
                    enabled: scrim.opacity > 0.5
                    onClicked: root.activePlayer?.togglePlaying()
                }
            }

            Rectangle {
                width: Math.round(coverRoot.width * 0.3)
                height: width
                radius: width / 2
                color: nextArea.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : "transparent"
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    name: "skip_next"
                    size: Math.round(parent.width * 0.62)
                    color: "#ffffff"
                    anchors.centerIn: parent
                }

                MouseArea {
                    id: nextArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.PointingHandCursor
                    enabled: scrim.opacity > 0.5
                    onClicked: MprisController.next()
                }
            }
        }
    }
    * ─────────────────────────────────────────────────────────────────────────

    * ─────────────────────────────────────────────────────────────────────────
     * 旧版实现二（2026-10-02 下午）：大圆形封面叠层版（32px 圆形封面，
     * 悬浮浮现居中单按钮；频谱叠在封面内下沿 + 深色底衬）。
     * 恢复方法：把 verticalBarPill 里的 Column 换回单個 CoverArt(32px)，
     * CoverArt 用 ClippingRectangle + radius: width/2，内部含
     * Image / DankIcon 占位 / AudioVisualization 叠层 / scrim / MouseArea。
     * 详细代码见 git 历史：plugins/zzpMediaCover/MediaCover.qml @ 4668cdf
     * ───────────────────────────────────────────────────────────────────────── */

    // 临时诊断代码已于 2026-10-02 移除（定位结束后清理）。如再需调试，参考 AGENTS.md
    // 「调试手段」一节：Quickshell.Io 的 Process 写 /tmp 文件（插件里 console.log 会被吞）。
}

/* ─────────────────────────────────────────────────────────────────────────────
 * 旧版自绘媒体悬浮面板（2026-10-02，DankAlbumArt+控制按钮，已被 DankDash 媒体页悬浮面板取代）。
 * 如需恢复：把下面整段作为 popoutContent: Component { ... } 放回插件根（并补 popoutWidth/Height）。
 *     // 悬浮面板：DMS 悬浮控制器检测到 popoutContent 后会在悬停时自动调用
 *     // triggerHoverPopout（与其他组件的悬浮面板机制一致）
 *     popoutWidth: 240
 *     popoutHeight: 286
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
 *                 spacing: Theme.spacingS
 * 
 *                 DankAlbumArt {
 *                     width: 110
 *                     height: 110
 *                     anchors.horizontalCenter: parent.horizontalCenter
 *                     activePlayer: root.activePlayer
 *                 }
 * 
 *                 StyledText {
 *                     width: parent.width
 *                     text: root.activePlayer?.trackTitle || ""
 *                     font.pixelSize: 15
 *                     color: Theme.surfaceText
 *                     elide: Text.ElideRight
 *                     horizontalAlignment: Text.AlignHCenter
 *                     visible: root.activePlayer?.trackTitle !== ""
 *                 }
 * 
 *                 StyledText {
 *                     width: parent.width
 *                     text: root.activePlayer?.trackArtist || ""
 *                     font.pixelSize: 12
 *                     color: Theme.surfaceVariantText
 *                     elide: Text.ElideRight
 *                     horizontalAlignment: Text.AlignHCenter
 *                     visible: root.activePlayer?.trackArtist !== ""
 *                 }
 * 
 *                 Row {
 *                     spacing: Theme.spacingM
 *                     anchors.horizontalCenter: parent.horizontalCenter
 * 
 *                     DankActionButton {
 *                         buttonSize: 44
 *                         iconName: "skip_previous"
 *                         iconSize: 26
 *                         iconColor: Theme.surfaceText
 *                         anchors.verticalCenter: parent.verticalCenter
 *                         onClicked: MprisController.previousOrRewind()
 *                     }
 * 
 *                     Rectangle {
 *                         width: 52
 *                         height: 52
 *                         radius: width / 2
 *                         color: root.isPlaying ? Theme.primary : Theme.primaryHover
 *                         anchors.verticalCenter: parent.verticalCenter
 * 
 *                         DankIcon {
 *                             anchors.centerIn: parent
 *                             name: root.isPlaying ? "pause" : "play_arrow"
 *                             size: 30
 *                             color: root.isPlaying ? Theme.background : Theme.primary
 *                         }
 * 
 *                         MouseArea {
 *                             anchors.fill: parent
 *                             cursorShape: Qt.PointingHandCursor
 *                             onClicked: root.togglePlaying()
 *                         }
 *                     }
 * 
 *                     DankActionButton {
 *                         buttonSize: 44
 *                         iconName: "skip_next"
 *                         iconSize: 26
 *                         iconColor: Theme.surfaceText
 *                         anchors.verticalCenter: parent.verticalCenter
 *                         onClicked: MprisController.next()
 *                     }
 *                 }
 *             }
 *         }
 *     }
 * 
 *
 * ───────────────────────────────────────────────────────────────────────────── */
