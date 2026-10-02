# AGENTS.md — niri + DankMaterialShell 环境（给修改本机配置的 AI 代理）

> 面向 AI 代理的交接文档。**动手前必读「用户铁律」与「最高危禁令」两节。**
> 最后沉淀：2026-10-02（当天的全部踩坑、实测结论与待办已并入本文）。

## 环境总览

| 项 | 值 |
|---|---|
| 合成器 | niri 26.04，主配置 `~/.config/niri/config.kdl` |
| 桌面 shell | DankMaterialShell (DMS) **v1.6.2**，Go 静态二进制 `/usr/bin/dms` |
| DMS 运行方式 | 本机当前由 **niri 拉起**（systemd 里是 `app-niri-dms-<pid>.scope`，无 unit）；历史上也用过 transient unit `dms-manual`（见「重启 DMS」条） |
| DMS 日志 | `journalctl --user -t dms`（单元/scope 无关；`-f` 跟随，`--since "5 min ago"` 回溯） |
| DMS 运行时 QML | `/run/user/1000/danklinux-shell/<hash>/`（只读；**可直接对照运行版源码**，排查利器） |
| DMS 源码参考 | `git clone --depth 1 --branch v1.6.2 --recurse-submodules https://github.com/AvengeMedia/DankMaterialShell.git` |
| DMS 用户配置 | `~/.config/DankMaterialShell/`（settings.json / plugin_settings.json / plugins/）；会话态在 `~/.local/state/DankMaterialShell/session.json` |
| 配置 git 仓库 | `~/niri-config`（远端 `github.com/zzp1o3/niri-config`）：`./sync.sh` 一键同步（8 个插件 + 助手脚本 + AGENTS.md + settings 快照）+ 推送，支持补推积压 |
| 网络 | GitHub 走代理 `127.0.0.1:7897`（Clash Verge）；代理挂时 `git push` 会失败，直连会被 TLS 重置——**修好代理后 `./sync.sh` 会自动补推** |
| 用户 | zzp，简体中文交流 |

## 自研插件（`~/.config/DankMaterialShell/plugins/`，共 8 个）

均为 DMS widget 插件（`plugin.json` + QML）；需 `plugin_settings.json` 里 `enabled: true`；`dms ipc call plugin-scan list` 看加载状态。

| 插件 | 文件 | 说明 |
|---|---|---|
| zzpClockWeather | ClockWeather.qml | 时钟+日期+天气（竖排 = 原版数字堆叠样式，**视觉基线不可擅动**，曾因缩字被否决）。**已对齐 DMS「时间与天气」设置**：12/24h、补零、显示秒、日期顺序（`clockDateFormat`/每部件 `clockDateOrder`）、紧凑模式（横向）、华氏（`useFahrenheit`）。**限制**：竖排日期是"两位数字块"，格式串只能决定日/月顺序、不能渲染文本（可选加完整文本开关，待用户决定）|
| zzpMediaCover | MediaCover.qml + MediaCoverSettings.qml | 内置媒体组件最小改动版（20×20 频谱 + 封面替播放钮，悬浮浮现原按钮）。**带设置页**：coverSize/revealPlayButton/hoverPopout/spectrumOpensPanel（默认=原版行为）|
| zzpUserAvatar | UserAvatar.qml | 底部圆形头像；点击开控制中心；自注册 `controlCenterButtonRef` |
| zzpWorkspaceDots | WorkspaceDots.qml | macOS 风格工作区圆点（替代内置胶囊）|
| zzpPerfMonitor | PerfMonitor.qml | CPU/内存/GPU 监控（竖排紧凑 ×0.78）|
| zzpBattery | Battery.qml + BatterySettings.qml | 内置 `battery` 的**可管理替代**：同 BatteryService/BatteryMeter，**悬浮弹内置电池面板 + 点击锚定在组件上**；设置页：样式/图标环表大小(iconSize)/显示百分比·时间·功率。根带显式 visible 绑定 |
| zzpLauncher | Launcher.qml | 内置 `launcherButton` 的**可管理替代**：同 LauncherLogo、左键开应用抽屉、右键 niri 概览、悬浮 hover 弹抽屉 |
| zzpLegionTuner | LegionTuner.qml | 拯救者性能调节（重构版）：**顶部仪表盘**（CPU 占用/频率/温度/功耗 RAPL、GPU 占用/频率/温度/功耗、风扇转速、电池）+ 性能模式三档 + 双屏刷新率 + 键盘背光/FnLock + 电池养护/USB 常供电/CPU Boost + **风扇曲线**（10 档速度点 + 安静/均衡/性能/出厂 四预设，含选中高亮）。等宽分段控件（SegmentRow）布局。功耗墙控件已按用户要求移除（能力仍在助手脚本）|

栏布局（`settings.json → barConfigs[0]`）：left=[zzpLauncher, zzpWorkspaceDots, focusedWindow, systemTray, zzpMediaCover]；center=[zzpClockWeather]；right=[notificationButton, zzpPerfMonitor, zzpBattery, zzpLegionTuner, zzpUserAvatar]。
（2026-10-02 已把内置 `launcherButton`/`battery` 换成自研版——内置版在 DMS 显隐管理下会卡死，见踩坑。）

## ⛔ 最高危禁令（会丢数据 / 搞坏系统，绝不放开）

1. **绝不写 `platform_profile=max-power`**：LenovoLegionLinux 源码 `model_lpcn`（本机 EC）明确警告该档会**瞬间硬断电（无关机流程，有丢数据风险）**，上游已移除该档。助手脚本会拒绝该参数。
2. **重启 DMS 前必须先看 cgroup**：本机 DMS 由 niri 拉起，`app-niri-dms-<pid>.scope` 里**装着你从 DMS 启动器打开的一切**——实测含 **ZCode（AI 客户端自己）**、Clash Verge 等。停该 scope = **连坐杀掉它们**（"非主屏窗口/代理被关闭"的真因）。检查：`systemctl --user status app-niri-dms-*.scope`。
3. 本机 EC 的**风扇全速位 / 温度墙 / custom 档位是死的**：`fan_fullspeed`、`cpu_temperature_limit`、`platform_profile=custom`、`ideapad fan_mode`、`nvidia-smi -pl` 全部写入不生效（实测）——不要再试。

## 用户铁律（违反会被骂）

1. **不删功能**：被替换/弃用的代码一律**注释保留**在原文件（标注日期与恢复方法），绝不直接删除。
2. **改视觉前先问**：任何组件的布局/字号/样式改动，先给方案征得同意再动手；以"原样基础上最小改动"为原则，不擅自自建替代品。
3. **重启 DMS 会让栏瞬间消失**：先告知用户时机、多个改动攒成一次重启；文件级/热重载改动不闪断可直接做。**优先找免重启方案**（热重载 / 设置界面 / UI 写入）。
4. 只在用户授权范围内工作；完成要报告，失败要如实说。

## 关键技术事实（踩坑记录，务必遵守）

**插件结构类**
- **pill 内容根必须是带显式 implicit 尺寸的 `Item`**：把 `Column`/`Row`（positioner）直接当内容根，其 implicit 尺寸在 BasePill 的 Loader 托管下会塌缩为 0×0 → pill 只剩内边距高度（实测 42×13）→ 深色反馈/悬浮命中/弹窗定位全错，而内容仍"溢出渲染"看起来正常（内置 Clock.qml 就是 `Item{implicitWidth/implicitHeight}` 包一层）。
- **给未声明的属性赋值会静默失败**（QML 运行时错误随 console 一起被吞）：`root.foo = x` 前必须 `property var foo`；`vPillRoot/hPillRoot` 这类"pill 根引用"最容易漏。
- **不要放 `hoverEnabled: true` 的 MouseArea 在 pill 内容里**：它在 BasePill 的 mouseArea（z:-1）之上，会把 hover 全吃掉（深色反馈消失）。**点击**用 `pillClickAction`/`pillRightClickAction`；**悬浮**交给栏控制器 + 覆写 `triggerHoverPopout(widgetHostId)`。
- **根上必须有显式 `visible: root.effectiveVisible`**：DMS 的"隐藏/显示"用 `restoreMode: Binding.RestoreBinding` 的 visible Binding 控制，只有**原本就有绑定的属性**能在恢复时被还原；字面量 `visible: true` 或不写 → 隐藏后**永久卡死**（内置 battery/launcherButton 都中招，只能重启恢复）。自研 8 个插件已全部加。
- **新增插件/改栏布局后必须重启 DMS 才生效**（且组件校验路径有缓存，改完可先 `dms ipc call plugin-scan rescan <id>`；`plugin-scan reload <id>` 只用于已加载插件的热重载）。

**弹窗（Popout）类**
- 悬浮弹面板的正确链路：栏控制器（150ms 意图延迟）→ `triggerHoverPopout` → `openDashTab/openBatteryNow/...` → `PopoutManager.requestHoverPopout(popout, undefined, triggerId)`（hover 模式；移开自动消失由弹窗自身 `PopoutHoverDismiss` 负责）。点击则用 `requestPopout`（钉住）或内置的 `popoutService.toggleXxx`。
- **PopoutManager 在弹窗"关闭动画中"会吞掉 hover 请求**（`_isPopoutPresented()` 把 isClosing 也当已展示）→ 面板不弹。自研插件统一加"检测 `isClosing` 后 120ms 重试"（时钟/媒体/电池/启动器都有）。
- **内置 `PopoutService.toggleBattery(x,y,w,s,scr)` 只传 5 个定位参数、丢掉栏上下文** → 面板锚点错误（表现为"跟随鼠标"）。正确做法：`popout.setTriggerPosition(x,y,w,section,screen, barPosition,barThickness,barSpacing,barConfig)` 完整 9 参数后再 `toggle()`；`barPosition` 由 `axis.edge` 推导（left=2/right=3/top=0/bottom=1）。
- `PluginPopout`：面板高度绑定到 popoutContent 根 Item 的 `implicitHeight`，不设会变 ~16px 细条（自研组件改用 DankDash/内置弹窗后已无此问题）。
- 控制器偶尔对同一次悬浮发两次打开请求，被 PopoutManager 同 triggerId 去重吸收，无可见影响。

**其它 QML 环境类**
- **滚轮**：普通 Item 无 `onWheel`；`WheelHandler` 在 pill 内容里不触发 → 用 Connections 连 BasePill 的 `wheel` 信号（沿 parent 链找 `enableBackgroundHover !== undefined` 的祖先）。
- `HoverHandler` 在 Quickshell `ClippingRectangle` 内不触发；悬浮检测用 `MouseArea{hoverEnabled:true}.containsMouse`。
- layer-shell 窗口里 `Item.window` 恒为 null；要 DankBarWindow 用注入的 `blurBarWindow`。
- 插件可 import 内置模块：`qs.Modules.DankBar.Widgets`、`qs.Common/Services/Widgets/Modules.Plugins`（`BatteryMeter` 在 qs.Widgets，`BatteryService` 在 qs.Services）。
- **插件里 `console.log` 被吞**；调试用 `Quickshell.Io` 的 `Process` 写 `/tmp/xxx.log`（记得用完删）。
- **插件设置页**（`plugin.json` 声明 `"settings"` + `permissions: settings_read/write`，QML 用 `PluginSettings` + `ToggleSetting/SelectionSetting`）：值存 `plugin_settings.json`，组件侧经 `pluginData.<key>` 读取并热更新。**改了设置页文件后，DMS 设置窗口需要关掉重开**（组件按 URL 缓存），否则看不到新选项。

**DMS 管理机制类**
- `DankBarContent.updateComponentMap()` 是**死代码（无调用者）**：栏的部件映射不会因插件装卸刷新；配合 RestoreBinding 的行为，就出现了"部件隐藏后无法恢复"的坑。
- `settings.json` 必须在 DMS **停止**时改（`~/.local/state/.../session.json` 同理，运行时会被覆盖）；简单标量键可用 `dms ipc call settings set <key> <value>` 即时生效（对象/数组不支持）。

## 重启 DMS 的正确姿势（按危险度）

1. **能不重启就不重启**（热重载 / 设置界面 / UI 写入都优先）。
2. 必须重启时：先 `systemctl --user status app-niri-dms-*.scope` 看 cgroup——**若含 ZCode/Clash 等应用，先请用户保存并关闭它们**（ZCode 就是我们自己），再：
   - niri 拉起的情形：`dms kill` 或 kill 主进程，然后 `niri msg action spawn -- dms run`（或沿用 systemd-run 方式）；
   - 用 transient unit 时：**必须** `systemd-run --user --collect --unit=dms-manual --property=KillMode=process dms run`（默认 `KillMode=control-group` 会连坐杀 cgroup 内所有进程）。

## 硬件：LenovoLegionLinux（legion-laptop，2026-10-02 13:02 已装）

- DKMS 安装，机型 `model_lpcn` 按 BIOS 前缀 LPCN 匹配（R9000P/82WM ✓）；源码 `~/.local/src/LenovoLegionLinux`，安装脚本 `~/.local/bin/zzp-legion-install-lll`；Secure Boot 已关无需签名。接口在 `/sys/devices/platform/legion/`（属性**直接**挂在该目录下，无子目录）。
- **实测可写生效**：`cpu_longterm_powerlimit`(PL1)、`cpu_shortterm_powerlimit`(PL2，驱动保持 ≥PL1)、`gpu_ctgp_powerlimit`、`platform_profile`（LLL 接管后档位 `low-power balanced performance custom`，ppd 三档兼容；**max-power 已被上游结构性移除**）、**风扇曲线**（hwmon `legion_hwmon` 的 `pwm1_auto_point1..10_pwm`，0-100%，EC 按转速表量化：写 20→读 17、写 100→读 99 等，属正常）。
- **重要语义（2026-10-02 实测）**：**风扇曲线独立于性能模式**——写入后立即生效并保持，**切档位不会重置**；性能模式只管 CPU/GPU 频率与功耗。插件里提供 4 个预设（安静/均衡/性能/出厂）；"出厂"写 `3 6 8 11 13 16 18 21 21 21`，会量化回原始曲线 `2 5 7 10 12 15 17 20 20 20`。
- 只读监控：风扇转速 hwmon `fan1_input/fan2_input`；CPU 功耗 = `/sys/class/powercap/intel-rapl:0/energy_uj`（root-only）两次采样差（助手 `rapl` 子命令）。
- 免密助手 `~/.local/bin/zzp-legion-led`（sudoers 白名单**只认路径不认参数** → 新增子命令无需改 sudoers；参数已严格校验，非法输入实测被拒）。子命令：`bl/fnlock/fan/conservation/usb/profile/boost/gpu-pl/fanfull/pl1/pl2/ctgp/cputemp/fanpoint/fancurve/rapl`。原版备份 `zzp-legion-led.orig-20261002`。

## 其他已知问题 / 背景

- **主题重启后跳成深色（已修）**：根因是 `session.json` 的 `nightModeAutoEnabled=true` + `nightModeAutoMode="location"` 而本机无坐标（日志会警告），自动夜间模式乱判；已置 `nightModeAutoEnabled=false`（暖色 `nightModeEnabled` 保留）。另：壁纸路径曾指向已不存在的 `~/图片/photos/`，已修正到 `~/图片/wallpaper/`。
- **天气位置（2026-10-02 已查清，待用户填入）**：位置存 `session.json` 的 `weatherLocation`(城市名)/`weatherCoordinates`("lat,lon")/`useAutoLocation`，三项默认全空 → 天气取不到正确位置。
  - **用户实际所在地：江西省抚州市临川区**（用户亲口确认；**不要信 IP 定位**——直连 IP 库把它解析成北京西城区，实测错误；"自动定位"更不行，会走代理出口=日本）。
  - **设置界面里的"Location Search"在本机永远搜不到** ✗：它走 `dms dl` → **nominatim.openstreetmap.org 直连被墙**（实测超时；经代理 7897 可达 ✓，但 `dms dl` 不走代理）。→ 别在这上面浪费时间。
  - **正确做法（免重启、即时生效）**：设置 → 时间与天气 → 天气 → **Custom Location → 纬度 / 经度** 手动填：**纬度 27.95999，经度 116.33333**（open-meteo geocoding 里 "Fuzhou | Jiangxi" 的坐标，即抚州市区=临川区；注意 count=1 搜 "Fuzhou" 会命中福州福建 ✗）。该输入写入 `SessionData.weatherCoordinates` + `saveSettings()`，纯运行时写入，立刻生效。
  - 参考：open-meteo geocoding 直连可用（`dms dl`）✓；nominatim 只能经代理 ✓。
- gnome-control-center 在 niri 会话被拒（"only supported under GNOME and Unity"），包装脚本 `~/.local/bin/gnome-control-center`（注入 XDG_CURRENT_DESKTOP=GNOME）。
- 电池百分比数字已由 `showBatteryPercent: false` 全局关闭（用户要求）；zzpBattery 设置页有同名开关可覆盖。
- 自研插件历史版本全在 `~/niri-config` git 历史（`git show <commit>:<path>`）；`sync.sh` 现已覆盖全部 8 个插件 + 助手脚本 + AGENTS.md 本身。
- 已解决的历史问题存档（详细诊断过程见 git 历史与当日提交）：自研插件悬浮面板曾因"内容几何塌缩/属性漏声明"完全不可用 → 已修，规则已并入上文"踩坑"。

## 待验证 / 待办（交接给下一次会话）

1. **用户侧验证**：电池设置页新选项（需关掉设置窗口再打开）、天气位置搜索选"北京"、启动器（zzpLauncher，当前隐藏）显隐是否正常、时钟新样式与媒体悬浮面板。
2. **可选功能**（用户未拍板）：竖向日期是否加"完整格式文本"开关（现只有顺序生效）。
3. **已知未复现**：媒体悬浮面板在"从时钟面板快速移到媒体"场景曾不弹——已加 `isClosing` 重试修复，但缺少用户实测确认。
