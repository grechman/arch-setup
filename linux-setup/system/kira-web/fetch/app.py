"""Kira fetch front door.

The only Python we own: a thin HTTP wrapper so the bash `web_fetch` endpoint can
reach trafilatura (fast, static) and crawl4ai (dynamic, headless Chromium) over
loopback HTTP without anyone needing docker-group access.

POST /fetch  {"mode": "fast"|"dynamic", "urls": [...]}
  -> {"results": [ {url, mode, words, markdown} | {url, mode, error}, ... ]}
Order is preserved, one entry per input URL, per-URL errors are isolated.
"""
import asyncio
from contextlib import asynccontextmanager

import httpx
import trafilatura
from fastapi import FastAPI
from pydantic import BaseModel

from crawl4ai import AsyncWebCrawler, BrowserConfig, CrawlerRunConfig

UA = ("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36")

crawler: AsyncWebCrawler | None = None


@asynccontextmanager
async def lifespan(_app: FastAPI):
    # One warm browser, reused across all /dynamic requests.
    global crawler
    crawler = AsyncWebCrawler(config=BrowserConfig(headless=True, verbose=False))
    await crawler.start()
    try:
        yield
    finally:
        await crawler.close()


app = FastAPI(lifespan=lifespan)


class FetchReq(BaseModel):
    mode: str = "fast"
    urls: list[str]


def _words(s: str) -> int:
    return len(s.split()) if s else 0


def _extract_md(html: str, url: str) -> str:
    # output_format="markdown" needs a recent trafilatura; fall back to txt.
    for fmt in ("markdown", "txt"):
        try:
            out = trafilatura.extract(html, url=url, output_format=fmt,
                                      include_links=True)
        except (TypeError, ValueError):
            continue
        if out:
            return out
    return ""


async def _fast_one(client: httpx.AsyncClient, url: str) -> dict:
    try:
        r = await client.get(url, headers={"User-Agent": UA},
                             follow_redirects=True, timeout=20.0)
        r.raise_for_status()
        md = _extract_md(r.text, url)
        if not md.strip():
            return {"url": url, "mode": "fast", "words": 0, "markdown": "",
                    "error": "no extractable content (try --dynamic)"}
        return {"url": url, "mode": "fast", "words": _words(md), "markdown": md}
    except Exception as e:  # noqa: BLE001 - isolate per-URL failure
        return {"url": url, "mode": "fast", "error": f"{type(e).__name__}: {e}"}


async def _fast_batch(urls: list[str]) -> list[dict]:
    async with httpx.AsyncClient() as client:
        return await asyncio.gather(*[_fast_one(client, u) for u in urls])


def _md_text(res) -> str:
    md = getattr(res, "markdown", None)
    if md is None:
        return ""
    # crawl4ai >=0.4 returns a MarkdownGenerationResult; older returns a str.
    fit = getattr(md, "fit_markdown", None)
    if fit:
        return fit
    raw = getattr(md, "raw_markdown", None)
    if raw is not None:
        return raw
    return str(md)


async def _dynamic_batch(urls: list[str]) -> list[dict]:
    cfg = CrawlerRunConfig()
    results = await crawler.arun_many(urls, config=cfg)
    by_url = {getattr(r, "url", None): r for r in results}
    out: list[dict] = []
    for i, u in enumerate(urls):
        res = by_url.get(u)
        if res is None and i < len(results):
            res = results[i]  # fall back to positional if URL changed via redirect
        if res is None:
            out.append({"url": u, "mode": "dynamic", "error": "no result"})
        elif not getattr(res, "success", False):
            out.append({"url": u, "mode": "dynamic",
                        "error": getattr(res, "error_message", "crawl failed")})
        else:
            md = _md_text(res)
            out.append({"url": u, "mode": "dynamic", "words": _words(md),
                        "markdown": md})
    return out


@app.post("/fetch")
async def fetch(req: FetchReq):
    if not req.urls:
        return {"results": []}
    if req.mode == "dynamic":
        return {"results": await _dynamic_batch(req.urls)}
    return {"results": await _fast_batch(req.urls)}


@app.get("/health")
async def health():
    return {"ok": True, "crawler": crawler is not None}
