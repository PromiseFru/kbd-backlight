#!/usr/bin/env bash
# Install kbd-backlight for one USB keyboard.
# Usage: ./install.sh [--list] [VENDOR:PRODUCT]
set -euo pipefail
cd "$(dirname "$0")"

RULE=/etc/udev/rules.d/99-kbd-backlight.rules
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/kbd-backlight"
KEY="${KEY:-Scroll_Lock}"
MEDIA=org.gnome.settings-daemon.plugins.media-keys
SHORTCUT=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/kbd-backlight/

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

ids=() names=()
for d in /sys/class/leds/input*::scrolllock; do
  [[ -e $d ]] || continue
  id=$(usb_id "$d")
  [[ -n $id ]] || continue
  ids+=("$id")
  names+=("$(<"$d/device/name")")
done
((${#ids[@]})) || {
  echo "no USB keyboard with a Scroll Lock LED found" >&2
  exit 1
}

if [[ ${1:-} == --list ]]; then
  for i in "${!ids[@]}"; do echo "${ids[$i]}  ${names[$i]}"; done
  exit 0
fi

pick=
for i in "${!ids[@]}"; do
  if [[ -n ${1:-} ]]; then
    [[ ${ids[$i]} == "$1" ]] && pick=$i
  elif ((${#ids[@]} == 1)); then
    pick=0
  fi
done
if [[ -z $pick ]]; then
  [[ -n ${1:-} ]] && {
    echo "keyboard $1 not found, see ./install.sh --list" >&2
    exit 1
  }
  for i in "${!ids[@]}"; do echo "$((i + 1))) ${ids[$i]}  ${names[$i]}"; done
  read -rp "keyboard number: " n
  pick=$((n - 1))
  [[ -n ${ids[$pick]:-} ]] || {
    echo "invalid choice" >&2
    exit 1
  }
fi
id=${ids[$pick]} name=${names[$pick]}
vendor=${id%:*} product=${id#*:}
echo "installing for $name ($id)"

# udev: turn the LED on when the keyboard connects and let your group control it.
echo "ACTION==\"add\", SUBSYSTEM==\"leds\", KERNEL==\"input*::scrolllock\", ATTRS{idVendor}==\"$vendor\", ATTRS{idProduct}==\"$product\", ATTR{brightness}=\"1\", RUN+=\"/bin/chgrp $(id -gn) /sys%p/brightness\", RUN+=\"/bin/chmod g+w /sys%p/brightness\"" |
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

echo "done"
