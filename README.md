# duotfiles

[English](README.md) · [中文](README.zh-CN.md)

Cross-machine config management, **one tool at a time**. Linux and macOS keep their
own copies and are merged only when you decide to merge them. No whole-machine
bootstrap, no background syncing — every change lands because you ran a command.

Why it works this way: [DESIGN.md](DESIGN.md).

---

## What it manages

| Tool | Mode | Linux | macOS |
|---|---|---|---|
| tmux | link | `~/.config/tmux` | `~/.config/tmux` |
| kitty | link | `~/.config/kitty` | `~/.config/kitty` |
| ghostty | link | `~/.config/ghostty` | `~/.config/ghostty` |
| claude | link | `~/.claude` | `~/.claude` |
| agy | link | `~/.gemini` | `~/.gemini` |
| rime | copy | `~/.local/share/fcitx5/rime` | `~/Library/Rime` |

To add a tool: append a line to [`manifest`](manifest), then
`mkdir -p tools/<name>/{common,linux,macos}`.

---

## Where to put this repo

**Recommended: `~/.duotfiles`** — the same path on every machine.

Unlike an ordinary git repo, this one's location is not a free choice. Four reasons:

1. **`link` mode writes absolute symlinks *into* this repo.** After
   `dof pull tmux`, `~/.config/tmux/tmux.conf` is a pointer containing the literal
   text `/home/you/.duotfiles/tools/tmux/linux/tmux.conf`. Move the repo and every
   pointer goes stale. (Recoverable — re-run `dof pull <tool>` — but avoidable.)
2. **It must live under `$HOME`.** Home directories differ across platforms
   (`/Users/you` vs `/home/you`), but a *home-relative* path is identical on both.
   A path outside `$HOME` such as `/projects/...` cannot even be created on macOS,
   where the root volume is read-only.
3. **Never inside a cloud-sync folder** (iCloud / OneDrive / Dropbox). Sync engines
   and `.git` corrupt each other — a classic way to lose a repository. Git is
   already your sync mechanism; don't stack a second one under it.
4. **Never anywhere that gets cleaned** (`/tmp`, Downloads). Under `link` mode this
   repo holds the *only* copy of your configs.

`~/duotfiles` (visible) works equally well if you prefer it; just keep it consistent
across machines.

---

## Getting started

### On a new machine

```bash
git clone <your-repo> ~/.duotfiles
cd ~/.duotfiles

./bin/dof list                       # what exists, what's deployed here
./bin/dof pull tmux                  # deploy only what you need right now
./bin/dof pull claude
```

Existing files at the destination are backed up to `<name>.dof-bak-<timestamp>`
before anything is overwritten. Nothing is lost.

### Making `dof` callable (optional)

`dof` needs no installation. Pick one:

| Approach | How | Notes |
|---|---|---|
| **Do nothing** | `~/.duotfiles/bin/dof status` | Zero setup, always correct. You rarely need `dof` day to day — under `link` mode, changing a config just means `git commit` |
| **Add to PATH** (recommended) | `echo 'export PATH="$HOME/.duotfiles/bin:$PATH"' >> ~/.zshrc` | One line, once per machine. Once your shell config itself is managed here, that line lives in the repo |
| **Symlink into an existing PATH dir** | `ln -s ~/.duotfiles/bin/dof ~/.local/bin/dof` | `~/.local/bin` is usually already on PATH on Linux; on macOS it is not, so you'd still add a line |

`dof` resolves symlinks on `$0` before locating the repo, so the third approach
won't misidentify the repo root. If the script lives away from the repo, override
with `DOF_REPO=<path> dof …`.

**Don't package it for brew / apt.** `dof` is inseparable from this repo — it
locates the repo from its own path. A package manager would install a detached
copy that needs extra configuration to work at all.

### Importing configs that already exist on a machine

```bash
dof adopt tmux                       # copies into tools/tmux/<platform>/
git status                           # review — drop anything that shouldn't be here
git add -A && git commit -m "tmux(linux): import existing config"
dof pull tmux                        # switch to link-managed (optional, recommended)
```

---

## Daily use

### You changed a config and want it on your other machine

**`link` tools (tmux / kitty / ghostty / claude / agy)** — you edited the repo file
directly:

```bash
vim ~/.config/tmux/tmux.conf         # or change it any other way
git status                           # the change is already here. No "upload" step.
git add -A && git commit -m "tmux(macos): prefix key -> C-a"
git push
```

**`copy` tools (rime)** — needs one explicit collection step:

```bash
dof diff rime                        # see what differs first
dof push rime                        # copy the machine's version back into the repo
git add -A && git commit -m "rime: a few new custom phrases"
git push
```

### Pulling on the other machine

```bash
git pull
dof diff tmux                        # optional: preview what will change
dof pull tmux
```

### Periodic health check

```bash
dof status                           # all tools, or: dof status claude
```

Watch for `UNLINKED` — it means an application replaced the symlink with a regular
file, so its changes are no longer reaching the repo. See
[DESIGN.md](DESIGN.md#linkcopy-的判据).

---

## Commands

| Command | What it does |
|---|---|
| `dof list` | Deployment status of every tool on this machine |
| `dof status [tool]` | Per-file check, including symlink health |
| `dof pull <tool>` | Repo → machine. Backs up before overwriting |
| `dof push <tool>` | Machine → repo. Not needed for `link` tools; it will tell you |
| `dof diff <tool>` | Differences between repo and machine |
| `dof adopt <tool> [subpath]` | Import this machine's existing config into the repo |

`dof` is [`bin/dof`](bin/dof) in this repo — a dependency-free bash script, not a
system command. It handles the one thing git cannot: mapping a repo path to the
place an application actually expects its config.

---

## Layout

```
tools/<name>/
├── common/     shared by both platforms (empty until you merge something)
├── linux/      Linux only
├── macos/      macOS only
├── .dofignore  optional: paths dof never touches
└── .dofkeep    optional: allow-list of paths `adopt` may import
```

`common/` is laid down first, then `<current platform>/` on top — the platform
layer wins on name collisions.

**Don't create `common/` up front.** Keep a full copy per platform, and only move
files into `common/` after you have compared them and decided they should be shared.

---

## Per-tool notes

**rime** — the only `copy` tool. The user dictionary (`*.userdb/`) **never goes into
git**; it syncs through Rime's own mechanism. Upstream schemas (rime-ice) are cloned
at deploy time rather than vendored. Each new machine needs `installation.yaml`
configured once. Full details: [notes/rime.md](notes/rime.md).

**claude / agy** — `~/.claude` and `~/.gemini` mix configuration with local state,
so a `.dofkeep` allow-list controls what may be imported. `~/.claude/projects/` holds
full transcripts of every session and must never enter the repo. How the instruction
files are organised: [notes/ai-context.md](notes/ai-context.md).

**kitty / ghostty / tmux** — all three have native include mechanisms
(`include ${KITTY_OS}.conf`, `config-file = ?platform-macos.conf`, `source-file -q`).
Use those when you eventually merge platform differences; no template engine needed.

---

## Before pushing to a public remote

Confirm none of these were ever committed:

- `~/.claude/.credentials.json`, `~/.claude/projects/` (session transcripts)
- any `*.key` / `*.pem` / token-bearing file
- Rime's `installation.yaml` (contains machine-local paths)

[`.gitignore`](.gitignore) blocks these aggressively — false positives are the
intended trade-off. Force a legitimate file through with `git add -f`.

---

## Further reading

| Document | Answers |
|---|---|
| [DESIGN.md](DESIGN.md) | Why it is built this way: principles, structure, trade-offs |
| [AGENTS.md](AGENTS.md) | Rules for AI agents working in this repo (`CLAUDE.md` / `GEMINI.md` are symlinks to it) |
| [notes/](notes/) | One file per tool: why these parts must stay platform-specific |
