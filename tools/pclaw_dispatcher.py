#!/usr/bin/env python3
from __future__ import annotations

import fcntl
import hashlib
import json
import os
import re
import subprocess
import sys
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from datetime import datetime, timedelta
from html import unescape
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo

BASE = Path("/home/pclaw/.openclaw")
RUNTIME = BASE / "runtime"
STATE_DIR = RUNTIME / "state"
LOCK_DIR = RUNTIME / "locks"
LOG_DIR = RUNTIME / "logs"
DATA_DIR = BASE / "data"
SOURCES_FILE = RUNTIME / "sources.json"
TARGETS_FILE = RUNTIME / "targets.json"
STATE_FILE = STATE_DIR / "tasks.json"
LOCK_FILE = LOCK_DIR / "dispatcher.lock"
LOG_FILE = LOG_DIR / "dispatcher.log"
TZ = ZoneInfo("Asia/Taipei")


@dataclass
class JobResult:
    ok: bool
    message: str


def ensure_dirs() -> None:
    for path in [
        STATE_DIR,
        LOCK_DIR,
        LOG_DIR,
        DATA_DIR / "market",
        DATA_DIR / "tech",
        DATA_DIR / "ops",
        BASE / "local-data" / "market",
        BASE / "local-data" / "tech",
        BASE / "bin",
    ]:
        path.mkdir(parents=True, exist_ok=True)


def log(event: str, **kwargs: Any) -> None:
    payload = {
        "ts": now_iso(),
        "event": event,
        **kwargs,
    }
    with LOG_FILE.open("a", encoding="utf-8") as f:
        f.write(json.dumps(payload, ensure_ascii=False) + "\n")


def now_tpe() -> datetime:
    return datetime.now(TZ)


def now_iso() -> str:
    return now_tpe().isoformat()


def load_json(path: Path, default: Any) -> Any:
    if not path.exists():
        return default
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default


def save_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def acquire_lock() -> Any:
    LOCK_FILE.parent.mkdir(parents=True, exist_ok=True)
    handle = LOCK_FILE.open("w", encoding="utf-8")
    try:
        fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        print("dispatcher already running", file=sys.stderr)
        sys.exit(0)
    return handle


def read_targets() -> dict[str, Any]:
    return load_json(TARGETS_FILE, {})


def read_sources() -> dict[str, Any]:
    return load_json(SOURCES_FILE, {})


def read_state() -> dict[str, Any]:
    return load_json(STATE_FILE, {"tasks": {}, "lastErrors": []})


def write_state(state: dict[str, Any]) -> None:
    save_json(STATE_FILE, state)


def is_placeholder(value: str | None) -> bool:
    if not value:
        return True
    return "REPLACE_ME" in value


def hhmm_to_minutes(value: str) -> int:
    hh, mm = value.split(":")
    return int(hh) * 60 + int(mm)


def in_window(now_dt: datetime, start: str, end: str) -> bool:
    now_min = now_dt.hour * 60 + now_dt.minute
    start_min = hhmm_to_minutes(start)
    end_min = hhmm_to_minutes(end)
    if start_min <= end_min:
        return start_min <= now_min <= end_min
    return now_min >= start_min or now_min <= end_min


def in_silence(now_dt: datetime, silence_cfg: dict[str, str]) -> bool:
    return in_window(now_dt, silence_cfg["start"], silence_cfg["end"])


def task_key(job_name: str, date_str: str) -> str:
    return f"{job_name}:{date_str}"


def task_status(state: dict[str, Any], job_name: str, date_str: str) -> dict[str, Any]:
    return state["tasks"].get(task_key(job_name, date_str), {})


def set_task_status(
    state: dict[str, Any],
    job_name: str,
    date_str: str,
    payload: dict[str, Any],
) -> None:
    state["tasks"][task_key(job_name, date_str)] = payload


def fetch_text(url: str, timeout: int = 20, headers: dict[str, str] | None = None) -> str:
    req = urllib.request.Request(url, headers=headers or {"User-Agent": "PClawDispatcher/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read().decode("utf-8", errors="ignore")


def fetch_json_url(url: str, timeout: int = 20, headers: dict[str, str] | None = None) -> Any:
    return json.loads(fetch_text(url, timeout=timeout, headers=headers))


def strip_tags(text: str) -> str:
    text = re.sub(r"<script.*?</script>", "", text, flags=re.S | re.I)
    text = re.sub(r"<style.*?</style>", "", text, flags=re.S | re.I)
    text = re.sub(r"<[^>]+>", " ", text)
    text = unescape(text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def read_local_drop(drop_dir: str, limit: int = 10) -> list[dict[str, Any]]:
    path = Path(drop_dir)
    path.mkdir(parents=True, exist_ok=True)
    files = sorted(path.glob("*.json"), key=lambda p: p.stat().st_mtime, reverse=True)[:limit]
    out: list[dict[str, Any]] = []
    for file in files:
        try:
            out.append({
                "file": file.name,
                "data": json.loads(file.read_text(encoding="utf-8")),
            })
        except Exception:
            continue
    return out


def fetch_rss_items(url: str, limit: int = 5) -> list[dict[str, str]]:
    xml_text = fetch_text(url)
    root = ET.fromstring(xml_text)
    items: list[dict[str, str]] = []
    for item in root.findall(".//item")[:limit]:
        items.append({
            "title": (item.findtext("title") or "").strip(),
            "link": (item.findtext("link") or "").strip(),
            "pubDate": (item.findtext("pubDate") or "").strip(),
        })
    return items


def fetch_openai_news(url: str) -> list[dict[str, str]]:
    return fetch_rss_items(url, limit=6)


def fetch_anthropic_news(url: str) -> list[dict[str, str]]:
    html = fetch_text(url)
    matches = re.findall(r'href="(/news/[^"]+)".{0,200}?>(.*?)</a>', html, flags=re.S | re.I)
    items: list[dict[str, str]] = []
    seen: set[str] = set()
    for href, raw_title in matches:
        title = strip_tags(raw_title)
        if not title or title in seen:
            continue
        seen.add(title)
        items.append({
            "title": title,
            "link": urllib.parse.urljoin(url, href),
            "pubDate": "",
        })
        if len(items) >= 6:
            break
    return items


def fetch_arxiv_bundle(urls: list[str]) -> list[dict[str, str]]:
    items: list[dict[str, str]] = []
    seen: set[str] = set()
    for url in urls:
        try:
            for item in fetch_rss_items(url, limit=3):
                if item["title"] in seen:
                    continue
                seen.add(item["title"])
                items.append(item)
        except Exception:
            continue
    return items[:8]


def fetch_twse_taiex_history(url: str) -> dict[str, Any]:
    html = fetch_text(url)
    text = strip_tags(html)
    rows = re.findall(
        r"(\d{4}/\d{2}/\d{2})\s+([\d,]+\.\d+)\s+([\d,]+\.\d+)\s+([\d,]+\.\d+)\s+([\d,]+\.\d+)",
        text,
    )
    if not rows:
        return {"ok": False, "reason": "parse_failed"}
    latest = rows[-1]
    return {
        "ok": True,
        "date": latest[0],
        "open": latest[1],
        "high": latest[2],
        "low": latest[3],
        "close": latest[4],
    }


def fetch_finmind_watchlist(api_base: str, symbols: list[str]) -> dict[str, Any]:
    token = os.environ.get("FINMIND_API_TOKEN", "").strip()
    if not token:
        return {"ok": False, "reason": "missing_token", "items": []}

    end_date = now_tpe().strftime("%Y-%m-%d")
    start_date = (now_tpe() - timedelta(days=10)).strftime("%Y-%m-%d")
    headers = {"Authorization": f"Bearer {token}", "User-Agent": "PClawDispatcher/1.0"}
    items: list[dict[str, Any]] = []

    for symbol in symbols:
        params = urllib.parse.urlencode({
            "dataset": "TaiwanStockPrice",
            "data_id": symbol,
            "start_date": start_date,
            "end_date": end_date,
        })
        url = f"{api_base}?{params}"
        try:
            payload = fetch_json_url(url, headers=headers)
            data = payload.get("data", [])
            if not data:
                continue
            latest = data[-1]
            items.append({
                "symbol": symbol,
                "date": latest.get("date"),
                "open": latest.get("open"),
                "high": latest.get("max"),
                "low": latest.get("min"),
                "close": latest.get("close"),
                "spread": latest.get("spread"),
                "volume": latest.get("Trading_Volume"),
            })
        except Exception:
            continue

    return {"ok": True, "items": items}


def capture_cmd(args: list[str], timeout: int = 30) -> str:
    proc = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    output = (proc.stdout or "") + ("\n" + proc.stderr if proc.stderr else "")
    return output.strip()


def build_market_pack(sources_cfg: dict[str, Any]) -> dict[str, Any]:
    market_cfg = sources_cfg["market"]
    taiex = fetch_twse_taiex_history(market_cfg["twse_taiex_history_url"])
    watchlist = fetch_finmind_watchlist(market_cfg["finmind_api_base"], market_cfg["watchlist"])
    local_notes = read_local_drop(market_cfg["local_drop_dir"])
    pack = {
      "generatedAt": now_iso(),
      "kind": "market",
      "taiex": taiex,
      "watchlist": watchlist,
      "localNotes": local_notes,
    }
    out_file = DATA_DIR / "market" / f"{now_tpe().strftime('%Y-%m-%d')}.json"
    save_json(out_file, pack)
    return pack


def build_tech_pack(sources_cfg: dict[str, Any]) -> dict[str, Any]:
    tech_cfg = sources_cfg["tech"]
    openai_items = fetch_openai_news(tech_cfg["openai_news_rss"])
    anthropic_items = fetch_anthropic_news(tech_cfg["anthropic_news_url"])
    arxiv_items = fetch_arxiv_bundle(tech_cfg["arxiv_feeds"])
    local_notes = read_local_drop(tech_cfg["local_drop_dir"])
    pack = {
      "generatedAt": now_iso(),
      "kind": "tech",
      "openai": openai_items,
      "anthropic": anthropic_items,
      "arxiv": arxiv_items,
      "localNotes": local_notes,
    }
    out_file = DATA_DIR / "tech" / f"{now_tpe().strftime('%Y-%m-%d')}.json"
    save_json(out_file, pack)
    return pack


def build_ops_pack(state: dict[str, Any]) -> dict[str, Any]:
    pack = {
        "generatedAt": now_iso(),
        "kind": "ops",
        "openclawStatus": capture_cmd(["openclaw", "status"]),
        "gatewayStatus": capture_cmd(["openclaw", "gateway", "status"]),
        "channelsStatus": capture_cmd(["openclaw", "channels", "status"]),
        "stateSnapshot": state,
    }
    out_file = DATA_DIR / "ops" / f"{now_tpe().strftime('%Y-%m-%d')}.json"
    save_json(out_file, pack)
    return pack


def compact_json(payload: Any) -> str:
    return json.dumps(payload, ensure_ascii=False, indent=2)


def hash_payload(payload: Any) -> str:
    return hashlib.sha256(compact_json(payload).encode("utf-8")).hexdigest()[:16]


def run_agent_delivery(agent_id: str, message: str, channel: str, target: str, timeout: int = 900) -> JobResult:
    args = [
        "openclaw",
        "agent",
        "--agent", agent_id,
        "--message", message,
        "--deliver",
        "--reply-channel", channel,
        "--reply-to", target,
        "--timeout", str(timeout),
    ]
    proc = subprocess.run(args, capture_output=True, text=True)
    if proc.returncode == 0:
        return JobResult(True, (proc.stdout or "").strip())
    return JobResult(False, ((proc.stdout or "") + "\n" + (proc.stderr or "")).strip())


def market_prompt(pack: dict[str, Any]) -> str:
    return f"""你是 market agent。
今天要產出每日市場摘要。
只能依據以下 evidence pack，不要額外搜尋，不要重跑研究。

輸出要求：
1. 今日市場一句話
2. 主要趨勢（2~4點）
3. 強弱族群
4. 風險提醒
5. 簡短結論（偏多 / 偏空 / 震盪）

限制：
- 繁體中文
- 直接
- 不要 AI 開場白
- 不提供買賣指令
- 若資料不足要明說
- 要區分事實與推論，但不要寫成教科書

evidence pack:
{compact_json(pack)}
"""


def tech_prompt(pack: dict[str, Any]) -> str:
    return f"""你是 tech agent。
今天要產出每日 AI / 科技摘要。
只能依據以下 evidence pack，不要額外搜尋，不要重跑研究。

輸出要求：
1. 今天最重要的一句話
2. 3~5 個重點
3. 這些變化對工具 / 開發 / 產業的意義
4. 簡短結論

限制：
- 繁體中文
- 直接
- 不做新聞堆疊
- 不把 rumor 當 confirmed
- 若資料不足要明說

evidence pack:
{compact_json(pack)}
"""


def ops_prompt(pack: dict[str, Any]) -> str:
    return f"""你是 ops agent。
請根據以下系統資料，產出短版 ops 摘要。

輸出要求：
- 先說整體是否健康
- 再說最重要風險
- 再說今天是否有任務未完成
- 最後給一句處理建議
- 總長控制在 10 行內
- 繁體中文
- 不要做市場或科技研究

evidence pack:
{compact_json(pack)}
"""


def should_run_market(now_dt: datetime, targets: dict[str, Any]) -> bool:
    cfg = targets["jobs"]["market_close_digest"]
    if not cfg.get("enabled", False):
        return False
    if cfg.get("weekdaysOnly", False) and now_dt.weekday() >= 5:
        return False
    return in_window(now_dt, cfg["windowStart"], cfg["windowEnd"])


def should_run_tech(now_dt: datetime, targets: dict[str, Any]) -> bool:
    cfg = targets["jobs"]["tech_evening_digest"]
    if not cfg.get("enabled", False):
        return False
    return in_window(now_dt, cfg["windowStart"], cfg["windowEnd"])


def should_run_ops(now_dt: datetime, targets: dict[str, Any]) -> bool:
    cfg = targets["jobs"]["ops_daily_check"]
    if not cfg.get("enabled", False):
        return False
    return now_dt.hour * 60 + now_dt.minute >= hhmm_to_minutes(cfg["time"])


def handle_job(
    state: dict[str, Any],
    date_str: str,
    job_name: str,
    agent_id: str,
    channel: str,
    target: str,
    pack: dict[str, Any],
    prompt_builder,
) -> None:
    existing = task_status(state, job_name, date_str)
    if existing.get("status") == "done":
        return
    if existing.get("attempts", 0) >= 2:
        return

    if is_placeholder(target):
        set_task_status(state, job_name, date_str, {
            "status": "blocked",
            "attempts": existing.get("attempts", 0),
            "reason": "target_not_configured",
            "updatedAt": now_iso(),
        })
        log("job_blocked", job=job_name, reason="target_not_configured")
        return

    attempt = existing.get("attempts", 0) + 1
    pack_hash = hash_payload(pack)
    result = run_agent_delivery(agent_id, prompt_builder(pack), channel, target)

    if result.ok:
        set_task_status(state, job_name, date_str, {
            "status": "done",
            "attempts": attempt,
            "updatedAt": now_iso(),
            "hash": pack_hash,
        })
        log("job_done", job=job_name, attempt=attempt, hash=pack_hash)
    else:
        set_task_status(state, job_name, date_str, {
            "status": "failed",
            "attempts": attempt,
            "updatedAt": now_iso(),
            "hash": pack_hash,
            "error": result.message[:1200],
        })
        state.setdefault("lastErrors", []).append({
            "job": job_name,
            "ts": now_iso(),
            "error": result.message[:500],
        })
        state["lastErrors"] = state["lastErrors"][-20:]
        log("job_failed", job=job_name, attempt=attempt, error=result.message[:500])


def main() -> int:
    ensure_dirs()
    lock_handle = acquire_lock()
    try:
        now_dt = now_tpe()
        date_str = now_dt.strftime("%Y-%m-%d")
        state = read_state()
        targets = read_targets()
        sources = read_sources()

        if not targets or not sources:
            log("config_missing")
            return 1

        if should_run_ops(now_dt, targets):
            ops_pack = build_ops_pack(state)
            if not in_silence(now_dt, targets["silence"]):
                handle_job(
                    state=state,
                    date_str=date_str,
                    job_name="ops_daily_check",
                    agent_id="ops",
                    channel=targets["ops"]["channel"],
                    target=targets["ops"]["target"],
                    pack=ops_pack,
                    prompt_builder=ops_prompt,
                )

        if should_run_market(now_dt, targets):
            market_pack = build_market_pack(sources)
            handle_job(
                state=state,
                date_str=date_str,
                job_name="market_close_digest",
                agent_id="market",
                channel=targets["market"]["channel"],
                target=targets["market"]["target"],
                pack=market_pack,
                prompt_builder=market_prompt,
            )

        if should_run_tech(now_dt, targets):
            tech_pack = build_tech_pack(sources)
            handle_job(
                state=state,
                date_str=date_str,
                job_name="tech_evening_digest",
                agent_id="tech",
                channel=targets["tech"]["channel"],
                target=targets["tech"]["target"],
                pack=tech_pack,
                prompt_builder=tech_prompt,
            )

        write_state(state)
        log("dispatcher_tick_complete")
        return 0
    finally:
        lock_handle.close()


if __name__ == "__main__":
    raise SystemExit(main())