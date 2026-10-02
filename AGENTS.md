# AGENTS.md — niri + DankMaterialShell 环境（给修改本机配置的 AI 代理）

> 面向 AI 代理的交接文档。修改前必读「用户铁律」一节。

## 环境总览

| 项 | 值 |
|---|---|
| 合成器 | niri 26.04，主配置 `~/.config/niri/config.kdl` |
| 桌面 shell | DankMaterialShell (DMS) **v1.6.2**，Go 静态二进制 `/usr/bin/dms` |
| DMS 运行方式 | `systemd-run --user --collect --unit=dms-manual dms run`（transient unit；用户登录时由 niri spawn-at-startup 拉起则无 unit） |
| DMS 日志 | `journalctl --user -u dms-manual` |
| DMS 运行时 QML | `/run/user/1000/danklinux-shell/<hash>/`（重启后重新解压，**只读**，可直接对照运行版源码） |
| DMS 源码参考 | `git clone --depth 1 --branch v1.6.2 --recurse-submodules https://github.com/AvengeMedia/DankMaterialShell.git`（子模块 dank-qml-common 含 DankCircularImage/ClippingRectangle 等） |
| DMS 用户配置 | `~/.config/DankMaterialShell/`（settings.json、plugin_settings.json、plugins/） |
| 配置 git 仓库 | `~/niri-config`（远端 `github.com/zzp1o3/niri-config`；`./sync.sh` 一键同步+推送，支持补推积压提交；GitHub 需代理 `127.0.0.1:7897`，git 已全局配好） |
| 用户 | zzp，简体中文交流 |

## 自研插件（`~/.config/DankMaterialShell/plugins/`）

全部为 DMS widget 插件（plugin.json + QML），需在 `plugin_settings.json` 里 `"enabled": true` 才会加载（`dms ipc call plugin-scan list` 可看 loaded/unloaded）。

| 插件 | 文件 | 说明 |
|---|---|---|
| zzpClockWeather | ClockWeather.qml | 时钟+日期+天气。竖排为原版样式（数字堆叠+分隔线+月相+温度），**视觉不可改动**（曾因缩字被用户否决，原版在 git 历史 163790c） |
| zzpMediaCover | MediaCover.qml + MediaCoverSettings.qml | 内置媒体组件的最小改动版：20×20 Cava 频谱（原样）+ 封面替代播放钮（默认 24×24），悬浮浮现原样播放/暂停按钮（左键 toggle/中键 prevOrRewind/右键 next），滚轮逻辑与内置逐字相同。**2026-10-02 起带自己的设置页**（DMS 设置→插件→媒体封面；plugin.json 已声明 `settings` + `permissions: settings_read/write`）：`coverSize`(20/24/28) / `revealPlayButton` / `hoverPopout` / `spectrumOpensPanel`，默认值=原版行为；值存 plugin_settings.json，组件内经 `pluginData.<key>` 读取并热更新 |
| zzpUserAvatar | UserAvatar.qml | 底部圆形头像（AccountsService），点击打开控制中心（`blurBarWindow.triggerControlCenter()`），并自注册为 `controlCenterButtonRef`（保证 `dms ipc call control-center toggle`/Mod+Shift+C 可用） |
| zzpWorkspaceDots | WorkspaceDots.qml | macOS 风格工作区圆点（替代内置胶囊）：NiriService.allWorkspaces 过滤本屏、switchToWorkspace、圆点三态 |
| zzpPerfMonitor | PerfMonitor.qml | CPU/内存/GPU 监控（竖排已紧凑化 ×0.78） |
| zzpLauncher | Launcher.qml | 内置启动器按钮的**可管理替代**（2026-10-02 新建）：同一 LauncherLogo/左键开应用抽屉/右键 niri 概览/悬浮 hover 弹应用抽屉，根带显式 visible 绑定 |
| zzpBattery | Battery.qml | 内置电池组件的**可管理替代**（2026-10-02 新建）：图标/环表与内置一致（同一 BatteryService/BatteryMeter），点击打开内置电池面板（`PopoutService.toggleBattery`），根带显式 `visible` 绑定 → 可在 DMS 设置中正常隐藏/显示。**注意：内置 `battery` 组件隐藏后无法恢复（见踩坑），需替换时把栏配置里的 `battery` 换成 `zzpBattery`（新增插件需重启 DMS 生效）** |
| zzpLegionTuner | LegionTuner.qml | 拯救者性能调节（2026-10-02 重构）：**顶部仪表盘**（CPU 占用/频率/温度/功耗 RAPL、GPU 占用/频率/温度/功耗、风扇转速、电池）+ 性能模式三档（powerprofilesctl）+ 双屏刷新率 + 键盘背光/FnLock + 电池养护/USB 常供电/CPU Boost + **风扇曲线**（10 档速度点读写 + 安静/均衡/性能预设）。布局用等宽分段控件（SegmentRow）填满行宽。root 写入走免密助手 `~/.local/bin/zzp-legion-led`，回退 pkexec。**功耗墙 PL1/PL2/cTGP 控件已按用户要求移除**（能力仍在助手脚本里：pl1/pl2/ctgp）|

栏布局（settings.json → barConfigs[0]）：leftWidgets=[zzpLauncher, zzpWorkspaceDots, focusedWindow, systemTray, zzpMediaCover]；centerWidgets=[zzpClockWeather]；rightWidgets=[notificationButton, zzpPerfMonitor, zzpBattery, zzpLegionTuner, zzpUserAvatar]。**2026-10-02：launcherButton→zzpLauncher、battery→zzpBattery 已替换**（内置版本在 DMS 显隐管理下有卡死缺陷，见踩坑；zzpBattery 保留每部件设置如 batteryStyle=ring）。

## ✅ 悬浮面板问题（2026-10-02 已解决，存档备查）

自研插件的"悬浮 → 弹 DankDash 面板、移开自动消失"曾长期异常，2026-10-02 已定位修复并通过实机日志验证。**两个插件是两个独立 bug**：

1. **zzpClockWeather：内容几何塌缩**。pill 内容根直接用了 `Column`（positioner），其 `implicitWidth/implicitHeight` 是只读自动计算值，在 BasePill 的 `contentLoader` 托管下被算成 **0×0** → BasePill 算出的 pill 只剩"内边距高度"（实测 42×13）→ 深色反馈矩形和悬浮命中区都只剩一条窄边（用户描述："只有顶部一点地方有深色反馈/能弹面板"）。数字仍正常显示属**溢出渲染**（QML 默认不裁剪子项），即"看起来正常、几何全错"。
   修复：按内置 `Clock.qml` 写法，**内容根改为带显式 implicit 尺寸的 `Item`**（竖排 `implicitHeight: vPillColumn.implicitHeight`；横排 `implicitWidth: hPillRow.implicitWidth`）。修复后 pill = 41×151（正常值）。
2. **zzpMediaCover：属性漏声明**。`root.vPillRoot = vPillItem` 给未声明的属性赋值 → 插件内**静默失败**（QML 运行时错误随 console 一起被吞）→ `openDashTab` 首行 `if (!pill) return` 永远提前返回 → 任何路径都弹不出面板。
   修复：补上 `property var vPillRoot: null` / `property var hPillRoot: null`。

另修掉一个共性问题：**pill 内容区里 `hoverEnabled: true` 的 MouseArea 会截走 BasePill 用于深色反馈的 hover 事件**（BasePill 的 mouseArea 在 `z:-1`，Qt 的 hover 只发给最上层接受者）。已改回内置组件标准通路（当前代码状态）：

- **点击** → `pillClickAction` / `pillRightClickAction`（BasePill 的 mouseArea 转发，附带标准 ripple 水波）；
- **悬浮** → 栏控制器（`DankBarHoverController`，150ms 意图延迟）→ 插件覆写的 `triggerHoverPopout(widgetHostId)` → `openDashTab(...)` → `PopoutManager.requestHoverPopout`（hover 模式，移开自动消失由弹窗自身的 `PopoutHoverDismiss` 机制负责，与内置组件同路径）；
- MediaCover 封面"悬浮浮现播放按钮" → 改绑 BasePill 的 `isMouseHovered`，其 `coverHover` MouseArea 保持 `hoverEnabled: false`（点击不受影响）。

**验证方法（已实测）**：临时加 Process→/tmp 日志，悬浮时钟/媒体各一次，日志应出现 `openDashTab(overview/media, hover=true) pill=ok` → `popout dash=true tab=overview/media trig=zzpClockWeather/zzpMediaCover`；鼠标移到面板上时面板保持（不消失），移开组件与面板后 `dash=false`。控制器偶尔对同一次悬浮发两次打开请求，被 PopoutManager 同 triggerId 去重吸收，无可见影响。

## 关键技术事实（踩坑记录，务必遵守）

- **插件 pill 内容根必须是带显式 implicit 尺寸的 `Item`**：把 `Column`/`Row`（positioner）直接当 `verticalBarPill`/`horizontalBarPill` 的根，其 implicit 尺寸在 BasePill 的 Loader 托管下会塌缩为 0×0 → pill 只剩内边距高度（如 42×13）→ 深色反馈/悬浮命中/弹窗定位全错（内置 Clock.qml 就是 `Item { implicitWidth/implicitHeight: ... }` 包一层）。
- **插件里给未声明的属性赋值会静默失败**（QML 运行时错误随 console 一起被吞）：`root.foo = x` 前必须先 `property var foo`。排查靠 Process 写 /tmp 日志。
- **pill 内容里不要放 `hoverEnabled: true` 的 MouseArea**：它位于 BasePill 的 mouseArea（z:-1）之上，会把 hover 事件全部吃掉（深色反馈消失）。点击用 `pillClickAction`/`pillRightClickAction`，悬浮交给栏控制器 + 覆写 `triggerHoverPopout`。
- **DMS 部件"隐藏/显示"的显隐恢复规则**（2026-10-02 实测确认）：属性**原本有 `visible` 绑定**的组件隐藏后能恢复（自研插件已全部加 `visible: root.effectiveVisible`，实测 5/5 成功）；**只有字面量 `visible: true` 或完全不写 `visible` 的组件会永久卡死**（内置 battery/launcherButton 都中招）。→ 新增自研组件务必带上显式 visible 绑定。
- **DMS 部件"隐藏/显示"（设置→状态栏→部件行的眼睛按钮）有坑**（2026-10-02 实测）：它写 bar 配置里该部件的 `enabled`；恢复依赖 `WidgetHost` 里 `restoreMode: Binding.RestoreBinding` 的 visible Binding。而 DMS 运行时的 `DankBarContent.updateComponentMap()` **没有任何调用者（死代码）**，栏的部件映射不会因插件装卸刷新。**实测：切换显隐后部件会消失且不再恢复（内置 battery 也一样，与插件无关）——唯一可靠恢复是重启 DMS**：`systemctl --user restart dms-manual`（栏闪断几秒）。缓解：自研插件根都加了 `visible: root.effectiveVisible` 显式绑定（6 个插件，2026-10-02），让恢复时能回到该绑定。
- **⛔ 绝对不要写 `platform_profile=max-power`**（2026-10-02 发现）：LenovoLegionLinux 源码 `model_lpcn`（本机 EC，R9000P/82WM）明确警告该档在本 EC 上会**瞬间硬断电（无关机流程，有丢数据风险）**，上游已将其从可用档位移除。插件已移除"性能拉满"按钮，助手脚本也会拒绝该参数——不要放开。
- **PluginPopout**：面板高度绑定到 popoutContent 根 Item 的 `implicitHeight`，不设会变成 ~16px 细条。
- **滚轮**：普通 QML Item 没有 `onWheel`；`WheelHandler` 在 pill 内容里不触发；正确做法是 Connections 连 BasePill 的 `wheel` 信号（从 content 往 parent 链找 `enableBackgroundHover !== undefined` 的祖先即 BasePill）。
- **HoverHandler** 在 Quickshell ClippingRectangle 内不触发；悬浮检测用 `MouseArea{hoverEnabled:true}.containsMouse`。
- **Quickshell layer-shell 窗口里 `Item.window` 恒为 null**；要拿 DankBarWindow 用注入的 `blurBarWindow` 属性。
- **插件可以 import 内置模块**：`qs.Modules.DankBar.Widgets`（AudioVisualization 等）、qs.Common/qs.Services/qs.Widgets/qs.Modules.Plugins。
- `console.log` 在插件里被吞：调试用 Process 写 /tmp 文件。
- DMS 的 settings.json 必须先 `dms kill` 再改再重启（systemd-run 方式）；**简单设置键可用 `dms ipc call settings set <key> <value>` 即时生效**（如 showBatteryPercent）。
- 插件 QML 改动用 `dms ipc call plugin-scan reload <id>` 热重载；新增插件/改栏布局才需要重启 DMS。

## 用户铁律（违反会被骂）

1. **不删功能**：被替换/弃用的代码一律**注释保留**在原文件（标注日期与恢复方法），绝不直接删除。
2. **改视觉前先问**：任何组件的布局/字号/样式改动，先给方案征得同意再动手；用户在用的东西以"原样基础上最小改动"为原则，不要自建替代品。
3. **`dms kill` 会让栏瞬间消失**：需要重启 DMS 时先告知用户时机、多个改动攒成一次重启；文件级/热重载改动不闪断可直接做。
4. 只在用户授权范围内工作；完成要报告，失败要如实说。

## 其他已知问题/背景

- gnome-control-center 在 niri 会话被 Ubuntu 拒绝（"only supported under GNOME and Unity"），已装包装脚本 `~/.local/bin/gnome-control-center`（注入 XDG_CURRENT_DESKTOP=GNOME）。其他 GNOME 应用同理可包一层。
- **LenovoLegionLinux（legion-laptop）内核驱动：2026-10-02 13:02 已装好**（DKMS，机型 `model_lpcn` 匹配 BIOS 前缀 LPCN ✓；源码 `~/.local/src/LenovoLegionLinux`，安装脚本 `~/.local/bin/zzp-legion-install-lll`；Secure Boot 关闭无需签名）。接口在 `/sys/devices/platform/legion/`（属性直接挂在该目录下，**没有** legion_laptop 子目录）：`cpu_longterm_powerlimit`(PL1) / `cpu_shortterm_powerlimit`(PL2) / `cpu_peak_powerlimit` / `gpu_ctgp_powerlimit` / `cpu_temperature_limit` / `fan_fullspeed` / `lockfancontroller` / `powermode` 等，全部 root 可写；风扇转速在 hwmon（`name=legion_hwmon` 的 `fan1_input`/`fan2_input`）。驱动会按 EC 能力数据钳制功耗墙，并保持 PL2≥PL1。
- 本机（R9000P/82WM，LPCN EC）实测**可写生效**：PL1、PL2、GPU cTGP、platform_profile（LLL 接管后档位为 `low-power balanced performance custom`，ppd 三档仍兼容）、**风扇曲线**（hwmon `legion_hwmon` 的 `pwm1_auto_point1..10_pwm`，值域 0-100%，EC 按转速表量化——读回值常比写入值小几档，如写 20→读 17、写 100→读 99；批量写用助手 `fancurve "v1 .. v10"`）；**写入不生效/不可用（不要再试）**：`custom` 档位（platform_profile 写入报 I/O error）、`fan_fullspeed`、`cpu_temperature_limit`、`ideapad fan_mode`、`nvidia-smi -pl`。即：这台 EC 的**功耗墙 + 风扇曲线速度点是活的**，全速位/温度墙/自定义档位是死的。
- CPU 功耗读法：`/sys/class/powercap/intel-rapl:0/energy_uj`（root-only，0400）→ 经助手 `rapl` 子命令读取，两次采样差算瓦数（插件 5 秒轮询一次）。
- 本机 `lenovo_wmi_gamezone` 与 `ideapad_laptop` 也在提供 platform_profile，装 LLL 后实测档位已由 LLL 接管（max-power 随之从 choices 消失——危险的档位被结构性移除 ✓），当前无需 softdep 处理。
- 电池百分比数字已通过 `showBatteryPercent: false` 全局关闭（用户要求）。
- 自研插件的历史版本全部在 ~/niri-config git 历史里，恢复用 `git show <commit>:<path>`（⚠ 目前仅覆盖 4 个插件，见下条）。
- ⚠ `sync.sh` 目前只备份 4 个自研插件（zzpPerfMonitor / zzpClockWeather / zzpUserAvatar / zzpMediaCover），**zzpWorkspaceDots 与 zzpLegionTuner 未入库**；AGENTS.md 本身也不在 git 仓库中（待补）。
