#!/usr/bin/python3
"""切换 kitty 图标（窗口图标 + Dock/应用网格图标）。

用法:
    ./switch-icon.py            列出可用图标
    ./switch-icon.py nyan       切换到 icons/nyan.png
    ./switch-icon.py /path/x.png  切换到任意 PNG（会一并存进 icons/）

改完按 Alt+F2 输入 r 回车重启 GNOME Shell 生效。
"""
import os
import shutil
import subprocess
import sys

import gi
gi.require_version('GdkPixbuf', '2.0')
from gi.repository import GdkPixbuf

CONF = os.path.expanduser('~/.config/kitty')
LIB = os.path.join(CONF, 'icons')
WINDOW_ICON = os.path.join(CONF, 'kitty.app.png')
HICOLOR = os.path.expanduser('~/.local/share/icons/hicolor')
SIZES = [16, 24, 32, 48, 64, 128, 256, 512]


def available():
    if not os.path.isdir(LIB):
        return []
    return sorted(f[:-4] for f in os.listdir(LIB) if f.endswith('.png'))


def resolve(arg):
    """把参数解析成一个源 PNG 路径。"""
    if os.path.sep in arg or arg.endswith('.png'):
        path = os.path.abspath(os.path.expanduser(arg))
        if not os.path.exists(path):
            sys.exit(f'找不到文件: {path}')
        # 存进图标库，方便以后按名字切换
        os.makedirs(LIB, exist_ok=True)
        dest = os.path.join(LIB, os.path.basename(path))
        if os.path.abspath(dest) != path:
            shutil.copy2(path, dest)
            print(f'已存入图标库: {dest}')
        return dest
    path = os.path.join(LIB, arg + '.png')
    if not os.path.exists(path):
        sys.exit(f'图标库里没有 {arg!r}。可用: {", ".join(available()) or "(空)"}')
    return path


def install(src):
    pixbuf = GdkPixbuf.Pixbuf.new_from_file(src)
    w, h = pixbuf.get_width(), pixbuf.get_height()
    print(f'源图: {src} ({w}x{h})')

    # 1. 窗口图标：kitty 启动时读取 config 目录下的 kitty.app.png
    if os.path.abspath(src) != WINDOW_ICON:
        shutil.copy2(src, WINDOW_ICON)
    print(f'窗口图标 -> {WINDOW_ICON}')

    # 2. 启动器图标：装进 hicolor 主题，供 .desktop 的 Icon=kitty 解析
    #    只缩不放，避免生成比源图还大的糊图
    sizes = [s for s in SIZES if s <= max(w, h)] or [max(w, h)]
    for size in sizes:
        d = os.path.join(HICOLOR, f'{size}x{size}', 'apps')
        os.makedirs(d, exist_ok=True)
        scaled = pixbuf.scale_simple(size, size, GdkPixbuf.InterpType.BILINEAR)
        scaled.savev(os.path.join(d, 'kitty.png'), 'png', [], [])
    print(f'启动器图标 -> {HICOLOR}/{{{",".join(f"{s}x{s}" for s in sizes)}}}/apps/kitty.png')

    # 源图小于某些尺寸时，清掉上一个图标残留的大尺寸文件，避免混用两张图。
    # 注意：只针对 ~/.local/share/icons（用户级）。若日后用 apt 装了 kitty，
    # 发行版图标在 /usr/share/icons，不受影响。
    for size in SIZES:
        if size not in sizes:
            stale = os.path.join(HICOLOR, f'{size}x{size}', 'apps', 'kitty.png')
            if os.path.exists(stale):
                os.remove(stale)
                print(f'清除残留: {stale}')

    subprocess.run(['gtk-update-icon-cache', '-f', '-t', HICOLOR], check=True)


def main():
    if len(sys.argv) != 2:
        icons = available()
        print(__doc__.strip())
        print(f'\n图标库 ({LIB}):')
        for name in icons:
            print(f'  {name}')
        if not icons:
            print('  (空)')
        return
    install(resolve(sys.argv[1]))
    print('\n完成。按 Alt+F2 -> 输入 r -> 回车，重启 GNOME Shell 生效。')


if __name__ == '__main__':
    main()
