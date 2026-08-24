import json
import os
import re
import signal
import subprocess
import tempfile
import gi

gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import GdkPixbuf, GLib, Gtk, GtkLayerShell

HOME = os.path.expanduser("~")
COLORS = f"{HOME}/.config/waybar/colors.css"
HISTORY = os.environ.get("ISLAND_DIR", f"{HOME}/.cache/island") + "/history.jsonl"
MAX_ROWS = 14


def palette():
    found = dict(
        re.findall(r"@define-color\s+(\w+)\s+(#[0-9a-fA-F]{6})", open(COLORS).read())
    )
    return {
        "bg": found.get("bg", "#181616"),
        "fg": found.get("fg", "#c5c9c5"),
        "fg_alt": found.get("fg_alt", "#a6a69c"),
        "muted": found.get("fg_muted", "#625e5a"),
        "ok": found.get("ok", "#87a987"),
        "warn": found.get("warn", "#c4b28a"),
        "crit": found.get("critical", "#c4746e"),
        "accent": found.get("accent", "#658594"),
    }


def history_rows():
    rows = []
    try:
        lines = open(HISTORY, errors="ignore").read().splitlines()[-MAX_ROWS:]
    except OSError:
        return rows
    for line in reversed(lines):
        try:
            e = json.loads(line)
        except ValueError:
            continue
        rows.append(e)
    return rows


class Overlay(Gtk.Window):
    def __init__(self):
        super().__init__()
        self.pal = palette()
        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.TOP)
        GtkLayerShell.set_namespace(self, "island-overlay")
        for edge in (
            GtkLayerShell.Edge.TOP,
            GtkLayerShell.Edge.BOTTOM,
            GtkLayerShell.Edge.LEFT,
            GtkLayerShell.Edge.RIGHT,
        ):
            GtkLayerShell.set_anchor(self, edge, True)
        GtkLayerShell.set_exclusive_zone(self, -1)
        self.set_app_paintable(True)
        self.shot = grab_blurred()
        css = Gtk.CssProvider()
        p = self.pal
        css.load_from_data(
            f"""
window {{ background: transparent; }}
label {{ font-family: "JetBrainsMono Nerd Font", monospace; }}
#time {{ font-size: 92px; font-weight: 800; color: {p["fg"]}; }}
#date {{ font-size: 19px; color: {p["fg_alt"]}; }}
#empty {{ font-size: 15px; color: {p["muted"]}; }}
#hist label {{ font-size: 15.5px; }}
""".encode()
        )
        Gtk.StyleContext.add_provider_for_screen(
            self.get_screen(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
        root = Gtk.Overlay()
        area = Gtk.DrawingArea()
        area.connect("draw", self.draw_bg)
        root.add(area)
        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        top = Gtk.Box()
        top.set_size_request(-1, 240)
        outer.pack_start(top, False, False, 0)
        self.time_l = Gtk.Label(name="time")
        self.date_l = Gtk.Label(name="date")
        outer.pack_start(self.time_l, False, False, 0)
        outer.pack_start(self.date_l, False, False, 14)
        self.hist = Gtk.Box(
            orientation=Gtk.Orientation.VERTICAL, spacing=10, name="hist"
        )
        self.hist.set_halign(Gtk.Align.CENTER)
        pad = Gtk.Box()
        pad.set_size_request(-1, 60)
        outer.pack_start(pad, False, False, 0)
        outer.pack_start(self.hist, False, False, 0)
        root.add_overlay(outer)
        self.add(root)
        self.tick()
        self.fill()
        GLib.timeout_add(1000, self.tick)
        GLib.timeout_add(5000, self.fill)
        self.set_opacity(0.0)
        self.show_all()
        self.fade(0.0, 1.0, 160)
        GLib.unix_signal_add(GLib.PRIORITY_HIGH, signal.SIGTERM, self.fade_out)

    def draw_bg(self, _w, cr):
        if self.shot:
            aw = self.get_allocated_width() or 1920
            ah = self.get_allocated_height() or 1080
            cr.save()
            cr.scale(aw / self.shot.get_width(), ah / self.shot.get_height())
            from gi.repository import Gdk

            Gdk.cairo_set_source_pixbuf(cr, self.shot, 0, 0)
            cr.paint()
            cr.restore()
        r, g, b = (int(self.pal["bg"][i : i + 2], 16) / 255 for i in (1, 3, 5))
        cr.set_source_rgba(r, g, b, 0.45)
        cr.paint()
        return False

    def fade(self, start, end, ms, done=None):
        steps = max(1, ms // 16)
        state = {"i": 0}

        def step():
            state["i"] += 1
            f = state["i"] / steps
            self.set_opacity(start + (end - start) * f)
            if state["i"] >= steps:
                if done:
                    done()
                return False
            return True

        GLib.timeout_add(16, step)

    def fade_out(self):
        self.fade(1.0, 0.0, 130, Gtk.main_quit)
        return False

    def tick(self):
        import datetime

        now = datetime.datetime.now()
        self.time_l.set_text(now.strftime("%H:%M"))
        self.date_l.set_text(now.strftime("%A %d %B"))
        return True

    def fill(self):
        for ch in self.hist.get_children():
            self.hist.remove(ch)
        rows = history_rows()
        p = self.pal
        colmap = {
            "ok": p["ok"],
            "warn": p["warn"],
            "crit": p["crit"],
            "task": p["fg_alt"],
        }
        if not rows:
            lab = Gtk.Label(name="empty")
            lab.set_text("no alerts yet")
            self.hist.pack_start(lab, False, False, 0)
        for e in rows:
            import datetime

            t = datetime.datetime.fromtimestamp(e.get("at", 0)).strftime("%H:%M")
            col = colmap.get(e.get("severity"), p["fg_alt"])
            icon = e.get("icon", "")
            text = GLib.markup_escape_text(f"{icon} {e.get('text', '')}".strip())
            lab = Gtk.Label()
            lab.set_markup(
                f'<span foreground="{p["muted"]}">{t}</span>  <span foreground="{col}">{text}</span>'
            )
            lab.set_halign(Gtk.Align.CENTER)
            self.hist.pack_start(lab, False, False, 0)
        self.hist.show_all()
        return True


def grab_blurred():
    try:
        tmp = tempfile.mktemp(suffix=".png", dir="/tmp")
        subprocess.run(["grim", "-s", "0.6", tmp], check=True, timeout=3)
        pb = GdkPixbuf.Pixbuf.new_from_file(tmp)
        os.remove(tmp)
        w, h = pb.get_width(), pb.get_height()
        cur = pb
        for div in (2, 4, 8, 16):
            cur = cur.scale_simple(max(1, w // div), max(1, h // div), GdkPixbuf.InterpType.BILINEAR)
        for div in (8, 4, 2, 1):
            cur = cur.scale_simple(max(1, w // div), max(1, h // div), GdkPixbuf.InterpType.BILINEAR)
        return cur
    except Exception:
        return None


def main():
    win = Overlay()
    win.connect("destroy", Gtk.main_quit)
    Gtk.main()


if __name__ == "__main__":
    main()
