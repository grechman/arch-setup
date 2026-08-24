import calendar
import glob
import json
import os
import re
import socket
import subprocess
import sys
import threading
import time
import urllib.request
from datetime import date, datetime

HOME = os.path.expanduser("~")
COLORS = f"{HOME}/.config/waybar/colors.css"
CONFIG = f"{HOME}/.config/waybar/island.json"
STATE_DIR = os.environ.get("ISLAND_DIR", f"{HOME}/.cache/island")
EVENTS_DIR = f"{STATE_DIR}/events"
TASKS_DIR = f"{STATE_DIR}/tasks"
DATE_FLAG = f"{STATE_DIR}/showdate"
GH_SEEN = f"{STATE_DIR}/github-seen.json"
NTFY_TOPIC_FILE = f"{HOME}/.config/island/ntfy-topic"
SOUND = "/usr/share/sounds/freedesktop/stereo/dialog-warning.oga"
SOUNDS = {
    "warning": "/usr/share/sounds/freedesktop/stereo/dialog-warning.oga",
    "complete": "/usr/share/sounds/freedesktop/stereo/complete.oga",
    "bell": "/usr/share/sounds/freedesktop/stereo/bell.oga",
    "message": "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga",
}
TICK = 0.05
GROW = 0.3
FADE = 0.15
SHRINK = 0.3
CLOCK_OUT = 0.12
CLOCK_FILE = f"{STATE_DIR}/clock.json"
DOT_FILE = f"{STATE_DIR}/dot.json"
CLOCK_SIGNAL = 10
BLANK = "\u200b"
DATE_SECONDS = 4
TAILNET_HOST = ("100.90.140.3", 22)
ICONS = {
    "charging": "\U000f0084",
    "low": "\U000f007b",
    "critical": "\U000f0083",
    "date": "\U000f00ed",
    "full": "\U000f0085",
    "wifi": "\U000f05a9",
    "wifi_off": "\U000f05aa",
    "wifi_change": "\U000f16c7",
    "tailnet_down": "\U000f0319",
    "tailnet_up": "\U000f0318",
    "github": "\U000f02a4",
    "bt": "\U000f00b1",
    "bt_off": "\U000f00b2",
    "ram": "\U000f07c6",
}
DEFAULT = {
    "sound": True,
    "seconds": 3.0,
    "history_ignore": ["charging", "low", "critical", "full", "wifi", "bt-", "btb-", "ram", "date", "test"],
    "producers": {
        "charging": True,
        "low": True,
        "critical": True,
        "external": True,
        "wifi": True,
        "tailnet": True,
        "ram": True,
        "bluetooth": True,
        "battery_full": True,
        "github": True,
    },
}
LOW_AT = 15
CRITICAL_AT = 5
RAM_AT = 90
RAM_REARM = 85
SEVERITY_RANK = {"task": 0, "info": 1, "good": 2, "bad": 3, "crit": 4}
SEV_ALIAS = {"ok": "info", "warn": "info", "low": "info"}


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
        "fg_alt": found.get("fg_alt", "#a6a69c"),
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


def run(cmd, timeout=5):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.stdout if r.returncode == 0 else ""
    except Exception:
        return ""


class Island:
    def __init__(self):
        os.makedirs(EVENTS_DIR, exist_ok=True)
        os.makedirs(TASKS_DIR, exist_ok=True)
        self.queue = []
        self.current = None
        self.started = 0.0
        self.last_out = None
        self.last_clock = None
        self.last_dot = None
        self.task_grow_until = 0.0
        self.prev_task = False
        self.task_seen = -10.0
        self.task_w = {}
        self.last_plain = ""
        self.last_wk = 1
        self.last_label_at = -10.0
        self.last_dot_cls = "ok"
        self.prev_status = None
        self.low_fired_at = None
        self.full_fired = False
        self.date_until = 0.0
        self.wifi = self.wifi_state()
        self.wifi_next = 0.0
        self.tail_next = 30.0
        self.tail_fails = 0
        self.tail_down = False
        self.ram_fired = False
        self.bt = self.bt_state()
        self.bt_next = 0.0
        self.bt_batt_next = 0.0
        self.bt_batt_fired = set()
        self.gh_next = 20.0

    def push(self, ev):
        if any(e["id"] == ev["id"] for e in self.queue) or (
            self.current and self.current["id"] == ev["id"]
        ):
            return
        self.queue.append(ev)
        self.queue.sort(key=lambda e: -SEVERITY_RANK.get(e.get("severity"), 0))

    def wifi_state(self):
        for line in run(
            ["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "d"], 4
        ).splitlines():
            parts = line.split(":")
            if parts[0] == "wifi":
                return (
                    parts[2]
                    if len(parts) > 2 and parts[1] == "connected" and parts[2]
                    else None
                )
        return None

    def bt_state(self):
        out = {}
        for line in run(["bluetoothctl", "devices", "Connected"], 4).splitlines():
            parts = line.split(None, 2)
            if len(parts) == 3 and parts[0] == "Device":
                out[parts[1]] = parts[2]
        return out

    def battery_producers(self, p):
        cap, status = battery()
        if cap is None:
            return
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
                    "severity": "info",
                }
            )
        self.prev_status = status
        if status == "Discharging":
            self.full_fired = False
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
                            "severity": "bad",
                        }
                    )
                    self.low_fired_at = step
        else:
            self.low_fired_at = None
            if cap >= 100 and p["battery_full"] and not self.full_fired:
                self.push(
                    {
                        "id": "full",
                        "icon": ICONS["full"],
                        "text": "100%, unplug",
                        "severity": "info",
                    }
                )
                self.full_fired = True

    def wifi_producer(self, now):
        if now < self.wifi_next:
            return
        self.wifi_next = now + 2.0
        cur = self.wifi_state()
        if cur == self.wifi:
            return
        if cur and not self.wifi:
            self.push(
                {"id": "wifi", "icon": ICONS["wifi"], "text": cur, "severity": "info"}
            )
        elif cur and self.wifi:
            self.push(
                {
                    "id": "wifi",
                    "icon": ICONS["wifi_change"],
                    "text": cur,
                    "severity": "info",
                }
            )
        else:
            self.push(
                {
                    "id": "wifi",
                    "icon": ICONS["wifi_off"],
                    "text": "no wifi",
                    "severity": "bad",
                }
            )
        self.wifi = cur

    def tailnet_producer(self, now):
        if now < self.tail_next:
            return
        self.tail_next = now + 60.0
        if not self.wifi:
            return
        ok = False
        try:
            with socket.create_connection(TAILNET_HOST, timeout=1.5):
                ok = True
        except OSError:
            pass
        if ok:
            if self.tail_down:
                self.push(
                    {
                        "id": "tailnet",
                        "icon": ICONS["tailnet_up"],
                        "text": "tailnet back",
                        "severity": "good",
                    }
                )
            self.tail_down = False
            self.tail_fails = 0
        else:
            self.tail_fails += 1
            if self.tail_fails >= 2 and not self.tail_down:
                self.tail_down = True
                self.push(
                    {
                        "id": "tailnet",
                        "icon": ICONS["tailnet_down"],
                        "text": "tailnet silent",
                        "severity": "bad",
                    }
                )

    def ram_producer(self):
        d = {}
        for line in open("/proc/meminfo"):
            k, v = line.split(":")
            d[k] = int(v.split()[0])
            if k == "MemAvailable":
                break
        pct = 100 * (1 - d["MemAvailable"] / d["MemTotal"])
        if pct >= RAM_AT and not self.ram_fired:
            self.push(
                {
                    "id": "ram",
                    "icon": ICONS["ram"],
                    "text": f"ram {pct:.0f}%",
                    "severity": "bad",
                }
            )
            self.ram_fired = True
        elif pct < RAM_REARM:
            self.ram_fired = False

    def bt_producer(self, now):
        if now >= self.bt_next:
            self.bt_next = now + 3.0
            cur = self.bt_state()
            for mac, name in cur.items():
                if mac not in self.bt:
                    self.push(
                        {
                            "id": f"bt-{mac}",
                            "icon": ICONS["bt"],
                            "text": name[:24],
                            "severity": "info",
                        }
                    )
            for mac, name in self.bt.items():
                if mac not in cur:
                    self.push(
                        {
                            "id": f"bt-{mac}",
                            "icon": ICONS["bt_off"],
                            "text": name[:24],
                            "severity": "info",
                        }
                    )
                    self.bt_batt_fired.discard(mac)
            self.bt = cur
        if now >= self.bt_batt_next:
            self.bt_batt_next = now + 60.0
            for mac, name in self.bt.items():
                if mac in self.bt_batt_fired:
                    continue
                m = re.search(
                    r"Battery Percentage.*\((\d+)\)",
                    run(["bluetoothctl", "info", mac], 4),
                )
                if m and int(m.group(1)) <= 20:
                    self.push(
                        {
                            "id": f"btb-{mac}",
                            "icon": ICONS["bt"],
                            "text": f"{name[:18]} {m.group(1)}%",
                            "severity": "bad",
                        }
                    )
                    self.bt_batt_fired.add(mac)

    def github_producer(self, now):
        if now < self.gh_next:
            return
        self.gh_next = now + 180.0
        out = run(["gh", "api", "notifications"], 15)
        if not out:
            return
        try:
            seen = set(json.load(open(GH_SEEN)))
        except (OSError, ValueError):
            seen = set()
        try:
            items = json.loads(out)
        except ValueError:
            return
        new = [n for n in items if n.get("id") not in seen]
        for n in new[:2]:
            repo = n.get("repository", {}).get("name", "")
            title = n.get("subject", {}).get("title", "")[:26]
            self.push(
                {
                    "id": f"gh-{n['id']}",
                    "icon": ICONS["github"],
                    "text": f"{repo}: {title}",
                    "severity": "info",
                    "ttl": 6,
                }
            )
        if new:
            seen |= {n["id"] for n in items}
            json.dump(sorted(seen)[-500:], open(GH_SEEN, "w"))

    def external_producer(self):
        for path in sorted(glob.glob(f"{EVENTS_DIR}/*.json")):
            try:
                ev = json.load(open(path))
                os.remove(path)
            except (OSError, ValueError):
                continue
            if isinstance(ev, dict) and ev.get("text"):
                ev.setdefault("id", os.path.basename(path)[:-5])
                ev.setdefault("icon", "")
                ev.setdefault("severity", "info")
                ev["severity"] = SEV_ALIAS.get(ev["severity"], ev["severity"])
                self.push(ev)

    def producers(self, cfg):
        now = time.monotonic()
        p = cfg["producers"]
        self.battery_producers(p)
        if p["wifi"]:
            self.wifi_producer(now)
        if p["tailnet"]:
            self.tailnet_producer(now)
        if p["ram"]:
            self.ram_producer()
        if p["bluetooth"]:
            self.bt_producer(now)
        if p["github"]:
            self.github_producer(now)
        if p["external"]:
            self.external_producer()

    def task(self):
        files = sorted(glob.glob(f"{TASKS_DIR}/*.json"), key=os.path.getmtime)
        if not files:
            self.task_w = {}
            return None
        try:
            t = json.load(open(files[-1]))
        except (OSError, ValueError):
            return None
        if not isinstance(t, dict):
            return None
        t.setdefault("icon", "")
        t.setdefault("dot", "ok")
        t["count"] = len(files) - 1
        t["_id"] = os.path.basename(files[-1])
        return t

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
        return self.phase2(age, ttl, GROW)

    def phase2(self, age, ttl, g):
        if age < g:
            return "grow"
        if age < ttl - FADE - g:
            return "show"
        if age < ttl - g:
            return "fade"
        return "shrink"

    def width_class(self, text, icon):
        px = len(text) * 9.3 + (22 if icon else 0) + 24
        return f"w{max(1, min(14, -(-int(px) // 30)))}"

    def wdur(self, wcls):
        return min(0.16 + 0.025 * int(wcls[1:]), 0.4) + 0.04

    def alert_pop(self, cfg, now):
        if not self.current and now < self.date_until:
            self.current = {"id": "date", "icon": ICONS["date"], "text": datetime.now().strftime("%A %d %B"), "severity": "info", "ttl": DATE_SECONDS}
            self.started = now
            self.date_until = 0.0
        if not self.current and self.queue:
            self.current = self.queue.pop(0)
            self.started = now
            snd = self.current.get("sound")
            if snd and cfg["sound"]:
                spath = SOUNDS.get(snd, SOUND) if isinstance(snd, str) else SOUND
                subprocess.Popen(["pw-play", spath], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            eid = self.current.get("id", "")
            if not any(eid.startswith(p) for p in cfg.get("history_ignore", [])):
                try:
                    with open(f"{STATE_DIR}/history.jsonl", "a") as f:
                        f.write(json.dumps(dict(self.current, at=time.time())) + "\n")
                except OSError:
                    pass

    def task_clock(self, t, clock, c):
        eta = t.get("eta")
        pre = f'<span foreground="{c["fg_alt"]}">eta {eta}</span>  ' if eta else ""
        return {"text": pre + clock, "class": ["on", "task"]}

    def render(self, cfg, now):
        c = colors()
        clock = datetime.now().strftime("%H:%M")
        nodot = {"text": "", "class": ["idle"]}
        idle = ({"text": BLANK, "class": ["idle"]}, {"text": clock, "class": ["idle"]}, nodot)
        self.alert_pop(cfg, now)
        t = self.task()
        if t:
            plain = " ".join(x for x in [t["icon"], t.get("text", ""), t.get("progress", "")] if x)
            if t["count"]:
                plain += f" +{t['count']}"
            eta = t.get("eta")
            label = plain
            if eta:
                plain += f"  eta {eta}"
                label += f'  <span foreground="{c["muted"]}">eta {eta}</span>'
            k = int(self.width_class(plain, "")[1:])
            k = max(k, self.task_w.get(t["_id"], 0))
            self.task_w[t["_id"]] = k
            wt = f"w{k}"
            self.last_dot_cls = t["dot"]
            dot = {"text": "●", "class": ["task", t["dot"]]}
            tclock = {"text": clock, "class": ["on", "task"]}
        if not self.prev_task and t:
            self.task_grow_until = now + self.wdur(wt)
        self.prev_task = bool(t)
        if t:
            self.task_seen = now
        grace = (now - self.task_seen) < 0.8
        if self.current:
            ev = self.current
            ttl = max(float(ev.get("ttl") or cfg["seconds"]), CLOCK_OUT + GROW + FADE + SHRINK + 0.5)
            age = now - self.started
            if age >= ttl:
                self.current = None
                self.task_grow_until = 0.0
                return self.render(cfg, now)
            ph = self.phase(age, ttl)
            sev = SEV_ALIAS.get(ev.get("severity", "info"), ev.get("severity", "info"))
            if "_wk" not in ev:
                wtext = re.sub(r"<[^>]+>", "", ev["text"])
                ka = int(self.width_class(wtext, ev["icon"])[1:])
                recent = now - self.last_label_at < 0.6
                ev["_wk"] = ka
                ev["_from"] = self.last_wk if recent else ka
                ev["_morph"] = recent
                span = max(ka, ev["_from"])
                ev["_g"] = (0.13 + self.wdur(f"w{span}")) if recent else self.wdur(f"w{ka}")
            wa = f"w{ev['_wk']}"
            text = f'{ev["icon"]} {ev["text"]}'.strip()
            if t or grace:
                base = ["on", sev]
                if not t:
                    tclock = {"text": clock, "class": ["on"]}
                    dot = {"text": BLANK, "class": ["gone-dot"]}
                g = ev["_g"]
                if self.queue and age >= ttl - g:
                    self.current = None
                    return self.render(cfg, now)
                ph = self.phase2(age, ttl, g)
                done = ["done"] if ev.get("kind") == "done" and ph == "show" else []
                pulse = ["pulse"] if sev == "crit" and ph in ("grow", "show") else []
                ptclock = dict(tclock, **{"class": tclock["class"] + pulse + done})
                pdot = dict(dot, **{"class": dot["class"] + pulse})
                if ph == "grow":
                    if age < 0.13 and ev.get("_morph"):
                        return {"text": self.last_plain, "class": base + [f"w{ev['_from']}"] + pulse}, ptclock, pdot
                    return {"text": BLANK, "class": base + [wa] + pulse}, ptclock, pdot
                if ph == "show":
                    self.task_seen = now
                    self.last_plain, self.last_wk, self.last_label_at = text, ev["_wk"], now
                    return {"text": text, "class": base + [wa, "show"] + pulse + done}, ptclock, pdot
                if ph == "fade":
                    self.task_seen = now
                    calm = [x for x in base if x != "crit"]
                    fclock = dict(tclock, **{"class": [x for x in tclock["class"] if x != "done"]})
                    return {"text": text, "class": calm + [wa]}, fclock, pdot
                if t:
                    return {"text": BLANK, "class": base + [wt]}, tclock, pdot
                return {"text": BLANK, "class": ["on", sev, "gone"]}, {"text": clock, "class": ["idle"]}, {"text": BLANK, "class": ["gone-dot"]}
            base = ["on", sev, wa, "solo"]
            hidden = {"text": clock, "class": ["gone"]}
            co = 0.0 if ev.get("_morph") else CLOCK_OUT
            if age < co:
                return {"text": BLANK, "class": ["idle"]}, hidden, nodot
            g = ev["_g"]
            if self.queue and age - co >= ttl - co - g:
                self.current = None
                return self.render(cfg, now)
            ph = self.phase2(age - co, ttl - co, g)
            pulse = ["pulse"] if sev == "crit" else []
            if ph == "grow":
                if age - co < 0.13 and ev.get("_morph"):
                    return {"text": self.last_plain, "class": ["on", sev, f"w{ev['_from']}", "solo"] + pulse}, hidden, nodot
                return {"text": BLANK, "class": base + pulse}, hidden, nodot
            if ph == "show":
                self.last_plain, self.last_wk, self.last_label_at = text, ev["_wk"], now
                return {"text": text, "class": base + ["show"] + pulse}, hidden, nodot
            if ph == "fade":
                calm = [x for x in base if x != "crit"]
                return {"text": text, "class": calm}, hidden, nodot
            return {"text": BLANK, "class": ["on", sev, "solo", "gone"]}, hidden, nodot
        if t:
            if now < self.task_grow_until:
                return {"text": BLANK, "class": ["on", "task", wt]}, tclock, dot
            self.last_plain, self.last_wk, self.last_label_at = plain, int(wt[1:]), now
            return {"text": label, "class": ["on", "task", "show", wt]}, tclock, dot
        return idle

    def loop(self):
        last_prod = 0.0
        while True:
            now = time.monotonic()
            cfg = load_config()
            if now - last_prod >= 1.0:
                self.producers(cfg)
                last_prod = now
            elif cfg["producers"]["external"]:
                self.external_producer()
            if os.path.exists(DATE_FLAG):
                os.remove(DATE_FLAG)
                self.date_until = now + DATE_SECONDS
            ev_out, clock_out, dot_out = self.render(cfg, now)
            clock_out["tooltip"] = self.tooltip()
            changed = False
            for out, attr, path in ((clock_out, "last_clock", CLOCK_FILE), (dot_out, "last_dot", DOT_FILE)):
                if out != getattr(self, attr):
                    tmp = path + ".tmp"
                    with open(tmp, "w") as f:
                        json.dump(out, f)
                    os.replace(tmp, path)
                    setattr(self, attr, out)
                    changed = True
            if changed:
                subprocess.run(["pkill", f"-RTMIN+{CLOCK_SIGNAL}", "-x", "waybar"], stderr=subprocess.DEVNULL)
            if ev_out != self.last_out:
                sys.stdout.write(json.dumps(ev_out) + "\n")
                sys.stdout.flush()
                self.last_out = ev_out
            time.sleep(TICK)


def ntfy_thread():
    try:
        topic = open(NTFY_TOPIC_FILE).read().strip()
    except OSError:
        return
    if not topic:
        return
    while True:
        try:
            req = urllib.request.Request(
                f"https://ntfy.sh/{topic}/json", headers={"User-Agent": "island"}
            )
            with urllib.request.urlopen(req, timeout=300) as r:
                for raw in r:
                    try:
                        m = json.loads(raw)
                    except ValueError:
                        continue
                    if m.get("event") != "message":
                        continue
                    sev = "crit" if m.get("priority", 3) >= 4 else "info"
                    ev = {
                        "id": f"ntfy-{m.get('id')}",
                        "icon": ICONS["tailnet_up"],
                        "text": (m.get("title") or m.get("message") or "")[:30],
                        "severity": sev,
                        "ttl": 6,
                    }
                    if sev == "crit":
                        ev["sound"] = True
                    json.dump(ev, open(f"{EVENTS_DIR}/ntfy-{m.get('id')}.json", "w"))
        except Exception:
            pass
        time.sleep(15)


def menu():
    cfg = load_config()
    keys = [
        "charging",
        "low",
        "critical",
        "wifi",
        "tailnet",
        "ram",
        "bluetooth",
        "battery_full",
        "github",
        "external",
    ]
    labels = {
        "charging": "charging",
        "low": f"low battery {LOW_AT}%",
        "critical": f"critical battery {CRITICAL_AT}%",
        "wifi": "wifi",
        "tailnet": "tailnet",
        "ram": f"ram {RAM_AT}%",
        "bluetooth": "bluetooth",
        "battery_full": "battery full",
        "github": "github",
        "external": "events from scripts",
    }
    while True:
        rows = [
            "notifications",
            f"sound on critical: {'on' if cfg['sound'] else 'off'}",
            f"show for: {cfg['seconds']:g} s",
        ]
        rows += [f"{labels[k]}: {'on' if cfg['producers'][k] else 'off'}" for k in keys]
        rows += ["clear tasks", "test alert"]
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
            subprocess.Popen(["swaync-client", "-t", "-sw"])
            return
        if idx == 1:
            cfg["sound"] = not cfg["sound"]
        elif idx == 2:
            cfg["seconds"] = 2.0 if cfg["seconds"] >= 5 else cfg["seconds"] + 0.5
        elif 3 <= idx < 3 + len(keys):
            key = keys[idx - 3]
            cfg["producers"][key] = not cfg["producers"][key]
        elif idx == 3 + len(keys):
            for f in glob.glob(f"{TASKS_DIR}/*.json"):
                os.remove(f)
        else:
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
        threading.Thread(target=ntfy_thread, daemon=True).start()
        Island().loop()
