#!/usr/bin/env python3
# =============================================================================
# 将环境变量注入 openclaw.json（替代 entrypoint 中多处 jq）
# 用法: inject_openclaw_config.py <config.json 路径>
# 会原地修改该文件；若为 symlink 则应由调用方先复制为实体文件再调用。
# =============================================================================
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path


def ensure_path(obj: dict, path: str) -> None:
    """确保 obj 内存在 path 所表示的嵌套键（缺失则建空 dict）。"""
    keys = path.split(".")
    cur = obj
    for k in keys[:-1]:
        if k not in cur:
            cur[k] = {}
        cur = cur[k]


def set_deep(obj: dict, path: str, value: object) -> None:
    """在 obj 中设置 path（如 'gateway.auth.token'）为 value。"""
    ensure_path(obj, path)
    keys = path.split(".")
    cur = obj
    for k in keys[:-1]:
        cur = cur[k]
    cur[keys[-1]] = value


def main() -> int:
    if len(sys.argv) != 2:
        print("用法: inject_openclaw_config.py <openclaw.json 路径>", file=sys.stderr)
        return 2
    cfg_path = Path(sys.argv[1])
    if not cfg_path.is_file():
        print(f"文件不存在: {cfg_path}", file=sys.stderr)
        return 1

    with open(cfg_path, "r", encoding="utf-8") as f:
        cfg = json.load(f)

    # ------ Gateway：仅注入 auth token；保持 mode=local 以便容器内 openclaw gateway 能启动服务 ------
    token = os.environ.get("OPENCLAW_GATEWAY_TOKEN", "").strip()
    if token:
        set_deep(cfg, "gateway.auth", cfg.get("gateway", {}).get("auth") or {})
        cfg["gateway"]["auth"]["mode"] = "token"
        cfg["gateway"]["auth"]["token"] = token
    # 不改为 remote：remote 会导致 "Gateway start blocked"；CLI 在容器内用 local 即连本机服务

    # ------ 飞书凭证（Gateway 只读 config，不自动用 .env 填 channels）------
    app_id = os.environ.get("FEISHU_APP_ID", "").strip()
    app_secret = os.environ.get("FEISHU_APP_SECRET", "").strip()
    if app_id and app_secret:
        ensure_path(cfg, "channels.feishu.accounts.main")
        cfg["channels"]["feishu"]["accounts"]["main"]["appId"] = app_id
        cfg["channels"]["feishu"]["accounts"]["main"]["appSecret"] = app_secret
        print("[inject_openclaw_config] ✓ 飞书凭证已注入 channels.feishu.accounts.main")

    # ------ LLM providers：LLM_PROVIDER_{NAME}_BASE_URL / API_KEY / MODELS ------
    providers = cfg.setdefault("models", {}).setdefault("providers", {})
    for key, value in os.environ.items():
        m = re.match(r"^LLM_PROVIDER_([A-Za-z0-9]+)_BASE_URL$", key)
        if not m:
            continue
        name = m.group(1)
        pid = name.lower()
        base_url = (value or "").strip()
        api_key_var = f"LLM_PROVIDER_{name}_API_KEY"
        models_var = f"LLM_PROVIDER_{name}_MODELS"
        api_key = (os.environ.get(api_key_var) or "").strip()
        models_csv = (os.environ.get(models_var) or "").strip()
        if not base_url or not api_key:
            print(f"[inject_openclaw_config] 跳过 provider '{pid}'：缺少 BASE_URL 或 API_KEY")
            continue
        models = []
        for part in models_csv.split(","):
            part = part.strip()
            if part:
                models.append({
                    "id": part,
                    "name": part,
                    "reasoning": False,
                    "input": ["text"],
                    "contextWindow": 128000,
                    "maxTokens": 16384,
                })
        providers[pid] = {
            "baseUrl": base_url,
            "apiKey": api_key,
            "api": "openai-completions",
            "models": models,
        }
        print(f"[inject_openclaw_config] ✓ provider '{pid}' 已注入（模型: {models_csv}）")

    # ------ 全局默认模型 ------
    primary = (os.environ.get("LLM_PRIMARY_MODEL") or "").strip()
    if primary:
        set_deep(cfg, "agents.defaults.model.primary", primary)
        print(f"[inject_openclaw_config] ✓ 默认模型设置为 {primary}")

    # ------ Embedding（memory search 向量化）------
    emb_key = (os.environ.get("EMBEDDING_API_KEY") or "").strip()
    if emb_key:
        ensure_path(cfg, "agents.defaults.memorySearch.remote")
        remote = cfg["agents"]["defaults"]["memorySearch"].setdefault("remote", {})
        remote["apiKey"] = emb_key
        remote["baseUrl"] = (
            (os.environ.get("EMBEDDING_BASE_URL") or "").strip()
            or "https://open.bigmodel.cn/api/paas/v4/"
        )
        print(f"[inject_openclaw_config] ✓ Embedding 已注入 memorySearch（baseUrl: {remote['baseUrl']}）")

    with open(cfg_path, "w", encoding="utf-8") as f:
        json.dump(cfg, f, ensure_ascii=False, indent=2)

    return 0


if __name__ == "__main__":
    sys.exit(main())
