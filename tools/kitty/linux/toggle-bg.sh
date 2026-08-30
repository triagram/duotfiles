#!/bin/bash
# kitty 背景圖開關 / 切換。綁定見 kitty.conf 第 11 節。
#   toggle          開↔關（用上次選的圖，預設第一張）
#   next            換下一張（若目前是關閉狀態則直接開啟）
# 預設是「關」：新視窗不帶背景圖，要背景得自己按一次。
# 依賴 kitty.conf 裡的 listen_on —— 沒有它，背景行程呼叫 kitty @ 會找不到 /dev/tty。
set -u
DIR="$HOME/.config/kitty/backgrounds"

# 狀態按 kitty 實例分開存。
#
# kitty 的 set-background-image 預設「只改當前活動的 OS 視窗」（官方說明原文）。
# 若所有視窗共用一份狀態，它們會互相攪亂：在 A 視窗關掉背景後，B 視窗的下一次
# toggle 讀到「已關閉」而去開啟，可 B 本來就開著 —— 看起來就是「按了沒反應，
# 要多按幾次才行」。視窗開得越多越明顯。
#
# KITTY_LISTEN_ON 形如 unix:@kitty-305519，取末段（PID）當鍵。
# 已知侷限：同一個 kitty 實例底下開多個 OS 視窗時，它們仍共用一份狀態。
_key="${KITTY_LISTEN_ON##*-}"
STATE="${XDG_RUNTIME_DIR:-/tmp}/kitty-bg.${_key:-shared}.state"

mapfile -t IMGS < <(find "$DIR" -maxdepth 1 -name '*.png' | sort)
[ ${#IMGS[@]} -eq 0 ] && exit 0

# 沒有狀態檔時視為「關閉」—— theme-overrides.conf 不再設定 background_image，
# 新視窗一律不帶背景圖，所以第一次 toggle 應該是「開啟」。
idx=0; on=0
[ -f "$STATE" ] && read -r idx on < "$STATE" 2>/dev/null
[[ "$idx" =~ ^[0-9]+$ ]] || idx=0
[[ "$on"  =~ ^[01]$   ]] || on=0
# 圖片數量變少時舊狀態的 idx 會越界，取到空字串會讓 set-background-image 報錯。
[ "$idx" -lt "${#IMGS[@]}" ] || idx=0

case "${1:-toggle}" in
  toggle) on=$((1-on)) ;;
  next)   if [ "$on" -eq 1 ]; then idx=$(((idx+1) % ${#IMGS[@]})); else on=1; fi ;;
esac

if [ "$on" -eq 1 ]; then
  kitty @ set-background-image "${IMGS[$idx]}"
else
  kitty @ set-background-image none
fi
echo "$idx $on" > "$STATE"
