#!/bin/sh
# 一键同步：把当前机器上的实时配置同步进本仓库并推送。
# 用法：./sync.sh
set -e

R="$(cd "$(dirname "$0")" && pwd)"
if command -v git >/dev/null 2>&1; then
    GIT=git
else
    GIT="$HOME/.local/bin/git"
fi

# niri 配置
cp "$HOME/.config/niri/config.kdl" "$R/"
mkdir -p "$R/dms"
cp "$HOME"/.config/niri/dms/*.kdl "$R/dms/"

# 辅助脚本（2026-10-02：补入拯救者免密助手，原版备份一并入库）
mkdir -p "$R/scripts"
cp "$HOME/.local/bin/niri-flow" "$HOME/.local/bin/niri-focus-cross" "$HOME/.local/bin/screenrec-toggle" "$R/scripts/"
cp "$HOME/.local/bin/zzp-legion-led" "$HOME/.local/bin/zzp-legion-install-lll" "$R/scripts/"
[ -f "$HOME/.local/bin/zzp-legion-led.orig-20261002" ] && cp "$HOME/.local/bin/zzp-legion-led.orig-20261002" "$R/scripts/"
chmod +x "$R"/scripts/*

# AGENTS.md（AI 代理交接文档，2026-10-02 起入库）
[ -f "$HOME/.config/niri/AGENTS.md" ] && cp "$HOME/.config/niri/AGENTS.md" "$R/AGENTS.md"

# DMS 自研插件（2026-10-02：补齐 zzpWorkspaceDots / zzpLegionTuner）
mkdir -p "$R/plugins"
for p in zzpPerfMonitor zzpClockWeather zzpUserAvatar zzpMediaCover zzpWorkspaceDots zzpLegionTuner zzpBattery zzpLauncher; do
    rm -rf "$R/plugins/$p"
    cp -r "$HOME/.config/DankMaterialShell/plugins/$p" "$R/plugins/"
done

# DMS 设置与插件锁
cp "$HOME/.config/DankMaterialShell/settings.json" "$R/dankmaterialshell-settings.json"
if [ -f "$HOME/.config/DankMaterialShell/plugin_settings.json" ]; then
    cp "$HOME/.config/DankMaterialShell/plugin_settings.json" "$R/dankmaterialshell-plugin-settings.json"
fi
if [ -f "$HOME/.config/DankMaterialShell/plugins.lock.json" ]; then
    cp "$HOME/.config/DankMaterialShell/plugins.lock.json" "$R/dankmaterialshell-plugins.lock.json"
fi

# keyd（真实配置在 /etc/keyd/default.conf，世界可读；~/keyd-default.conf 中间副本已删除）
if [ -f /etc/keyd/default.conf ]; then
    cp /etc/keyd/default.conf "$R/keyd-default.conf"
fi

cd "$R"
"$GIT" add -A
if "$GIT" diff --cached --quiet; then
    # 没有新改动，但可能还有上次推送失败的积压提交
    if [ -n "$("$GIT" log '@{u}..HEAD' --oneline 2>/dev/null)" ]; then
        GIT_TERMINAL_PROMPT=0 "$GIT" push
        echo "✓ 已推送积压的提交。"
    else
        echo "没有变化，无需提交。"
    fi
    exit 0
fi
"$GIT" commit -m "sync: $(date '+%Y-%m-%d %H:%M:%S')"
GIT_TERMINAL_PROMPT=0 "$GIT" push
echo "✓ 已同步并推送。"
