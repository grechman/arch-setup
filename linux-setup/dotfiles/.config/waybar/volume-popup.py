#!/usr/bin/env python3
import atexit
import json
import os
import re
import signal
import subprocess
import sys
from pathlib import Path

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gdk, GLib, Gtk, GtkLayerShell


APP_ID = "waybar-volume-popup"
WIDTH = 138
HEIGHT = 54
BAR_WIDTH = 16
BLOCKS = " ▏▎▍▌▋▊▉█"


def run(cmd, timeout=0.7):
    return subprocess.run(
        cmd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        timeout=timeout,
        check=False,
    )


def read_volume():
    proc = run(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"])
    match = re.search(r"Volume:\s+([0-9.]+)", proc.stdout)
    if not match:
        return 0, False
    muted = "MUTED" in proc.stdout
    value = round(float(match.group(1)) * 100)
    return max(0, min(100, value)), muted


def set_volume(value):
    value = max(0, min(100, int(value)))
    if value == 0:
        run(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "0"])
        run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "1"])
        return
    run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "0"])
    run(["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", f"{value / 100:.2f}"])


def parse_colors():
    colors = {
        "bg": "#181616",
        "fg": "#c5c9c5",
        "fg_alt": "#a6a69c",
        "accent": "#658594",
    }
    path = Path.home() / ".config/waybar/colors.css"
    if not path.exists():
        return colors
    pattern = re.compile(r"@define-color\s+([A-Za-z0-9_]+)\s+(#[0-9A-Fa-f]{6})")
    for line in path.read_text(errors="ignore").splitlines():
        match = pattern.search(line)
        if match:
            colors[match.group(1)] = match.group(2)
    return colors


def popup_position():
    cursor = run(["hyprctl", "cursorpos"]).stdout.strip().replace(",", "")
    try:
        cursor_x, cursor_y = (int(part) for part in cursor.split()[:2])
    except ValueError:
        cursor_x, cursor_y = 0, 0

    proc = run(["hyprctl", "-j", "monitors"])
    try:
        monitors = json.loads(proc.stdout)
    except json.JSONDecodeError:
        monitors = []

    monitor = None
    for candidate in monitors:
        x = int(candidate.get("x", 0))
        y = int(candidate.get("y", 0))
        w = int(candidate.get("width", 1920))
        h = int(candidate.get("height", 1080))
        if x <= cursor_x < x + w and y <= cursor_y < y + h:
            monitor = candidate
            break
    if monitor is None:
        monitor = monitors[0] if monitors else {"x": 0, "y": 0, "width": 1920, "height": 1080, "reserved": [0, 27, 0, 0]}

    mon_x = int(monitor.get("x", 0))
    mon_y = int(monitor.get("y", 0))
    mon_w = int(monitor.get("width", 1920))
    mon_h = int(monitor.get("height", 1080))
    x = cursor_x - WIDTH // 2
    y = mon_y + 4
    x = max(mon_x + 8, min(x, mon_x + mon_w - WIDTH - 8))
    y = max(mon_y + 4, min(y, mon_y + mon_h - HEIGHT - 8))
    return x - mon_x, y - mon_y


def toggle_existing():
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp"))
    pidfile = runtime / "waybar-volume-popup.pid"
    if pidfile.exists():
        try:
            pid = int(pidfile.read_text().strip())
            os.kill(pid, 0)
        except (OSError, ValueError):
            pidfile.unlink(missing_ok=True)
        else:
            cmdline = Path(f"/proc/{pid}/cmdline")
            try:
                command = cmdline.read_text(errors="ignore").replace("\0", " ")
            except OSError:
                command = ""
            if APP_ID not in command and "volume-popup.py" not in command:
                pidfile.unlink(missing_ok=True)
            elif pid != os.getpid():
                os.kill(pid, signal.SIGTERM)
                return True

    pidfile.write_text(str(os.getpid()))

    def cleanup():
        try:
            if pidfile.read_text().strip() == str(os.getpid()):
                pidfile.unlink(missing_ok=True)
        except OSError:
            pass

    atexit.register(cleanup)
    return False


class VolumePopup:
    def __init__(self):
        self.colors = parse_colors()
        self.pending_value = None
        self.dragging = False
        self.value, muted = read_volume()
        if muted:
            self.value = 0

        self.window = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
        self.window.set_title(APP_ID)
        self.window.set_name(APP_ID)
        self.window.set_decorated(False)
        self.window.set_resizable(False)
        self.window.set_default_size(WIDTH, HEIGHT)
        self.window.set_size_request(WIDTH, HEIGHT)
        self.window.connect("destroy", Gtk.main_quit)
        self.window.connect("key-press-event", self.on_key)

        GtkLayerShell.init_for_window(self.window)
        GtkLayerShell.set_namespace(self.window, APP_ID)
        GtkLayerShell.set_layer(self.window, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_keyboard_mode(self.window, GtkLayerShell.KeyboardMode.ON_DEMAND)
        GtkLayerShell.set_anchor(self.window, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(self.window, GtkLayerShell.Edge.LEFT, True)
        x, y = popup_position()
        GtkLayerShell.set_margin(self.window, GtkLayerShell.Edge.LEFT, x)
        GtkLayerShell.set_margin(self.window, GtkLayerShell.Edge.TOP, y)

        self.event_box = Gtk.EventBox()
        self.event_box.set_name("root")
        self.event_box.set_size_request(WIDTH, HEIGHT)
        self.event_box.add_events(
            Gdk.EventMask.BUTTON_PRESS_MASK
            | Gdk.EventMask.BUTTON_RELEASE_MASK
            | Gdk.EventMask.POINTER_MOTION_MASK
            | Gdk.EventMask.SCROLL_MASK
            | Gdk.EventMask.LEAVE_NOTIFY_MASK
        )
        self.event_box.connect("button-press-event", self.on_press)
        self.event_box.connect("motion-notify-event", self.on_motion)
        self.event_box.connect("button-release-event", self.on_release)
        self.event_box.connect("leave-notify-event", self.on_leave)
        self.event_box.connect("scroll-event", self.on_scroll)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        box.set_margin_top(7)
        box.set_margin_bottom(7)
        box.set_margin_start(8)
        box.set_margin_end(8)

        self.value_label = Gtk.Label(xalign=0)
        self.value_label.set_name("value")
        self.bar_label = Gtk.Label(xalign=0)
        self.bar_label.set_name("meter")

        box.pack_start(self.value_label, False, False, 0)
        box.pack_start(self.bar_label, False, False, 0)
        self.event_box.add(box)
        self.window.add(self.event_box)

        self.apply_style()
        self.update_label(self.value)
        GLib.timeout_add(1000, self.refresh_volume)

    def apply_style(self):
        c = self.colors
        css = f"""
            window#{APP_ID} {{
                background: transparent;
            }}
            #root {{
                background-color: alpha({c["bg"]}, 0.94);
                border: none;
                border-radius: 6px;
            }}
            label {{
                font-family: "JetBrainsMono Nerd Font", monospace;
                font-size: 12px;
                font-weight: 700;
            }}
            #value {{
                color: {c["fg_alt"]};
            }}
            #meter {{
                color: {c["accent"]};
                letter-spacing: 0;
            }}
        """
        provider = Gtk.CssProvider()
        provider.load_from_data(css.encode())
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

    def update_label(self, value):
        value = max(0, min(100, int(value)))
        units = round((value / 100) * BAR_WIDTH * 8)
        full_blocks, partial = divmod(units, 8)
        bar = "█" * full_blocks
        if full_blocks < BAR_WIDTH:
            bar += BLOCKS[partial]
            bar += " " * (BAR_WIDTH - full_blocks - 1)
        self.value_label.set_text(f"volume {value:3d}%")
        self.bar_label.set_text(bar)

    def set_pending(self, value):
        self.value = max(0, min(100, int(value)))
        self.update_label(self.value)
        self.pending_value = self.value
        GLib.timeout_add(45, self.flush_volume_once)

    def flush_volume_once(self):
        if self.pending_value is not None:
            set_volume(self.pending_value)
            self.pending_value = None
        return False

    def value_from_x(self, x):
        left = 12
        right = max(left + 1, WIDTH - 12)
        value = round(((x - left) / (right - left)) * 100)
        return max(0, min(100, value))

    def on_press(self, _widget, event):
        if event.button == 1:
            self.dragging = True
            self.set_pending(self.value_from_x(event.x))
            return True
        return False

    def on_motion(self, _widget, event):
        if self.dragging:
            self.set_pending(self.value_from_x(event.x))
            return True
        return False

    def on_release(self, _widget, event):
        if event.button == 1:
            self.dragging = False
            self.flush_volume_once()
            return True
        return False

    def on_leave(self, *_args):
        self.dragging = False
        return False

    def on_scroll(self, _widget, event):
        if event.direction == Gdk.ScrollDirection.UP:
            self.set_pending(self.value + 5)
        elif event.direction == Gdk.ScrollDirection.DOWN:
            self.set_pending(self.value - 5)
        return True

    def on_key(self, _widget, event):
        if event.keyval == Gdk.KEY_Escape:
            self.window.destroy()
            return True
        if event.keyval in (Gdk.KEY_Right, Gdk.KEY_Up):
            self.set_pending(self.value + 5)
            return True
        if event.keyval in (Gdk.KEY_Left, Gdk.KEY_Down):
            self.set_pending(self.value - 5)
            return True
        return False

    def refresh_volume(self):
        if self.dragging or self.pending_value is not None:
            return True
        value, muted = read_volume()
        self.value = 0 if muted else value
        self.update_label(self.value)
        return True

    def show(self):
        self.window.show_all()


def main():
    if toggle_existing():
        return 0
    popup = VolumePopup()
    popup.show()
    Gtk.main()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
