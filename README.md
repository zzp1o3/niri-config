# niri-config

我的 [niri](https://github.com/niri-wm/niri)（滚动平铺式 Wayland 合成器）+ DankMaterialShell (DMS) 桌面配置。
**本仓库同时是整套桌面环境的"迁移快照"**：新机器 clone 后按「迁移到新机器」一节即可还原。

## 环境

- Ubuntu（内核 7.x），niri 26.04，DMS 1.6.x，fcitx5 输入法（`--disable chttrans`，只出简体）
- 双显示器：**DP-2**（外接 2K@180Hz，在左）+ **eDP-1**（笔记本 2.5K@240Hz，在右），NVIDIA 单卡驱动
- 全局窗口透明度 0.9；聚焦框 1.5px 半透明彩虹渐变 + 克制紫色光晕
- 鼠标指针：Bibata-Modern-Classic
- keyd：轻点 Win = DMS 启动器（mod-tap）

## 文件结构

| 路径 | 部署到 | 说明 |
|---|---|---|
| `config.kdl` | `~/.config/niri/` | niri 主配置 |
| `dms/` | `~/.config/niri/dms/` | DMS 自动生成的包含配置（**勿手改**，会被 DMS 重写） |
| `scripts/` | `~/.local/bin/` | 配套脚本（见下），需 `chmod +x` |
| `plugins/zzpPerfMonitor/` | `~/.config/DankMaterialShell/plugins/` | 自研插件：性能监控（CPU/内存/GPU + 仪表盘 + 进程列表） |
| `plugins/zzpClockWeather/` | 同上 | 自研插件：时间+日期+天气合并组件 |
| `dankmaterialshell-settings.json` | `~/.config/DankMaterialShell/settings.json` | DMS 全部设置（栏布局、托盘等） |
| `dankmaterialshell-plugins.lock.json` | `~/.config/DankMaterialShell/plugins.lock.json` | DMS 插件清单 |
| `keyd-default.conf` | `/etc/keyd/default.conf`（需 sudo） | keyd 的 mod-tap 配置（可选） |
| `sync.sh` | 本仓库内 | 一键同步脚本：把当前机器的实时配置同步回仓库并推送 |

## 快捷键（相对默认配置的自定义部分）

| 快捷键 | 功能 |
|---|---|
| `Mod+O` | 总览（Overview） |
| `Alt+Tab` / `Mod+Tab` | 最近窗口切换器（带预览，niri 25.11+ 默认绑定） |
| `Mod+←/→`（`Mod+H/L`） | 焦点左右移动，**到边缘自动跨到另一块屏** |
| `Mod+滚轮上/下` | 聚焦窗口→工作区（到底/到顶自动跨屏） |
| `Mod+滚轮左/右` | 焦点左右移动，到边缘自动跨屏 |
| `Mod+Ctrl+←/→` | 移动窗口/列（滑到边缘自动跨屏，焦点跟随） |
| `Mod+Shift+←/→` | 焦点直接切到另一块屏 |
| `Ctrl+Shift+S` | 截图（DMS，存 `~/图片/Screenshots`） |
| `Ctrl+Shift+R` | 录屏开关（wf-recorder，存 `~/视频`） |
| `Alt+C` | 剪贴板历史 |
| `Mod+Shift+C` | DMS 控制中心 |
| `Mod+Space` | DMS 启动器（配合 keyd：轻点 Win 也可） |

## scripts/

| 脚本 | 说明 |
|---|---|
| `niri-flow` | **窗口跨屏流转守护进程**（python3，随 niri 自启动）。某块屏超载（有窗口被完全挤出视野 ≥120px）时，把该屏**最久未被聚焦**的窗口送到另一块屏（LRU 淘汰，绝不动当前聚焦窗口）；反之，另一屏**完全隐藏**的窗口在本屏出现明确空位时自动回流。日志：`~/.local/state/niri-flow.log` |
| `niri-focus-cross` | 竖向焦点移动的跨屏接续：先执行屏内动作（窗口→工作区），无变化时自动聚焦另一块屏 |
| `screenrec-toggle` | 录屏开关（依赖 `wf-recorder`，文件存 `~/视频`） |

## 迁移到新机器

1. 装基础环境：niri（≥25.11）、DankMaterialShell、fcitx5、python3；可选 `wf-recorder`（录屏）、`keyd`（轻点 Win）；
2. clone 并部署：

```sh
git clone https://github.com/zzp1o3/niri-config.git && cd niri-config
mkdir -p ~/.config/niri ~/.config/DankMaterialShell/plugins ~/.local/bin
cp config.kdl ~/.config/niri/
cp -r dms ~/.config/niri/
cp scripts/* ~/.local/bin/ && chmod +x ~/.local/bin/niri-flow ~/.local/bin/niri-focus-cross ~/.local/bin/screenrec-toggle
cp -r plugins/* ~/.config/DankMaterialShell/plugins/
cp dankmaterialshell-settings.json ~/.config/DankMaterialShell/settings.json
cp dankmaterialshell-plugins.lock.json ~/.config/DankMaterialShell/plugins.lock.json
sudo install -D -m 644 keyd-default.conf /etc/keyd/default.conf && sudo systemctl restart keyd   # 可选（必须 restart 才会加载配置）
```

3. 鼠标指针主题（Bibata 经典黑白，国外网络需代理则加 `-x http://127.0.0.1:7897`）：

```sh
curl -L -o /tmp/bibata.tar.xz https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Classic.tar.xz
mkdir -p ~/.local/share/icons && tar -xJf /tmp/bibata.tar.xz -C ~/.local/share/icons/
gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic'
```

4. 注销重登 niri；进 DMS 设置 → 插件 → 扫描插件（两个 zzp 插件应自动就位）；
5. 壁纸路径等机器相关项按需调整（DMS 设置里改）。

## 日常同步

本机配置改动后，在仓库目录执行：

```sh
./sync.sh
```

即可把 `~/.config/niri`、脚本、DMS 设置与插件一次性同步回来并推送到 GitHub。

## 依赖

niri ≥ 25.11、DMS、fcitx5、python3（niri-flow）、wf-recorder（录屏，可选）、keyd（轻点 Win 呼出启动器，可选）。
