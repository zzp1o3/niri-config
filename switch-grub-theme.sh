#!/bin/sh
# 一键切换 GRUB 主题（主题文件就在本仓库 grub-themes/ 内）。
# 用法：sudo ./switch-grub-theme.sh <bsol|SekiroShadow|tela>
set -e

if [ "$(id -u)" != "0" ]; then
    echo "请用 sudo 运行：sudo $0 ${1:-<theme>}"
    exit 1
fi

R="$(cd "$(dirname "$0")" && pwd)"
T="${1:-}"

case "$T" in
    bsol) GFX=1920x1200 ;;
    SekiroShadow) GFX=1920x1080 ;;
    tela) GFX=2560x1440 ;;
    *)
        echo "用法: sudo $0 <bsol|SekiroShadow|tela>"
        exit 1
        ;;
esac

SRC="$R/grub-themes/$T"
[ -d "$SRC" ] || { echo "仓库里没有主题: $T"; exit 1; }

mkdir -p /usr/share/grub/themes
rm -rf "/usr/share/grub/themes/$T"
cp -r "$SRC" "/usr/share/grub/themes/$T"

sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"/usr/share/grub/themes/$T/theme.txt\"|" /etc/default/grub
sed -i "s|^GRUB_GFXMODE=.*|GRUB_GFXMODE=$GFX,auto|" /etc/default/grub
sed -i 's/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=menu/;s/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=30/' /etc/default/grub

update-grub
echo "✓ 已切换 GRUB 主题: $T（GRUB_GFXMODE=$GFX,auto）"
