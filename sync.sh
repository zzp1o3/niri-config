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

# 辅助脚本
mkdir -p "$R/scripts"
cp "$HOME/.local/bin/niri-flow" "$HOME/.local/bin/niri-focus-cross" "$HOME/.local/bin/screenrec-toggle" "$R/scripts/"
chmod +x "$R"/scripts/*

# DMS 自研插件
mkdir -p "$R/plugins"
for p in zzpPerfMonitor zzpClockWeather zzpUserAvatar zzpMediaCover; do
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

# keyd（可选）
if [ -f "$HOME/keyd-default.conf" ]; then
    cp "$HOME/keyd-default.conf" "$R/keyd-default.conf"
fi

cd "$R"
"$GIT" add -A
if "$GIT" diff --cached --quiet; then
    echo "没有变化，无需提交。"
    exit 0
fi
"$GIT" commit -m "sync: $(date '+%Y-%m-%d %H:%M:%S')"
GIT_TERMINAL_PROMPT=0 "$GIT" push
echo "✓ 已同步并推送。"
