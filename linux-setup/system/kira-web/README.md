# Kira web tools

Two device-wide CLI tools for an LLM agent:

- `web_search "<query>"` — ranked title/url/snippet from a local SearXNG.
- `web_fetch <url...> [--fast|--dynamic]` — one or many pages to clean markdown.
  `--fast` (default) = curl + trafilatura. `--dynamic` = crawl4ai headless Chromium.

Both are thin bash clients of two loopback HTTP services, so every user on the
box can call them with **no docker-group access**.

```
searxng     127.0.0.1:8888   metasearch JSON API
kira-fetch  127.0.0.1:8899   POST /fetch  {mode, urls[]}
```

## Install (system-wide, all users)

The image `kira-fetch:1` is already built and lives in the shared docker image
store, so the systemd stack reuses it with no rebuild.

```bash
# 0. stop the staging stack so it frees the container names + ports
docker compose -f ~/kira-web/docker-compose.yml down

# 1. copy the project into /opt
sudo mkdir -p /opt/kira-web && sudo cp -r ~/kira-web/* /opt/kira-web/

# 2. give SearXNG a fresh secret (replaces whatever value is there)
sudo sed -i -E "s|^  secret_key:.*|  secret_key: \"$(openssl rand -hex 32)\"|" /opt/kira-web/searxng/settings.yml

# 3. endpoints onto PATH for everyone
sudo install -m 755 ~/kira-web/web_search ~/kira-web/web_fetch /usr/local/bin/

# 4. start now + at every boot via systemd
sudo cp /opt/kira-web/systemd/kira-web.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now kira-web.service
```

## Verify

```bash
web_search "anthropic claude" --count 3
web_fetch https://example.com
web_fetch https://example.com https://en.wikipedia.org/wiki/Web_scraping   # batch
web_fetch <js-heavy-spa-url> --dynamic
sudo systemctl status kira-web
```

## Notes

- The fetch image is large (~1.3-1.7 GB) because of Chromium. Inherent to `--dynamic`.
- After the first good build, pin versions: `docker exec kira-fetch pip freeze | grep -iE 'crawl4ai|trafilatura|fastapi|uvicorn|httpx'` and paste into `fetch/requirements.txt`.
- SearXNG limiter is off because the service is loopback-only. Re-enable it in
  `searxng/settings.yml` if you ever expose the port.
- Env overrides: `KIRA_SEARX_URL`, `KIRA_FETCH_URL`, `KIRA_FETCH_THIN`.
