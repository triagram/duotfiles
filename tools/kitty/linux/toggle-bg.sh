#!/bin/bash
# kitty 背景圖開關 / 切換。綁定見 kitty.conf 第 11 節。
#   toggle          開↔關（用上次選的圖，預設第一張）
#   next            換下一張（若目前是關閉狀態則直接開啟）
# 依賴 kitty.conf 裡的 listen_on —— 沒有它，背景行程呼叫 kitty @ 會找不到 /dev/tty。
set -u
DIR="$HOME/.config/kitty/backgrounds"
STATE="${XDG_RUNTIME_DIR:-/tmp}/kitty-bg.state"
mapfile -t IMGS < <(find "$DIR" -maxdepth 1 -name '*.png' | sort)
[ ${#IMGS[@]} -eq 0 ] && exit 0

# 沒有狀態檔時，以 theme-overrides.conf 裡設定的圖為準，且視為「已開啟」——
# 因為新視窗一啟動就帶著那張背景圖，若預設成「關閉」，第一次 toggle 會變成
# 「開啟另一張圖」而不是使用者預期的「關掉」。
idx=0; on=1
if [ -f "$STATE" ]; then
  read -r idx on < "$STATE" 2>/dev/null
else
  cur=$(grep -oP "^background_image\\s+\\K.*" "$HOME/.config/kitty/theme-overrides.conf" 2>/dev/null)
  # 設定檔裡可能寫相對路徑（相對於 kitty 設定目錄），統一成絕對路徑再比對
  case "$cur" in /*) ;; *) cur="$HOME/.config/kitty/$cur" ;; esac
  for i in "${!IMGS[@]}"; do [ "${IMGS[$i]}" = "$cur" ] && idx=$i && break; done
fi
[[ "$idx" =~ ^[0-9]+$ ]] || idx=0
[[ "$on"  =~ ^[01]$   ]] || on=0

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
