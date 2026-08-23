import hashlib
import os
import re
import subprocess

HOME = os.path.expanduser("~")
COLORS = f"{HOME}/.config/waybar/colors.css"
OUT = f"{HOME}/.cache/elephant"
GLYPH = "\U000f07c6"
TOP = 16
BOTTOM = 50


def colors():
    found = dict(
        re.findall(r"@define-color\s+(\w+)\s+(#[0-9a-fA-F]{6})", open(COLORS).read())
    )
    return {
        "ok": found.get("ok", "#87a987"),
        "warn": found.get("warn", "#c4b28a"),
        "crit": found.get("critical", "#c4746e"),
        "muted": found.get("fg_muted", "#625e5a"),
    }


def state(p):
    return "ok" if p < 70 else "warn" if p <= 90 else "crit"


def meminfo():
    d = {}
    for line in open("/proc/meminfo"):
        k, v = line.split(":")
        d[k] = int(v.split()[0]) * 1024
    return d


def gb(n):
    return f"{n / 2**30:.1f}G"


def svg(pct, fill, muted):
    h = (BOTTOM - TOP) * pct / 100
    text = f'<text x="25.5" y="54" font-family="JetBrainsMono Nerd Font" font-size="58" text-anchor="middle"'
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">'
        f'<defs><clipPath id="c"><rect x="0" y="{BOTTOM - h}" width="64" height="{h}"/></clipPath></defs>'
        f'{text} fill="{muted}">{GLYPH}</text>'
        f'{text} fill="{fill}" clip-path="url(#c)">{GLYPH}</text>'
        "</svg>"
    )


def frame(pct, c):
    pct = int(round(pct / 2) * 2)
    key = hashlib.md5(
        f"{pct}{c['ok']}{c['warn']}{c['crit']}{c['muted']}".encode()
    ).hexdigest()[:8]
    path = f"{OUT}/ele-{key}.png"
    if not os.path.exists(path):
        os.makedirs(OUT, exist_ok=True)
        tmp = f"{OUT}/ele-{key}.svg"
        open(tmp, "w").write(svg(pct, c[state(pct)], c["muted"]))
        subprocess.run(
            ["rsvg-convert", "-w", "56", "-h", "56", tmp, "-o", path], check=True
        )
        os.remove(tmp)
    return path


def main():
    m = meminfo()
    total = m["MemTotal"]
    used = total - m["MemAvailable"]
    pct = 100 * used / total
    swap_total = m.get("SwapTotal", 0)
    swap_used = swap_total - m.get("SwapFree", 0)
    tip = f"ram {pct:.0f}%  {gb(used)} / {gb(total)}\ncached {gb(m.get('Cached', 0))}"
    if swap_total:
        tip += f"\nswap {gb(swap_used)} / {gb(swap_total)}"
    print(frame(pct, colors()))
    print(tip)


if __name__ == "__main__":
    main()
