# .zshrc — deployed by dof from duotfiles/tools/zsh/common/.zshrc
#
# ONE file for both machines. Everything here runs on Linux and macOS alike,
# except the single `case "$(uname -s)"` block below, which is the only
# per-machine part. Search for "PLATFORM-SPECIFIC" to find it.

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="half-life"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
# ═══════════════════════════════════════════════════════════════════════════
# PLATFORM-SPECIFIC — the only part of this file that differs per machine.
#
# Stays above `source $ZSH/oh-my-zsh.sh` on purpose: the fzf plugin reads
# FZF_BASE while oh-my-zsh loads, so setting it afterwards is too late.
#
# Where does a new line go?
#   here    it names a path outside $HOME, a package manager, or an OS tool
#   common  it uses only $HOME, or a command both machines have
#
# When unsure, put it here. Getting it wrong in this direction costs you the
# line on the other machine, which you notice the first time you miss it.
# Getting it wrong the other way puts a macOS-only line in the common part,
# where it runs on Linux and errors on every single shell start.
# ═══════════════════════════════════════════════════════════════════════════
case "$(uname -s)" in

  Darwin)
    export FZF_BASE=/opt/homebrew/opt/fzf      # Homebrew prefix, Apple Silicon
    ;;

  Linux)
    : # nothing yet — the Linux machine fills this in when it adopts
    ;;

esac
# ══════════════════════════════════════ end PLATFORM-SPECIFIC ══════════════

plugins=(git fast-syntax-highlighting zsh-autosuggestions fzf)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"


# Added by Antigravity CLI installer
export PATH="$HOME/.local/bin:$PATH"

# duotfiles: put `dof` (the config deployer) on PATH
export PATH="$HOME/duotfiles/bin:$PATH"

# --- version managers --------------------------------------------------
# Both of these are guarded, so a machine without the tool skips the line
# instead of erroring on every shell start. pyenv lives in the shared part
# rather than a platform block because it is going on the Mac too; until it
# is, `command -v` keeps it quiet there.
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
command -v pyenv >/dev/null 2>&1 && eval "$(pyenv init - zsh)"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# --- ls: directories first ---------------------------------------------
# 目录在前、文件在后。--group-directories-first 是 GNU ls 独有的，macOS 自带的
# BSD ls 没有；探测失败就保持原样，不会报错。
#
# Appends rather than overrides: oh-my-zsh's lib/theme-and-appearance.zsh has
# already picked the right colour alias for this platform (ls --color=tty on
# Linux, gls --color=tty with brew coreutils, plain ls -G on stock macOS), so
# this only adds a flag on top of whatever it chose. Has to come after
# `source $ZSH/oh-my-zsh.sh` to see that alias at all.
if ${=${aliases[ls]:-ls}} --group-directories-first / > /dev/null 2>&1; then
  alias ls="${aliases[ls]:-ls} --group-directories-first"
fi

# ═══════════════════════════════════════════════════════════════════════════
# PLATFORM-SPECIFIC (late) — for platform lines that must run AFTER oh-my-zsh.
#
# The early block above exists because FZF_BASE is read while oh-my-zsh loads.
# This one is for the opposite case: anything that has to see the finished
# environment. Empty right now — every platform-specific line this machine had
# turned out to be tool-managed, and those live in ~/.zshrc.local instead.
# ═══════════════════════════════════════════════════════════════════════════
case "$(uname -s)" in
  Darwin) : ;;
  Linux)  : ;;
esac

# --- machine-local, deliberately not in duotfiles ----------------------
# Blocks that a tool writes and owns (`conda init`, `mamba shell init` — both
# target ~/.zshrc directly), and anything naming an absolute path outside
# $HOME. Keeping them out of the repo is what stops two machines from
# overwriting each other's paths in this shared file. See notes/zsh.md.
# Sourced last so it can override anything above.
[ -r "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
