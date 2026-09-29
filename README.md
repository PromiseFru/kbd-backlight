# kbd-backlight

Backlight control for USB keyboards whose backlight is wired to the Scroll Lock LED (common on budget "gaming" keyboards). Works on Wayland and X11.

## Check

```sh
./install.sh --list
```

Lists USB keyboards with a Scroll Lock LED as `VENDOR:PRODUCT  NAME`.

```sh
echo 1 | sudo tee /sys/class/leds/input*::scrolllock/brightness
```

If the backlight turns on, this tool works for your keyboard.

## Install

```sh
./install.sh                  # auto-detect, or pick from a list
./install.sh 1a2c:212a        # a specific keyboard
KEY='<Super>F12' ./install.sh # different GNOME shortcut (default: Scroll_Lock)
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
./uninstall.sh
```

## Files

| Path | Purpose |
|---|---|
| `/etc/udev/rules.d/99-kbd-backlight.rules` | Turns the LED on at connect, lets your group write it |
| `~/.local/bin/kbd-backlight` | Control script |
| `~/.config/systemd/user/kbd-backlight.service` | Re-applies the state after Caps/Num Lock resets it |
| `~/.config/kbd-backlight/keyboard` | Configured keyboard name |
| `~/.local/state/kbd-backlight` | Last on/off state |
