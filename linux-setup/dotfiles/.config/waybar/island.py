import calendar
import glob
import json
import os
import re
import subprocess
import sys
import time
from datetime import date, datetime

HOME = os.path.expanduser("~")
COLORS = f"{HOME}/.config/waybar/colors.css"
CONFIG = f"{HOME}/.config/waybar/island.json"
STATE_DIR = f"{HOME}/.cache/island"
EVENTS_DIR = f"{STATE_DIR}/events"
DATE_FLAG = f"{STATE_DIR}/showdate"
SOUND = "/usr/share/sounds/freedesktop/stereo/dialog-warning.oga"
TICK = 0.05
GROW = 0.45
FADE = 0.25
SHRINK = 0.45
CLOCK_FILE = f"{STATE_DIR}/clock.json"
CLOCK_SIGNAL = 10
BLANK = "\u200b"
DATE_SECONDS = 4
ICONS = {
    "charging": "\U000f0084",
    "low": "\U000f007b",
    "critical": "\U000f0083",
    "date": "\U000f00ed",
}
DEFAULT = {
    "sound": True,
    "seconds": 3.0,
    "producers": {"charging": True, "low": True, "critical": True, "external": True},
}
LOW_AT = 15
CRITICAL_AT = 5
SEVERITY_RANK = {"ok": 0, "warn": 1, "crit": 2}


def load_config():
    try:
        raw = json.load(open(CONFIG))
    except (OSError, ValueError):
        raw = {}
    cfg = json.loads(json.dumps(DEFAULT))
    cfg.update({k: v for k, v in raw.items() if k != "producers"})
    cfg["producers"].update(raw.get("producers", {}))
    return cfg


def save_config(cfg):
    tmp = CONFIG + ".tmp"
    json.dump(cfg, open(tmp, "w"), indent=2)
    os.replace(tmp, CONFIG)


def colors():
    found = dict(
        re.findall(r"@define-color\s+(\w+)\s+(#[0-9a-fA-F]{6})", open(COLORS).read())
    )
    return {
        "ok": found.get("ok", "#87a987"),
        "warn": found.get("warn", "#c4b28a"),
        "crit": found.get("critical", "#c4746e"),
        "fg": found.get("fg", "#c5c9c5"),
        "muted": found.get("fg_muted", "#625e5a"),
        "accent": found.get("accent", "#658594"),
    }


def battery():
    for bat in glob.glob("/sys/class/power_supply/BAT*"):
        try:
            cap = int(open(f"{bat}/capacity").read())
            status = open(f"{bat}/status").read().strip()
            return cap, status
        except (OSError, ValueError):
            continue
    return None, None


class Island:
    def __init__(self):
        os.makedirs(EVENTS_DIR, exist_ok=True)
        self.queue = []
        self.current = None
        self.started = 0.0
        self.last_out = None
        self.prev_status = None
        self.low_fired_at = None
        self.date_until = 0.0

    def push(self, ev):
        if any(e["id"] == ev["id"] for e in self.queue) or (
            self.current and self.current["id"] == ev["id"]
        ):
            return
        self.queue.append(ev)
        self.queue.sort(key=lambda e: -SEVERITY_RANK.get(e.get("severity"), 0))

    def producers(self, cfg):
        p = cfg["producers"]
        cap, status = battery()
        if cap is not None:
            if (
                status != self.prev_status
                and self.prev_status is not None
                and status == "Charging"
                and p["charging"]
            ):
                self.push(
                    {
                        "id": "charging",
                        "icon": ICONS["charging"],
                        "text": f"{cap}%",
                        "severity": "ok",
                    }
                )
            self.prev_status = status
            if status == "Discharging":
                if cap <= CRITICAL_AT and p["critical"]:
                    if self.low_fired_at is None or self.low_fired_at > cap:
                        self.push(
                            {
                                "id": "critical",
                                "icon": ICONS["critical"],
                                "text": f"{cap}%",
                                "severity": "crit",
                                "sound": True,
                            }
                        )
                        self.low_fired_at = cap
                elif cap <= LOW_AT and p["low"]:
                    step = (cap // 5) * 5
                    if self.low_fired_at is None or self.low_fired_at > step:
                        self.push(
                            {
                                "id": "low",
                                "icon": ICONS["low"],
                                "text": f"{cap}%",
                                "severity": "warn",
                            }
                        )
                        self.low_fired_at = step
            else:
                self.low_fired_at = None
        if p["external"]:
            for path in sorted(glob.glob(f"{EVENTS_DIR}/*.json")):
                try:
                    ev = json.load(open(path))
                    os.remove(path)
                except (OSError, ValueError):
                    continue
                if isinstance(ev, dict) and ev.get("text"):
                    ev.setdefault("id", os.path.basename(path)[:-5])
                    ev.setdefault("icon", "")
                    ev.setdefault("severity", "warn")
                    self.push(ev)

    def tooltip(self):
        today = date.today()
        month = calendar.TextCalendar(calendar.MONDAY).formatmonth(
            today.year, today.month
        )
        lines = month.rstrip("\n").split("\n")
        body = "\n".join(lines[2:])
        body = re.sub(
            rf"(?<!\d){today.day:>2}(?!\d)", f"<b>{today.day:>2}</b>", body, count=1
        )
        return (
            f"<big>{lines[0].strip()}</big>\n<tt><small>{lines[1]}\n{body}</small></tt>"
        )

    def phase(self, age, ttl):
        if age < GROW:
            return "grow"
        if age < ttl - FADE - SHRINK:
            return "show"
        if age < ttl - SHRINK:
            return "fade"
        return "shrink"

    def width_class(self, ev):
        px = len(ev["text"]) * 9.3 + (22 if ev.get("icon") else 0) + 14
        return f"w{max(1, min(8, -(-int(px) // 30)))}"

    def render(self, cfg, now):
        clock = datetime.now().strftime("%H:%M")
        if not self.current and now < self.date_until:
            self.current = {"id": "date", "icon": ICONS["date"], "text": datetime.now().strftime("%A %d %B"), "severity": "ok", "ttl": DATE_SECONDS}
            self.started = now
            self.date_until = 0.0
        if not self.current and self.queue:
            self.current = self.queue.pop(0)
            self.started = now
            if self.current.get("sound") and cfg["sound"]:
                subprocess.Popen(["pw-play", SOUND], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if not self.current:
            return {"text": BLANK, "class": ["idle"]}, {"text": clock, "class": ["idle"]}
        ev = self.current
        ttl = max(float(ev.get("ttl") or cfg["seconds"]), GROW + FADE + SHRINK + 0.5)
        age = now - self.started
        if age >= ttl:
            self.current = None
            return self.render(cfg, now)
        ph = self.phase(age, ttl)
        sev = ev.get("severity", "warn")
        base = ["on", sev, self.width_class(ev)]
        if ph == "shrink":
            return {"text": BLANK, "class": ["idle"]}, {"text": clock, "class": ["idle"]}
        text = BLANK if ph == "grow" else f'{ev["icon"]} {ev["text"]}'.strip()
        cls = base + (["show"] if ph == "show" else [])
        return {"text": text, "class": cls}, {"text": clock, "class": base}

    def run(self):
        last_prod = 0.0
        last_clock = None
        while True:
            now = time.monotonic()
            cfg = load_config()
            if now - last_prod >= 1.0:
                self.producers(cfg)
                last_prod = now
            if os.path.exists(DATE_FLAG):
                os.remove(DATE_FLAG)
                self.date_until = now + DATE_SECONDS
            ev_out, clock_out = self.render(cfg, now)
            clock_out["tooltip"] = self.tooltip()
            if clock_out != last_clock:
                tmp = CLOCK_FILE + ".tmp"
                with open(tmp, "w") as f:
                    json.dump(clock_out, f)
                os.replace(tmp, CLOCK_FILE)
                subprocess.run(["pkill", f"-RTMIN+{CLOCK_SIGNAL}", "-x", "waybar"], stderr=subprocess.DEVNULL)
                last_clock = clock_out
            if ev_out != self.last_out:
                sys.stdout.write(json.dumps(ev_out) + "\n")
                sys.stdout.flush()
                self.last_out = ev_out
            time.sleep(TICK)


def menu():
    cfg = load_config()
    while True:
        rows = [
            f"sound on critical: {'on' if cfg['sound'] else 'off'}",
            f"show for: {cfg['seconds']:g} s",
            f"charging: {'on' if cfg['producers']['charging'] else 'off'}",
            f"low battery {LOW_AT}%: {'on' if cfg['producers']['low'] else 'off'}",
            f"critical battery {CRITICAL_AT}%: {'on' if cfg['producers']['critical'] else 'off'}",
            f"events from scripts: {'on' if cfg['producers']['external'] else 'off'}",
            "test alert",
        ]
        r = subprocess.run(
            ["rofi", "-dmenu", "-i", "-p", "island", "-no-custom"],
            input="\n".join(rows),
            capture_output=True,
            text=True,
        )
        choice = r.stdout.strip()
        if r.returncode != 0 or not choice:
            return
        idx = rows.index(choice)
        if idx == 0:
            cfg["sound"] = not cfg["sound"]
        elif idx == 1:
            cfg["seconds"] = 2.0 if cfg["seconds"] >= 5 else cfg["seconds"] + 0.5
        elif idx in (2, 3, 4, 5):
            key = ["charging", "low", "critical", "external"][idx - 2]
            cfg["producers"][key] = not cfg["producers"][key]
        elif idx == 6:
            os.makedirs(EVENTS_DIR, exist_ok=True)
            json.dump(
                {
                    "id": "test",
                    "icon": ICONS["critical"],
                    "text": "test",
                    "severity": "crit",
                    "sound": True,
                },
                open(f"{EVENTS_DIR}/test.json", "w"),
            )
            return
        save_config(cfg)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "menu":
        menu()
    else:
        Island().run()
