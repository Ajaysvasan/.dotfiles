# Theme switcher (kitty + tmux)

Keeps kitty's and tmux's color themes in sync, switchable live without
restarting either. Two themes ship today: **VS Code Dark+** and
**IntelliJ Darcula-inspired dark**.

## How it works

```
~/.config/
├── kitty/
│   ├── kitty.conf                 -- `include current-theme.conf`
│   ├── current-theme.conf         -- symlink, repointed by the switcher
│   └── themes/
│       ├── vscode-dark.conf
│       └── intellij-dark.conf
├── tmux/
│   ├── tmux.conf                  -- `source-file current-theme.conf`
│   ├── current-theme.conf         -- symlink, repointed by the switcher
│   └── themes/
│       ├── vscode-dark.conf
│       └── intellij-dark.conf
└── theme-switcher/
    ├── switch-theme.sh            -- the switcher itself
    ├── current                    -- state file: last theme name applied
    └── README.md                  -- this file
```

Each side (`kitty/current-theme.conf`, `tmux/current-theme.conf`) is a
symlink into that side's `themes/` directory. `kitty.conf` and
`tmux.conf` never reference a concrete theme file directly — they only
ever read through the symlink. Switching a theme means: repoint both
symlinks, write the new name to `theme-switcher/current`, then poke
the running kitty/tmux processes to reload.

**Never edit `current-theme.conf` by hand** — it's overwritten on
every switch. Edit the files under `themes/` instead.

## Usage

A CLI alias called `theme` is symlinked to `switch-theme.sh` on
`$PATH` (`/opt/homebrew/bin/theme` on this Mac). From any shell:

```sh
theme vscode      # switch to VS Code Dark+
theme intellij    # switch to IntelliJ dark
theme toggle       # flip between the two
theme status      # print the currently active theme name
```

Or trigger it from inside either app without touching a shell:

| App   | Binding          | Action                          |
|-------|------------------|----------------------------------|
| kitty | `cmd+shift+t`    | `theme toggle`, backgrounded     |
| tmux  | `prefix` then `T`| `theme toggle`, via `run-shell`  |

Both bindings call `~/.config/theme-switcher/switch-theme.sh` by its
absolute path, not the `theme` alias — so they work even if `theme`
isn't on `$PATH` (e.g. on a machine where the Homebrew symlink step
below hasn't been done).

### Linux / non-Homebrew setup

The `theme` alias above is just a convenience symlink into
`/opt/homebrew/bin`, which only exists on this Homebrew-on-macOS
machine. To get the same shorthand elsewhere:

```sh
ln -sf ~/.config/theme-switcher/switch-theme.sh ~/.local/bin/theme
# make sure ~/.local/bin is on $PATH
```

Nothing else needs to change — the kitty and tmux configs themselves
are already Mac/Linux-portable (see "Compatibility" below).

## CLI / API reference — `switch-theme.sh`

```
switch-theme.sh <command>
```

| Command    | Effect |
|------------|--------|
| `vscode`   | Apply the `vscode-dark` theme. |
| `intellij` | Apply the `intellij-dark` theme. |
| `toggle`   | Apply whichever of the two isn't currently active. |
| `status`   | Print `Current theme: <name>` and exit. Read-only. |

Anything else (including no argument) prints a usage line to stderr
and exits `1`.

**Applying a theme (`vscode` / `intellij` / `toggle`) does, in order:**

1. Validates `kitty/themes/<name>.conf` and `tmux/themes/<name>.conf`
   both exist; exits `1` with a message on stderr if either is missing.
2. `ln -sf` repoints `kitty/current-theme.conf` and
   `tmux/current-theme.conf` at the new theme files.
3. Writes `<name>` to `theme-switcher/current` (creating the directory
   if needed).
4. Reloads every running kitty OS window: globs `/tmp/kitty-*` for
   live control sockets (one per window, per kitty's
   `listen_on unix:/tmp/kitty-{kitty_pid}` setting) and runs
   `kitty @ --to unix:$sock set-colors --all --configured <kitty-theme-file>`
   against each. A dead or unreachable socket is skipped silently —
   this step never fails the whole command.
5. If a tmux server is reachable (`tmux info` succeeds), runs
   `tmux source-file ~/.config/tmux/tmux.conf` once. tmux options here
   are all global (`-g`), and tmux runs one server for every attached
   session/window/pane, so a single reload from anywhere updates all
   of them — you don't need to run this per-pane or per-session.
6. Prints `Theme switched to: <name>` on success.

**Exit codes:** `0` on success, `1` if a theme file is missing, an
unknown command was given, or no command was given. Reload failures
(steps 4–5) are swallowed on purpose — the symlinks and state file are
already updated by that point, so a stale window will show the new
theme on its next manual reload rather than leaving the switch
half-applied.

**State:** `theme-switcher/current` is the only persisted state, and
only `status` and the toggle direction in `toggle` read it — `vscode`
and `intellij` write it but don't consult it. Deleting the file just
makes the next `status`/`toggle` call assume `vscode-dark`.

**Adding a third theme:** drop `themes/<name>.conf` under both
`kitty/` and `tmux/`, then add a `<name>) apply_theme <name> ;;` case
in `switch-theme.sh`. The `THEMES` array at the top only supplies the
default for `status`/`toggle` when no state file exists yet — `toggle`
itself is currently a hardcoded two-way flip between `vscode-dark` and
`intellij-dark`, so a third theme needs its own explicit toggle logic
if you want `toggle` to cycle through it too.

## Compatibility

- **kitty ≥ 0.37** for full effect (that's when `cursor_trail` in
  `kitty.conf` was added). Older kitty still starts fine — it ignores
  config keys it doesn't recognize with a warning instead of failing
  — you'd just lose that one cosmetic feature. `set-colors`, the
  remote-control command the switcher relies on, has been part of
  kitty's protocol since its earliest releases.
- **tmux ≥ 3.1** (needed for `copy-pipe-no-clear` in the mouse-drag
  copy binding in `tmux.conf`, added around 3.0). The
  `default-terminal` / `terminal-features` detection at the top of
  `tmux.conf` already degrades gracefully below that: an unsupported
  line prints one startup error but doesn't stop the rest of the file
  from loading.
- **macOS and Linux**: every `macos_*` option in `kitty.conf` is a
  no-op on Linux (kitty only applies platform-specific options on
  their platform). `tmux.conf`'s clipboard bindings already branch on
  `uname` for `pbcopy` (macOS) vs. `xclip` (Linux). The theme switcher
  itself is plain POSIX-ish bash (works on macOS's stock bash 3.2 and
  any Linux bash) and uses `/tmp` for kitty's control sockets on both
  platforms.
