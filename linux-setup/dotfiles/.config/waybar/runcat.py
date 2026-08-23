import os
import re
import signal
import subprocess
import sys
import time

HOME = os.path.expanduser("~")
SRC = f"{HOME}/.config/waybar/runcat"
COLORS = f"{HOME}/.config/waybar/colors.css"
OUT = f"{HOME}/.cache/runcat"
FRAME_FILE = f"{OUT}/cat.txt"
SIZE = 28
FRAMES = ["cat-0", "cat-1", "cat-2", "cat-3", "cat-4"]
IDLE = "cat-idle"
SIGNAL = 8
SLEEP_BELOW = 5
SLOWEST_MS = 500
FASTEST_MS = 50


def color():
    m = re.search(r"@define-color\s+fg_alt\s+(#[0-9a-fA-F]{6})", open(COLORS).read())
    return m.group(1) if m else "#a6a69c"


def render(col):
    os.makedirs(OUT, exist_ok=True)
    for name in FRAMES + [IDLE]:
        svg = open(f"{SRC}/{name}.svg").read().replace("#bebebe", col)
        tmp = f"{OUT}/{name}.svg"
        open(tmp, "w").write(svg)
        subprocess.run(
            [
                "rsvg-convert",
                "-w",
                str(SIZE),
                "-h",
                str(SIZE),
                tmp,
                "-o",
                f"{OUT}/{name}.png",
            ],
            check=True,
        )
        os.remove(tmp)


def read_stat():
    total = None
    cores = []
    for line in open("/proc/stat"):
        if not line.startswith("cpu"):
            break
        vals = [int(x) for x in line.split()[1:]]
        pair = (vals[3] + vals[4], sum(vals))
        if line[3] == " ":
            total = pair
        else:
            cores.append(pair)
    return total, cores


def pct(prev, cur):
    dt = cur[1] - prev[1]
    return 100.0 * (1 - (cur[0] - prev[0]) / dt) if dt else 0.0


def top_process():
    try:
        r = subprocess.run(
            ["ps", "-eo", "pcpu,comm", "--sort=-pcpu", "--no-headers"],
            capture_output=True,
            text=True,
            timeout=2,
        )
        line = r.stdout.strip().splitlines()[0].split(None, 1)
        return f"{line[1]} {float(line[0]):.0f}%"
    except Exception:
        return ""


def write_frame(name, tip):
    tmp = FRAME_FILE + ".tmp"
    with open(tmp, "w") as f:
        f.write(f"{OUT}/{name}.png\n{tip}\n")
    os.replace(tmp, FRAME_FILE)
    subprocess.run(
        ["pkill", f"-RTMIN+{SIGNAL}", "-x", "waybar"], stderr=subprocess.DEVNULL
    )


def main():
    css_mtime = os.path.getmtime(COLORS)
    render(color())
    prev_total, prev_cores = read_stat()
    load = 0.0
    tip = "cpu 0%"
    frame = 0
    last_sample = time.monotonic()
    last_tip = 0.0
    while True:
        now = time.monotonic()
        if now - last_sample >= 1.0:
            total, cores = read_stat()
            load = load * 0.5 + pct(prev_total, total) * 0.5
            per_core = [pct(p, c) for p, c in zip(prev_cores, cores)]
            prev_total, prev_cores = total, cores
            last_sample = now
            if now - last_tip >= 3.0:
                top = top_process()
                core_txt = "  ".join(f"{c:3.0f}%" for c in per_core)
                tip = f"cpu {load:3.0f}%\ncores {core_txt}" + (
                    f"\ntop {top}" if top else ""
                )
                last_tip = now
            mt = os.path.getmtime(COLORS)
            if mt != css_mtime:
                css_mtime = mt
                render(color())
        if load < SLEEP_BELOW:
            write_frame(IDLE, tip)
            time.sleep(1.0)
            continue
        frame = (frame + 1) % len(FRAMES)
        write_frame(FRAMES[frame], tip)
        ms = SLOWEST_MS - (min(load, 100) - SLEEP_BELOW) / (100 - SLEEP_BELOW) * (
            SLOWEST_MS - FASTEST_MS
        )
        time.sleep(ms / 1000)


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    main()
