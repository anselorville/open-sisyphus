#!/usr/bin/env python3
# =============================================================================
# 从 openclaw-runtime.json 注入到 openclaw.json（Gateway/飞书/模型/Embedding）
# 用法: inject_openclaw_config.py --runtime <openclaw-runtime.json> <openclaw.json 路径>
# 容器启动时由 entrypoint 调用；改配置后执行 reapply_openclaw_config 可热重载。
# =============================================================================
from __future__ import annotations

import argparse
import json
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


def apply_runtime(cfg: dict, rt: dict) -> None:
    """把 runtime 配置合并进 openclaw cfg。"""
    # ------ Gateway token ------
    token = (rt.get("gateway") or {}).get("token") or ""
    if isinstance(token, str):
        token = token.strip()
    if token:
        set_deep(cfg, "gateway.auth", cfg.get("gateway", {}).get("auth") or {})
        cfg["gateway"]["auth"]["mode"] = "token"
        cfg["gateway"]["auth"]["token"] = token

    # ------ 飞书 ------
    feishu = (rt.get("channels") or {}).get("feishu") or {}
    app_id = (feishu.get("appId") or "").strip()
    app_secret = (feishu.get("appSecret") or "").strip()
    if app_id and app_secret:
        ensure_path(cfg, "channels.feishu.accounts.main")
        cfg["channels"]["feishu"]["accounts"]["main"]["appId"] = app_id
        cfg["channels"]["feishu"]["accounts"]["main"]["appSecret"] = app_secret
        print("[inject_openclaw_config] ✓ 飞书凭证已注入 channels.feishu.accounts.main")

    # ------ LLM providers + 默认模型 ------
    models_cfg = rt.get("models") or {}
    providers_src = models_cfg.get("providers") or {}
    providers = cfg.setdefault("models", {}).setdefault("providers", {})

    for pid, p in providers_src.items():
        if not isinstance(p, dict):
            continue
        base_url = (p.get("baseUrl") or "").strip()
        api_key = (p.get("apiKey") or "").strip()
        if not base_url or not api_key:
            print(f"[inject_openclaw_config] 跳过 provider '{pid}'：缺少 baseUrl 或 apiKey")
            continue
        model_ids = p.get("models") or []
        if isinstance(model_ids, str):
            model_ids = [m.strip() for m in model_ids.split(",") if m.strip()]
        models = []
        for mid in model_ids:
            if not mid:
                continue
            models.append({
                "id": mid,
                "name": mid,
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
        print(f"[inject_openclaw_config] ✓ provider '{pid}' 已注入（模型: {', '.join(model_ids)}）")

    primary = (models_cfg.get("primary") or "").strip()
    if primary:
        set_deep(cfg, "agents.defaults.model.primary", primary)
        print(f"[inject_openclaw_config] ✓ 默认模型设置为 {primary}")

    # ------ Embedding（memory search，OpenClaw agents.defaults.memorySearch）------
    # 官方文档 https://docs.openclaw.ai/concepts/memory
    # 支持两种模式：provider "openai"（远程）或 "local"（本地 GGUF / hf: URI）
    emb = rt.get("embedding") or {}
    msearch = cfg.setdefault("agents", {}).setdefault("defaults", {}).setdefault("memorySearch", {})

    use_local = (emb.get("provider") or "").strip().lower() == "local" or (emb.get("local") or {}).get("modelPath")
    if use_local:
        local_cfg = emb.get("local") or {}
        model_path = (local_cfg.get("modelPath") or "").strip()
        if not model_path:
            model_path = "hf:ggml-org/embeddinggemma-300m-qat-q8_0-GGUF/embeddinggemma-300m-qat-Q8_0.gguf"
        ensure_path(cfg, "agents.defaults.memorySearch.local")
        msearch["provider"] = "local"
        msearch["local"] = msearch.get("local") or {}
        msearch["local"]["modelPath"] = model_path
        if local_cfg.get("modelCacheDir"):
            msearch["local"]["modelCacheDir"] = local_cfg["modelCacheDir"]
        if emb.get("fallback") == "none":
            msearch["fallback"] = "none"
        print(f"[inject_openclaw_config] ✓ Embedding 已注入 memorySearch（provider: local, modelPath: {model_path}）")
    else:
        emb_key = (emb.get("apiKey") or "").strip()
        if emb_key:
            ensure_path(cfg, "agents.defaults.memorySearch.remote")
            msearch["provider"] = "openai"
            remote = msearch.setdefault("remote", {})
            remote["apiKey"] = emb_key
            remote["baseUrl"] = (emb.get("baseUrl") or "").strip() or "https://open.bigmodel.cn/api/paas/v4"
            emb_model = (emb.get("model") or "").strip()
            msearch["model"] = emb_model or "embedding-3"
            print(f"[inject_openclaw_config] ✓ Embedding 已注入 memorySearch（provider: openai, baseUrl: {remote['baseUrl']}, model: {msearch['model']}）")


def main() -> int:
    parser = argparse.ArgumentParser(description="从 openclaw-runtime.json 注入到 openclaw.json")
    parser.add_argument("--runtime", type=Path, required=True, metavar="FILE", help="openclaw-runtime.json 路径")
    parser.add_argument("config", type=Path, help="openclaw.json 路径（会被原地修改）")
    args = parser.parse_args()

    if not args.config.is_file():
        print(f"文件不存在: {args.config}", file=sys.stderr)
        return 1

    if not args.runtime.is_file():
        print(f"运行时配置不存在: {args.runtime}，跳过注入（仅保留模板）", file=sys.stderr)
        return 0

    with open(args.config, "r", encoding="utf-8") as f:
        cfg = json.load(f)

    with open(args.runtime, "r", encoding="utf-8") as f:
        rt = json.load(f)

    apply_runtime(cfg, rt)

    with open(args.config, "w", encoding="utf-8") as f:
        json.dump(cfg, f, ensure_ascii=False, indent=2)

    return 0


if __name__ == "__main__":
    sys.exit(main())
