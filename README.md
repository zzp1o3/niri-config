# niri-config

我的 [niri](https://github.com/niri-wm/niri)（滚动平铺式 Wayland 合成器）+ DankMaterialShell (DMS) 桌面配置。

## 环境

- Ubuntu（内核 7.x），niri 26.04，DMS 1.6.x，fcitx5 输入法（`--disable chttrans`，只出简体）
- 双显示器：**DP-2**（外接 2K@180Hz，在左）+ **eDP-1**（笔记本 2.5K@240Hz，在右），NVIDIA 单卡驱动
- 全局窗口透明度 0.9；聚焦框 1.5px 半透明彩虹渐变 + 克制紫色光晕
- 鼠标指针：Bibata-Modern-Classic（装于 `~/.local/share/icons/`）

## 文件

| 路径 | 说明 |
|---|---|
| `config.kdl` | niri 主配置 |
| `dms/` | DMS 自动生成的包含配置（outputs / layout / alttab 等，**勿手改**，会被 DMS 覆盖重写） |
| `scripts/` | 配套脚本，见下表 |

另有自研 DMS 插件（性能监控 `zzpPerfMonitor`、时间天气 `zzpClockWeather`）位于
`~/.config/DankMaterialShell/plugins/`，尚未纳入本仓库。

## 快捷键（相对默认配置的自定义部分）

| 快捷键 | 功能 |
|---|---|
| `Mod+O` | 总览（Overview） |
| `Alt+Tab` / `Mod+Tab` | 最近窗口切换器（带预览，niri 25.11+ 默认绑定） |
| `Mod+←/→`（`Mod+H/L`） | 焦点左右移动，**到边缘自动跨到另一块屏** |
| `Mod+Win+滚轮上/下` | 聚焦窗口→工作区（到底/到顶自动跨屏） |
| `Mod+滚轮左/右` | 焦点左右移动，到边缘自动跨屏 |
| `Mod+Ctrl+←/→` | 移动窗口/列（滑到边缘自动跨屏，焦点跟随） |
| `Mod+Shift+←/→` | 焦点直接切到另一块屏 |
| `Ctrl+Shift+S` | 截图（DMS，存 `~/图片/Screenshots`） |
| `Ctrl+Shift+R` | 录屏开关（wf-recorder，存 `~/视频`） |
| `Alt+C` | 剪贴板历史 |
| `Mod+Shift+C` | DMS 控制中心 |
| `Mod+Space` | DMS 启动器（配合 keyd：轻点 Win 也可呼出） |

## scripts/

| 脚本 | 说明 |
|---|---|
| `niri-flow` | **窗口跨屏流转守护进程**（python3，随 niri 自启动）。某块屏超载（有窗口被完全挤出视野 ≥120px）时，把该屏**最久未被聚焦**的窗口送到另一块屏（LRU 淘汰，绝不动当前聚焦窗口）；反之，另一屏**完全隐藏**的窗口在本屏出现明确空位时自动回流。日志：`~/.local/state/niri-flow.log` |
| `niri-focus-cross` | 竖向焦点移动的跨屏接续：先执行屏内动作（窗口→工作区），无变化时自动聚焦另一块屏 |
| `screenrec-toggle` | 录屏开关（依赖 `wf-recorder`，文件存 `~/视频`） |

## 部署

```sh
# niri 配置
cp config.kdl ~/.config/niri/
cp -r dms ~/.config/niri/
# 脚本
mkdir -p ~/.local/bin && cp scripts/* ~/.local/bin/ && chmod +x ~/.local/bin/*
```

依赖：niri ≥ 25.11、DMS、fcitx5、python3（niri-flow）、wf-recorder（录屏，可选）、keyd（轻点 Win 呼出启动器，可选）。
