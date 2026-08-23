import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone

HOME = os.path.expanduser("~")
CREDS = f"{HOME}/.claude/.credentials.json"
COLORS = f"{HOME}/.config/waybar/colors.css"
CACHE = f"{HOME}/.cache/waybar-usage.json"
LOG = f"{HOME}/.cache/waybar-usage.log"
STALE_AFTER = 600
USAGE_URL = "https://api.anthropic.com/api/oauth/usage"
TOKEN_URLS = [
    "https://platform.claude.com/v1/oauth/token",
    "https://console.anthropic.com/v1/oauth/token",
]
CLIENT_ID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
UA = "claude-code/2.1.241"
WINDOWS = [
    ("gpt", "codex weekly"),
    ("5h", "claude 5h"),
    ("all", "claude weekly"),
    ("fable", "fable weekly"),
]
DIVIDER_AFTER = "gpt"
RESET_GLYPH = {"ok": ("\U000f099b", 10240), "warn": ("\U000f099b", 12800), "crit": ("\U000f099b", 15360)}


def colors():
    text = open(COLORS).read()
    found = dict(re.findall(r"@define-color\s+(\w+)\s+(#[0-9a-fA-F]{6})", text))
    return {
        "ok": found.get("ok", "#87a987"),
        "warn": found.get("warn", "#c4b28a"),
        "crit": found.get("critical", "#c4746e"),
        "muted": found.get("fg_muted", "#625e5a"),
        "accent": found.get("accent", "#658594"),
        "fg_alt": found.get("fg_alt", "#a6a69c"),
    }


def state(p):
    return "ok" if p < 70 else "warn" if p <= 90 else "crit"


def presence(p):
    weight = (
        100
        if p < 15
        else 300
        if p < 35
        else 400
        if p < 55
        else 500
        if p < 70
        else 700
        if p < 90
        else 800
    )
    size = round((11.5 + p / 100 * 6.5) * 0.75 * 1024)
    alpha = round(55 + 45 * p / 100)
    return weight, size, alpha


def fmt_reset(ts):
    if ts is None:
        return ""
    return datetime.fromtimestamp(ts).strftime("%a %H:%M")


def parse_iso(s):
    if not s:
        return None
    return (
        datetime.fromisoformat(s.replace("Z", "+00:00"))
        .astimezone(timezone.utc)
        .timestamp()
    )


def http_json(url, data=None, headers=None):
    req = urllib.request.Request(
        url, data=data, headers=headers or {}, method="POST" if data else "GET"
    )
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.load(r)


def refresh_claude(creds, oauth):
    body = json.dumps(
        {
            "grant_type": "refresh_token",
            "refresh_token": oauth["refreshToken"],
            "client_id": CLIENT_ID,
        }
    ).encode()
    last = None
    for url in TOKEN_URLS:
        try:
            r = http_json(
                url, body, {"Content-Type": "application/json", "User-Agent": UA}
            )
            break
        except (urllib.error.URLError, urllib.error.HTTPError, ValueError) as e:
            last = e
    else:
        raise last
    oauth["accessToken"] = r["access_token"]
    oauth["refreshToken"] = r.get("refresh_token", oauth["refreshToken"])
    oauth["expiresAt"] = int((time.time() + r["expires_in"]) * 1000)
    tmp = CREDS + ".tmp"
    with open(tmp, "w") as f:
        json.dump(creds, f)
    os.chmod(tmp, 0o600)
    os.replace(tmp, CREDS)
    return oauth["accessToken"]


def claude_token():
    creds = json.load(open(CREDS))
    oauth = creds["claudeAiOauth"]
    if oauth.get("expiresAt", 0) / 1000 > time.time() + 120:
        return oauth["accessToken"]
    return refresh_claude(creds, oauth)


def window(d, key):
    v = d.get(key)
    if isinstance(v, dict) and v.get("utilization") is not None:
        return {
            "pct": round(float(v["utilization"])),
            "reset": parse_iso(v.get("resets_at")),
        }
    return None


def fetch_claude():
    token = claude_token()
    d = http_json(
        USAGE_URL,
        headers={
            "Authorization": f"Bearer {token}",
            "anthropic-beta": "oauth-2025-04-20",
            "User-Agent": UA,
        },
    )
    out = {"5h": window(d, "five_hour"), "all": window(d, "seven_day"), "fable": None}
    for lim in d.get("limits") or []:
        if lim.get("percent") is None:
            continue
        entry = {"pct": round(float(lim["percent"])), "reset": parse_iso(lim.get("resets_at"))}
        kind = lim.get("kind")
        model = ((lim.get("scope") or {}).get("model") or {}).get("display_name") or ""
        if kind == "session":
            out["5h"] = entry
        elif kind == "weekly_all":
            out["all"] = entry
        elif kind == "weekly_scoped" and "fable" in model.lower():
            out["fable"] = entry
    return {k: v for k, v in out.items() if v}


def fetch_codex():
    p = subprocess.Popen(
        ["codex", "app-server", "--stdio"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    try:

        def send(o):
            p.stdin.write(json.dumps(o) + "\n")
            p.stdin.flush()

        send(
            {
                "id": 1,
                "method": "initialize",
                "params": {
                    "clientInfo": {
                        "name": "waybar-usage",
                        "title": "waybar usage",
                        "version": "0.1.0",
                    }
                },
            }
        )
        send({"method": "initialized"})
        send({"id": 2, "method": "account/rateLimits/read", "params": {}})
        deadline = time.time() + 40
        while time.time() < deadline:
            line = p.stdout.readline()
            if not line:
                break
            try:
                o = json.loads(line)
            except ValueError:
                continue
            if o.get("id") == 2:
                if "result" not in o:
                    raise RuntimeError(f"codex app-server: {json.dumps(o.get('error'))[:300]}")
                rl = o["result"]["rateLimits"]
                wins = [w for w in (rl.get("primary"), rl.get("secondary")) if w]
                weekly = max(wins, key=lambda w: w.get("windowDurationMins", 0))
                credits = o["result"].get("rateLimitResetCredits") or {}
                return {
                    "gpt": {
                        "pct": round(float(weekly["usedPercent"])),
                        "reset": weekly.get("resetsAt"),
                        "resets_available": int(credits.get("availableCount") or 0),
                        "resets_expire": min(
                            (cr.get("expiresAt") for cr in credits.get("credits") or [] if cr.get("status") == "available" and cr.get("expiresAt")),
                            default=None,
                        ),
                    }
                }
        raise RuntimeError("codex app-server timeout")
    finally:
        p.kill()


def load_cache():
    try:
        return json.load(open(CACHE))
    except (OSError, ValueError):
        return {}


def save_cache(c):
    os.makedirs(os.path.dirname(CACHE), exist_ok=True)
    tmp = CACHE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(c, f)
    os.replace(tmp, CACHE)


def collect():
    cache = load_cache()
    now = time.time()
    fresh = {}
    errors = []
    for fetch in (fetch_codex, fetch_claude):
        try:
            for k, v in fetch().items():
                fresh[k] = dict(v, ts=now)
        except Exception as e:
            msg = f"{fetch.__name__[6:]}: {type(e).__name__}: {e}"
            errors.append(msg)
            with open(LOG, "a") as f:
                f.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} {msg}\n")
    cache.update(fresh)
    save_cache(cache)
    return cache, fresh, errors


def span(text, color, weight=400, size=None, alpha=None):
    attrs = f'foreground="{color}" weight="{weight}"'
    if size:
        attrs += f' size="{size}"'
    if alpha is not None:
        attrs += f' alpha="{alpha}%"'
    return f"<span {attrs}>{text}</span>"


def render(cache, fresh, errors):
    c = colors()
    cells = []
    worst = "ok"
    stale = False
    tip = []
    pcts = []
    for key, name in WINDOWS:
        v = cache.get(key)
        sigil = span(f"{key} ", c["fg_alt"], alpha=70)
        if not v:
            cells.append(sigil + span("--", c["muted"], alpha=60))
            tip.append(f"{name:<14} no data")
            continue
        p = max(0, min(100, int(v["pct"])))
        pcts.append(p)
        is_stale = time.time() - v.get("ts", 0) > STALE_AFTER
        w, size, alpha = presence(p)
        if is_stale:
            stale = True
            cells.append(sigil + span(f"{p:>2d}", c["muted"], w, size, 60))
            age = int((time.time() - v.get("ts", 0)) / 60)
            tip.append(
                f"{name:<14}{p:>4}%  stale {age} min  resets {fmt_reset(v.get('reset'))}"
            )
        else:
            s = state(p)
            if ["ok", "warn", "crit"].index(s) > ["ok", "warn", "crit"].index(worst):
                worst = s
            cell = sigil + span(f"{p:>2d}", c[s], w, size, alpha)
            n = v.get("resets_available", 0)
            if n:
                glyph, gsize = RESET_GLYPH[s]
                cell += " " + span(glyph, c["accent"], size=gsize)
                if n > 1:
                    cell += span(str(n), c["accent"], 500, 8704)
            cells.append(cell)
            tip.append(f"{name:<14}{p:>4}%  resets {fmt_reset(v.get('reset'))}")
            if n:
                exp = v.get("resets_expire")
                until = datetime.fromtimestamp(exp).strftime("%m/%d") if exp else ""
                word = "reset" if n == 1 else "resets"
                tip.append(f"{n:>19}  {word:<6} til {until}")
    parts = []
    for (key, _), cell in zip(WINDOWS, cells):
        parts.append(cell)
        if key == DIVIDER_AFTER:
            parts.append(span("│", c["muted"]))
    text = "  ".join(parts)
    tip.extend(errors)
    return {
        "text": text,
        "tooltip": "\n".join(tip),
        "class": "stale" if stale else worst,
        "percentage": max(pcts) if pcts else 0,
    }


def main():
    cache, fresh, errors = collect()
    print(json.dumps(render(cache, fresh, errors)))


if __name__ == "__main__":
    main()
