# kbd-backlight

Backlight control for USB keyboards whose backlight is wired to the Scroll Lock LED (common on budget "gaming" keyboards). Works on Wayland and X11.

## Check

```sh
curl -fsSL https://raw.githubusercontent.com/PromiseFru/kbd-backlight/main/install.sh | bash -s -- --list
```

Lists USB keyboards with a Scroll Lock LED as `VENDOR:PRODUCT  NAME`.

```sh
echo 1 | sudo tee /sys/class/leds/input*::scrolllock/brightness
```

If the backlight turns on, this tool works for your keyboard.

## Install

Inspect first:

```sh
curl -fsSL https://raw.githubusercontent.com/PromiseFru/kbd-backlight/main/install.sh | less
```

```sh
curl -fsSL https://raw.githubusercontent.com/PromiseFru/kbd-backlight/main/install.sh | bash                          # auto-detect, or pick from a list
curl -fsSL https://raw.githubusercontent.com/PromiseFru/kbd-backlight/main/install.sh | bash -s -- 1a2c:212a          # a specific keyboard
curl -fsSL https://raw.githubusercontent.com/PromiseFru/kbd-backlight/main/install.sh | KEY='<Super>F12' bash         # different GNOME shortcut (default: Scroll_Lock)
```

From a clone:

```sh
git clone https://github.com/PromiseFru/kbd-backlight.git
cd kbd-backlight
./install.sh
```

## Use

```sh
kbd-backlight on
kbd-backlight off
kbd-backlight toggle
kbd-backlight status
```

On GNOME, Scroll Lock toggles the backlight.

## Check the service

```sh
systemctl --user status kbd-backlight
```

## Uninstall

```sh
curl -fsSL https://raw.githubusercontent.com/PromiseFru/kbd-backlight/main/uninstall.sh | bash
```

From a clone:

```sh
./uninstall.sh
```

## Files

| Path | Purpose |
|---|---|
| `/etc/udev/rules.d/99-kbd-backlight.rules` | Turns the LED on at connect |
| `~/.local/bin/kbd-backlight` | Control script |
| `~/.config/systemd/user/kbd-backlight.service` | Re-applies the state after Caps/Num Lock resets it |
| `~/.config/kbd-backlight/keyboard` | Configured keyboard name |
| `~/.local/state/kbd-backlight` | Last on/off state |
