#!/usr/bin/env bash
# Install kbd-backlight for one USB keyboard.
# Usage: ./install.sh [--list] [VENDOR:PRODUCT]
set -euo pipefail

REPO=https://github.com/PromiseFru/kbd-backlight
RULE=/etc/udev/rules.d/99-kbd-backlight.rules
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/kbd-backlight"
KEY="${KEY:-Scroll_Lock}"
MEDIA=org.gnome.settings-daemon.plugins.media-keys
SHORTCUT=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/kbd-backlight/

die() {
  echo "$*" >&2
  exit 1
}

# Prints VENDOR:PRODUCT of the USB device that owns an LED, if any.
usb_id() {
  local p
  p=$(readlink -f "$1/device")
  while [[ $p != /sys && $p != / ]]; do
    [[ -r $p/idVendor ]] && {
      echo "$(<"$p/idVendor"):$(<"$p/idProduct")"
      return
    }
    p=${p%/*}
  done
}

# Wrapped in main so a partial download never runs.
main() {
  ((EUID != 0)) || die "run as your normal user, not root; sudo is used only where needed"

  local user
  user=$(id -un)
  [[ $user =~ ^[a-z_][a-z0-9_.-]*$ ]] || die "unsupported user name: $user"

  # Fetch repo files when run through curl.
  local src
  if [[ -f ${BASH_SOURCE[0]:-} && -f $(dirname "${BASH_SOURCE[0]}")/bin/kbd-backlight ]]; then
    src=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  else
    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT
    curl -fsSL --proto '=https' --tlsv1.2 "$REPO/archive/refs/heads/main.tar.gz" |
      tar -xz -C "$TMP" --strip-components=1 --no-same-owner
    src=$TMP
  fi
  cd "$src"

  local d id name ids=() names=()
  for d in /sys/class/leds/input*::scrolllock; do
    [[ -e $d ]] || continue
    id=$(usb_id "$d")
    name=$(<"$d/device/name")
    [[ $id =~ ^[0-9a-f]{4}:[0-9a-f]{4}$ && $name =~ ^[[:print:]]+$ ]] || continue
    ids+=("$id")
    names+=("$name")
  done
  ((${#ids[@]})) || die "no USB keyboard with a Scroll Lock LED found"

  if [[ ${1:-} == --list ]]; then
    for i in "${!ids[@]}"; do echo "${ids[$i]}  ${names[$i]}"; done
    return
  fi

  local i n pick=
  for i in "${!ids[@]}"; do
    if [[ -n ${1:-} ]]; then
      [[ ${ids[$i]} == "$1" ]] && pick=$i
    elif ((${#ids[@]} == 1)); then
      pick=0
    fi
  done
  if [[ -z $pick ]]; then
    [[ -z ${1:-} ]] || die "keyboard $1 not found, see: install.sh --list"
    for i in "${!ids[@]}"; do echo "$((i + 1))) ${ids[$i]}  ${names[$i]}"; done
    read -rp "keyboard number: " n </dev/tty # stdin is the script under curl | bash
    [[ $n =~ ^[0-9]+$ ]] && ((n >= 1 && n <= ${#ids[@]})) || die "invalid choice"
    pick=$((n - 1))
  fi
  id=${ids[$pick]} name=${names[$pick]}
  echo "installing for $name ($id)"

  # udev: LED on at connect, owned by you.
  echo "ACTION==\"add\", SUBSYSTEM==\"leds\", KERNEL==\"input*::scrolllock\", ATTRS{idVendor}==\"${id%:*}\", ATTRS{idProduct}==\"${id#*:}\", ATTR{brightness}=\"1\", RUN+=\"/bin/chown $user /sys%p/brightness\"" |
    sudo tee "$RULE" >/dev/null
  sudo udevadm control --reload
  sudo udevadm trigger --action=add -s leds

  mkdir -p ~/.local/bin ~/.config/systemd/user "$CONF_DIR"
  install -m 755 bin/kbd-backlight ~/.local/bin/kbd-backlight
  install -m 644 systemd/kbd-backlight.service ~/.config/systemd/user/kbd-backlight.service
  echo "$name" >"$CONF_DIR/keyboard"
  systemctl --user daemon-reload
  systemctl --user enable kbd-backlight.service
  systemctl --user restart kbd-backlight.service

  # GNOME shortcut, skipped on other desktops.
  if gsettings list-schemas 2>/dev/null | grep -qx "$MEDIA"; then
    local cur new
    cur=$(gsettings get $MEDIA custom-keybindings)
    if [[ $cur != *"$SHORTCUT"* ]]; then
      if [[ $cur == "@as []" || $cur == "[]" ]]; then new="['$SHORTCUT']"; else new="${cur%]}, '$SHORTCUT']"; fi
      gsettings set $MEDIA custom-keybindings "$new"
    fi
    gsettings set $MEDIA.custom-keybinding:$SHORTCUT name 'Keyboard backlight toggle'
    gsettings set $MEDIA.custom-keybinding:$SHORTCUT command "$HOME/.local/bin/kbd-backlight toggle"
    gsettings set $MEDIA.custom-keybinding:$SHORTCUT binding "$KEY"
    echo "shortcut: $KEY toggles the backlight"
  fi

  echo "done, replug the keyboard to reset any old permissions"
}

main "$@"
