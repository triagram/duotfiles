#!/usr/bin/env bash
# Claude Code status line, styled after the oh-my-zsh "half-life" theme.
#
#   mengyuan in ~/projects/foo on main ● λ  Opus 5 · 45k/200k 23% ↑3k · $0.12
#
# Colors and layout mirror ~/.oh-my-zsh/themes/half-life.zsh-theme: purple user,
# "in", limegreen path, "on" + turquoise branch, dirty-state bullets, then the
# orange lambda. Everything after the lambda is Claude Code specific.
#
# Layout adapts to the terminal width:
#   CLAUDE_STATUSLINE_STYLE=auto      (default) one line if it fits, else two
#                          =one-line  force one line, dropping segments to fit
#                          =two-line  force two lines
# In every mode the path is progressively abbreviated (~/projects/foo ->
# ~/p/foo -> foo -> fo…) before any information is thrown away, and the
# session stats shed their least useful figures last-in-first-out.
#
#   CLAUDE_STATUSLINE_COLS=120  override width detection
#
# Portability: written for bash 3.2 so it works unchanged on stock macOS.
# No mapfile, no associative arrays, no ${var^^}.

input=$(cat)

# 256-color palette lifted straight from half-life.zsh-theme.
turquoise=$'\033[38;5;81m'
orange=$'\033[38;5;166m'
purple=$'\033[38;5;135m'
hotpink=$'\033[38;5;161m'
limegreen=$'\033[38;5;118m'
grey=$'\033[38;5;245m'
reset=$'\033[0m'

# --- parse input -------------------------------------------------------
# One jq pass, one value per line. Line-oriented rather than @tsv on purpose:
# tab is an IFS whitespace character, so `read` would collapse runs of tabs and
# silently shift every field left whenever one of them came back empty.
_vals=$(printf '%s' "$input" | jq -r '[
    (.workspace.current_dir // ""),
    (.model.display_name // ""),
    (.cost.total_cost_usd // 0),
    (.context_window.used_percentage // 0),
    (.context_window.total_input_tokens // 0),
    (.context_window.total_output_tokens // 0),
    (.context_window.context_window_size // 0)
  ] | .[] | tostring' 2>/dev/null)

cwd=""; model=""; cost=0; pct=0; in_tok=0; out_tok=0; win=0
_i=0
while IFS= read -r _line; do
	case $_i in
		0) cwd=$_line ;;
		1) model=$_line ;;
		2) cost=$_line ;;
		3) pct=$_line ;;
		4) in_tok=$_line ;;
		5) out_tok=$_line ;;
		6) win=$_line ;;
	esac
	_i=$((_i + 1))
done <<EOF
$_vals
EOF

[ -n "$cwd" ] || cwd=$PWD
[ -n "$cost" ] || cost=0
[ -n "$pct" ] || pct=0
[ -n "$in_tok" ] || in_tok=0
[ -n "$out_tok" ] || out_tok=0
[ -n "$win" ] || win=0

# --- terminal width ----------------------------------------------------
# stdout is a pipe, so `tput cols` alone reports its 80-column fallback. The
# controlling terminal is inherited from Claude Code, so /dev/tty is the honest
# source. If everything fails, assume the conventional 80 columns: guessing
# narrow costs a wrapped-looking line at worst, guessing wide truncates.
cols=${CLAUDE_STATUSLINE_COLS:-} _src="env"
# Claude Code exports COLUMNS with the width actually available to the status
# bar, which is the number we want. Measured: it is set here but not in other
# tool subprocesses, so it is deliberate. /dev/tty is only a backstop — the
# device exists but `tput cols` against it returns nothing under Claude Code,
# and it would report the whole terminal rather than the usable bar width.
if [ -z "$cols" ] && [ -n "${COLUMNS:-}" ]; then cols=$COLUMNS; _src="COLUMNS"; fi
if [ -z "$cols" ] && [ -c /dev/tty ]; then
	cols=$(tput cols 2>/dev/null </dev/tty) || cols=""
	[ -n "$cols" ] && _src="tty"
fi
if [ -z "$cols" ]; then cols=80; _src="default"; fi
case $cols in *[!0-9]*) cols=80; _src="default(non-numeric)" ;; esac
[ "$cols" -gt 0 ] || { cols=80; _src="default(zero)"; }
# One column of slack: a status line that exactly fills the width wraps on some
# terminals, and a wrapped status line looks broken.
cols=$((cols - 1))

# Set CLAUDE_STATUSLINE_DEBUG=/path/to/log to record what width was detected.
if [ -n "${CLAUDE_STATUSLINE_DEBUG:-}" ]; then
	printf '%s budget=%s src=%s devtty=%s TERM=%s stty=%s\n' \
		"$(date +%H:%M:%S)" "$cols" "$_src" \
		"$([ -c /dev/tty ] && echo yes || echo no)" "${TERM:-unset}" \
		"$(stty size </dev/tty 2>/dev/null || echo n/a)" \
		>>"$CLAUDE_STATUSLINE_DEBUG" 2>/dev/null
fi

# --- helpers -----------------------------------------------------------
# All the number formatting in a single awk, because this script runs on a
# timer and process spawns dominate its cost — five awk calls were most of it.
_fmt=$(awk -v i="$in_tok" -v w="$win" -v o="$out_tok" -v c="$cost" -v p="$pct" '
	function human(n) {
		if (n >= 1000000) return sprintf("%.1fM", n/1000000);
		if (n >= 1000)    return sprintf("%.0fk", n/1000);
		return sprintf("%d", n)
	}
	BEGIN{ printf "%s\n%s\n%s\n$%.2f\n%d\n", human(i), human(w), human(o), c, p + 0.5 }')
tok_in=""; tok_win=""; tok_out=""; cost_s=""; pct_i=0
_i=0
while IFS= read -r _line; do
	case $_i in
		0) tok_in=$_line ;;
		1) tok_win=$_line ;;
		2) tok_out=$_line ;;
		3) cost_s=$_line ;;
		4) pct_i=$_line ;;
	esac
	_i=$((_i + 1))
done <<EOF
$_fmt
EOF
[ -n "$pct_i" ] || pct_i=0

# --- path variants -----------------------------------------------------
# %~ — abbreviate $HOME to a tilde the way zsh does.
case $cwd in
	"$HOME") path_full="~" ;;
	"$HOME"/*) path_full="~${cwd#"$HOME"}" ;;
	*) path_full=$cwd ;;
esac
path_base=${path_full##*/}
[ -n "$path_base" ] || path_base=$path_full

# ~/projects/bing-daily-reward -> ~/p/bing-daily-reward
# Leading ~ or / is kept, every directory above the last collapses to its first
# character (two for dotdirs, so .claude reads as .c rather than a bare dot).
abbrev_path() {
	local p=$1 head="" rest="" base="" dirs="" out="" comp="" short="" oldifs
	case $p in
		"~") printf '~'; return ;;
		"~/"*) head="~/"; rest=${p#\~/} ;;
		/*) head="/"; rest=${p#/} ;;
		*) rest=$p ;;
	esac
	base=${rest##*/}
	dirs=${rest%/*}
	if [ "$dirs" = "$rest" ]; then # single component, nothing to collapse
		printf '%s%s' "$head" "$rest"
		return
	fi
	oldifs=$IFS
	IFS=/
	set -- $dirs
	IFS=$oldifs
	for comp in "$@"; do
		[ -n "$comp" ] || continue
		case $comp in
			.?*) short=${comp:0:2} ;;
			*) short=${comp:0:1} ;;
		esac
		out="${out}${short}/"
	done
	printf '%s%s%s' "$head" "$out" "$base"
}
path_abbrev=$(abbrev_path "$path_full")
path_trunc=$path_base # recomputed only if we hit the last-resort branch

# --- vcs_info equivalent -----------------------------------------------
# Measured in a repo with 23.5k files: `git ls-files --others` costs 15ms and
# each `git diff --quiet` 8ms, i.e. ~80% of this script's runtime. Because the
# bar also runs on a timer, that would burn CPU continuously for information
# that changes rarely. So the git portion is cached for a few seconds; real
# edits still show up promptly, and idle redraws cost one `date` call.
vcs_c="" vcs_p=""
_ttl=${CLAUDE_STATUSLINE_GIT_TTL:-5}
_cache_dir="${TMPDIR:-/tmp}/claude-statusline-$(id -u 2>/dev/null || echo 0)"
_cache_file="$_cache_dir/$(printf '%s' "$cwd" | tr -c 'A-Za-z0-9' '_')"
_now=$(date +%s 2>/dev/null || echo 0)
_cached=0
if [ "$_ttl" -gt 0 ] && [ -f "$_cache_file" ]; then
	_i=0
	while IFS= read -r _line; do
		case $_i in
			0) [ "$((_now - _line))" -lt "$_ttl" ] 2>/dev/null || break; _cached=1 ;;
			1) vcs_c=$_line ;;
			2) vcs_p=$_line ;;
		esac
		_i=$((_i + 1))
	done <"$_cache_file"
fi

if [ "$_cached" -eq 1 ]; then
	cd "$cwd" 2>/dev/null || true
elif cd "$cwd" 2>/dev/null && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) ||
		branch=$(git rev-parse --short HEAD 2>/dev/null) ||
		branch="(no commits)"

	marks_c="" marks_p=""
	# Cheap per-state checks; `git status --porcelain` is far slower in repos
	# with large ignored/untracked trees.
	git diff --cached --quiet 2>/dev/null || { marks_c="${marks_c}${limegreen} ●"; marks_p="${marks_p} ●"; }
	git diff --quiet 2>/dev/null || { marks_c="${marks_c}${orange} ●"; marks_p="${marks_p} ●"; }
	if [ -n "$(git ls-files --others --exclude-standard 2>/dev/null | head -n1)" ]; then
		marks_c="${marks_c}${hotpink} ●"; marks_p="${marks_p} ●"
	fi

	# half-life's actionformats: " performing a <action>" mid-rebase/merge.
	gitdir=$(git rev-parse --git-dir 2>/dev/null)
	action=""
	if [ -d "$gitdir/rebase-merge" ] || [ -d "$gitdir/rebase-apply" ]; then
		action="rebase"
	elif [ -f "$gitdir/MERGE_HEAD" ]; then
		action="merge"
	elif [ -f "$gitdir/CHERRY_PICK_HEAD" ]; then
		action="cherry-pick"
	elif [ -f "$gitdir/BISECT_LOG" ]; then
		action="bisect"
	fi

	vcs_c=" on ${turquoise}${branch}${reset}${marks_c}${reset}"
	vcs_p=" on ${branch}${marks_p}"
	if [ -n "$action" ]; then
		vcs_c="${vcs_c} performing a ${limegreen}${action}${reset}"
		vcs_p="${vcs_p} performing a ${action}"
	fi
fi

# Record the result (including "not a repo", which is the empty string) so the
# next timer tick inside the TTL costs nothing.
if [ "$_cached" -eq 0 ] && [ "$_ttl" -gt 0 ]; then
	mkdir -p "$_cache_dir" 2>/dev/null &&
		printf '%s\n%s\n%s\n' "$_now" "$vcs_c" "$vcs_p" >"$_cache_file" 2>/dev/null
fi

# --- session figures ---------------------------------------------------
# tok_in/tok_win/tok_out/cost_s/pct_i were all produced by the single awk above.
if [ "$pct_i" -ge 80 ]; then
	tokcolor=$hotpink
elif [ "$pct_i" -ge 50 ]; then
	tokcolor=$orange
else
	tokcolor=$limegreen
fi
user=${USER:-$(whoami)}

# --- row builders ------------------------------------------------------
# Row 1 = the half-life prompt. $1 selects the path variant (0 full, 1
# abbreviated, 2 basename, 3 truncated basename), $2 keeps the username.
row1_build() {
	local lvl=$1 with_user=$2 pth
	case $lvl in
		0) pth=$path_full ;;
		1) pth=$path_abbrev ;;
		2) pth=$path_base ;;
		*) pth=$path_trunc ;;
	esac
	r1_c="" r1_p=""
	if [ "$with_user" -eq 1 ]; then
		r1_c="${purple}${user}${reset} in " r1_p="${user} in "
	fi
	r1_c="${r1_c}${limegreen}${pth}${reset}${vcs_c} ${orange}λ${reset}"
	r1_p="${r1_p}${pth}${vcs_p} λ"
}

# Row 2 = the session stats, shedding figures as $1 rises.
row2_build() {
	local d=$1 sep_c="${grey} · ${reset}" sep_p=" · " tk
	r2_c="" r2_p=""
	if [ "$d" -lt 4 ] && [ -n "$model" ]; then
		r2_c="${purple}${model}${reset}${sep_c}" r2_p="${model}${sep_p}"
	fi
	tk=$tok_in
	if [ "$d" -lt 3 ] && [ "$win" -gt 0 ] 2>/dev/null; then
		tk="${tk}/${tok_win}"
	fi
	tk="${tk} ${pct_i}%"
	r2_c="${r2_c}${tokcolor}${tk}${reset}" r2_p="${r2_p}${tk}"
	# Output tokens are billed separately and don't consume the window, so they
	# ride along as a smaller trailing figure and are the first thing dropped.
	if [ "$d" -lt 1 ]; then
		r2_c="${r2_c}${grey} ↑${tok_out}${reset}" r2_p="${r2_p} ↑${tok_out}"
	fi
	if [ "$d" -lt 2 ]; then
		r2_c="${r2_c}${sep_c}${grey}${cost_s}${reset}" r2_p="${r2_p}${sep_p}${cost_s}"
	fi
}

# Shrink row 1 until it fits $1 columns. The username goes first — it costs 12
# columns and never tells you anything you didn't know — then the path is
# abbreviated, and only as a last resort is the directory name itself cut.
fit_row1() {
	local budget=$1 combo over keep
	for combo in "0 1" "0 0" "1 0" "2 0"; do
		set -- $combo
		row1_build "$1" "$2"
		[ ${#r1_p} -le "$budget" ] && return
	done
	over=$((${#r1_p} - budget))
	keep=$((${#path_base} - over - 1))
	[ "$keep" -lt 3 ] && keep=3
	path_trunc="${path_base:0:$keep}…"
	row1_build 3 0
}

fit_row2() { # shrink row 2 until it fits $1 columns
	local budget=$1 d=0
	row2_build $d
	while [ ${#r2_p} -gt "$budget" ] && [ $d -lt 4 ]; do
		d=$((d + 1))
		row2_build $d
	done
}

# --- choose a layout ---------------------------------------------------
style=${CLAUDE_STATUSLINE_STYLE:-auto}

if [ "$style" != "two-line" ]; then
	# Try one line. The username may be dropped to make it fit — it is the only
	# part that carries no information, so losing it still counts as showing
	# everything. Anything beyond that and two lines is the better trade.
	row2_build 0
	for _combo in "0 1" "0 0"; do
		set -- $_combo
		row1_build "$1" "$2"
		if [ $((${#r1_p} + 2 + ${#r2_p})) -le "$cols" ]; then
			printf '%s  %s' "$r1_c" "$r2_c"
			exit 0
		fi
	done
fi

if [ "$style" = "one-line" ]; then
	# Forced single line: give row 2 what it needs, row 1 takes the remainder.
	fit_row2 $((cols / 2))
	fit_row1 $((cols - ${#r2_p} - 2))
	printf '%s  %s' "$r1_c" "$r2_c"
	exit 0
fi

# Two lines, each shrunk against the full width independently.
fit_row1 "$cols"
fit_row2 "$cols"
printf '%s\n%s' "$r1_c" "$r2_c"
