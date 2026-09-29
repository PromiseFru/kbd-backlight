#!/usr/bin/env bash
# Remove kbd-backlight.
# Usage: ./uninstall.sh
set -uo pipefail

MEDIA=org.gnome.settings-daemon.plugins.media-keys
SHORTCUT=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/kbd-backlight/

# Wrapped in main so a partial download never runs.
main() {
  ((EUID != 0)) || {
    echo "run as your normal user, not root; sudo is used only where needed" >&2
    exit 1
  }

  systemctl --user disable --now kbd-backlight.service 2>/dev/null
  rm -f ~/.config/systemd/user/kbd-backlight.service ~/.local/bin/kbd-backlight
  rm -rf "${XDG_CONFIG_HOME:-$HOME/.config}/kbd-backlight" "${XDG_STATE_HOME:-$HOME/.local/state}/kbd-backlight"
  systemctl --user daemon-reload

  sudo rm -f /etc/udev/rules.d/99-kbd-backlight.rules
  sudo udevadm control --reload

  if gsettings list-schemas 2>/dev/null | grep -qx "$MEDIA"; then
    local cur new
    cur=$(gsettings get $MEDIA custom-keybindings)
    new=$(echo "$cur" | sed "s#, '$SHORTCUT'##; s#'$SHORTCUT', ##; s#'$SHORTCUT'##")
    [[ $new == "[]" ]] && new="@as []"
    gsettings set $MEDIA custom-keybindings "$new"
    gsettings reset-recursively $MEDIA.custom-keybinding:$SHORTCUT
  fi

  echo "done, replug the keyboard to reset its permissions"
}

main "$@"
