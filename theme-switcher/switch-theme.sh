#!/usr/bin/env bash
# Switches kitty + tmux between VS Code Dark and IntelliJ Dark together,
# so the two never drift out of sync with each other.
set -euo pipefail

CONFIG_ROOT="$HOME/.config"
KITTY_THEMES="$CONFIG_ROOT/kitty/themes"
TMUX_THEMES="$CONFIG_ROOT/tmux/themes"
KITTY_LINK="$CONFIG_ROOT/kitty/current-theme.conf"
TMUX_LINK="$CONFIG_ROOT/tmux/current-theme.conf"
STATE_FILE="$CONFIG_ROOT/theme-switcher/current"

THEMES=(vscode-dark intellij-dark)

current_theme() {
  if [[ -f "$STATE_FILE" ]]; then cat "$STATE_FILE"; else echo "${THEMES[0]}"; fi
}

usage() {
  echo "Usage: $(basename "$0") [vscode|intellij|toggle|status]"
  exit 1
}

apply_theme() {
  local name="$1"
  local kfile="$KITTY_THEMES/$name.conf"
  local tfile="$TMUX_THEMES/$name.conf"
  [[ -f "$kfile" ]] || { echo "No kitty theme file: $kfile" >&2; exit 1; }
  [[ -f "$tfile" ]] || { echo "No tmux theme file: $tfile" >&2; exit 1; }

  ln -sf "$kfile" "$KITTY_LINK"
  ln -sf "$tfile" "$TMUX_LINK"
  mkdir -p "$(dirname "$STATE_FILE")"
  echo "$name" > "$STATE_FILE"

  # Each kitty OS window is its own process with its own control socket
  # (see `listen_on` in kitty.conf), so reload every one that's running.
  # set-colors is used (not load-config, which doesn't exist on older
  # kitty) because it's been part of the remote-control protocol since
  # kitty's earliest releases — --all applies it to every window in
  # that process, --configured makes it stick for windows opened later.
  shopt -s nullglob
  for sock in /tmp/kitty-*; do
    [[ -S "$sock" ]] || continue
    kitty @ --to "unix:$sock" set-colors --all --configured "$kfile" >/dev/null 2>&1 || true
  done
  shopt -u nullglob

  # tmux runs a single server shared by all sessions/windows/panes, and
  # the theme only touches global (-g) options, so one reload covers
  # every attached client regardless of which pane triggers it.
  if tmux info >/dev/null 2>&1; then
    tmux source-file "$CONFIG_ROOT/tmux/tmux.conf" >/dev/null 2>&1 || true
  fi

  echo "Theme switched to: $name"
}

case "${1:-}" in
  vscode)   apply_theme vscode-dark ;;
  intellij) apply_theme intellij-dark ;;
  toggle)
    if [[ "$(current_theme)" == "vscode-dark" ]]; then
      apply_theme intellij-dark
    else
      apply_theme vscode-dark
    fi
    ;;
  status) echo "Current theme: $(current_theme)" ;;
  *) usage ;;
esac
