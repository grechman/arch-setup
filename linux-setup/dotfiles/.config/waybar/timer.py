import json
import os
import subprocess
import sys
import time

STATE = os.path.expanduser("~/.cache/island/timer.json")
EVENTS = os.path.expanduser("~/.cache/island/events")
ICON = "\U000f051b"


def load():
    try:
        return json.load(open(STATE))
    except (OSError, ValueError):
        return None


def status():
    t = load()
    if not t:
        print(
            json.dumps(
                {"text": ICON, "class": "idle", "tooltip": "timer: click to set"}
            )
        )
        return
    left = int(t["end"] - time.time())
    if left <= 0:
        os.remove(STATE)
        os.makedirs(EVENTS, exist_ok=True)
        json.dump(
            {
                "id": "timer",
                "icon": ICON,
                "text": t.get("label") or "timer done",
                "severity": "info",
                "sound": True,
                "ttl": 6,
            },
            open(f"{EVENTS}/timer-{int(time.time())}.json", "w"),
        )
        print(
            json.dumps(
                {"text": ICON, "class": "idle", "tooltip": "timer: click to set"}
            )
        )
        return
    m, s = divmod(left, 60)
    h, m = divmod(m, 60)
    txt = f"{h}:{m:02d}:{s:02d}" if h else f"{m}:{s:02d}"
    print(
        json.dumps(
            {
                "text": f"{ICON} {txt}",
                "class": "run",
                "tooltip": f"timer: {t.get('label') or ''} click to cancel".strip(),
            }
        )
    )


def menu():
    if load():
        os.remove(STATE)
        return
    rows = ["5 min", "10 min", "15 min", "25 min", "45 min", "60 min"]
    r = subprocess.run(
        ["rofi", "-dmenu", "-i", "-p", "timer, minutes"],
        input="\n".join(rows),
        capture_output=True,
        text=True,
    )
    choice = r.stdout.strip()
    if r.returncode != 0 or not choice:
        return
    try:
        minutes = float(choice.split()[0])
    except ValueError:
        return
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    json.dump(
        {"end": time.time() + minutes * 60, "label": f"{choice.split()[0]} min timer"},
        open(STATE, "w"),
    )


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "menu":
        menu()
    else:
        status()
