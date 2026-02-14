#!/usr/bin/env bash
# ============================================================================
# Sisyphus 容器入口脚本
#
# 职责：
#   1. 加载 nvm + 激活 Python venv
#   2. 同步 brain/（镜像更新 = 代码更新）
#   3. 链接 OpenClaw 配置
#   4. 解析 LLM_PROVIDER_* 环境变量，注入 openclaw.json
#   5. 执行传入的命令（默认 /bin/bash）
#
# /workspace 可为 bind mount 的宿主机目录；若为空则从 skeleton 初始化。
# ============================================================================
set -e

# ── SSH（若设置了 ROOT_PASSWORD 则启用 root 密码登录，端口 10220）────────────
if [ -n "${ROOT_PASSWORD:-}" ]; then
    echo "root:${ROOT_PASSWORD}" | chpasswd
    mkdir -p /run/sshd
    /usr/sbin/sshd
fi

# ── 环境加载 ───────────────────────────────────────────────────────────────

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

source /opt/venv/bin/activate

# ── 空 workspace 初始化（bind mount 空目录时）────────────────────────────────
if [ ! -f /workspace/SOUL.md ] && [ -d /opt/sisyphus-workspace-skeleton ]; then
    cp -a /opt/sisyphus-workspace-skeleton/. /workspace/
fi

# ── brain/ 同步 ────────────────────────────────────────────────────────────
# 每次启动从镜像层同步最新 brain/ 到数据卷。
# 镜像重建 = brain/ 代码更新，无需手动操作。
# 数据目录（worklog/ memory/ 等）不受影响。

BRAIN_SRC="/opt/sisyphus-brain"
BRAIN_DST="/workspace/brain"

if [ -d "$BRAIN_SRC" ]; then
    rsync -a --delete "$BRAIN_SRC/" "$BRAIN_DST/"
fi

# ── OpenClaw 配置与凭证 ─────────────────────────────────────────────────────

OPENCLAW_HOME="$HOME/.openclaw"
WORKSPACE_CONFIG="/workspace/config/openclaw.json"
mkdir -p "$OPENCLAW_HOME"

# 每次启动都从 workspace 同步最新源配置（后续 jq 会在副本上做运行时注入）
if [ -f "$WORKSPACE_CONFIG" ]; then
    ln -sf "$WORKSPACE_CONFIG" "$OPENCLAW_HOME/openclaw.json"
fi

# ── 写 OpenClaw .env（保留 Gateway Token 和飞书凭证）─────────────────────────
OPENCLAW_ENV="$OPENCLAW_HOME/.env"
: > "$OPENCLAW_ENV"
for _var in OPENCLAW_GATEWAY_TOKEN FEISHU_APP_ID FEISHU_APP_SECRET; do
    _val="${!_var:-}"
    [ -n "$_val" ] && printf '%s=%s\n' "$_var" "$_val" >> "$OPENCLAW_ENV"
done

# ── 解析 LLM_PROVIDER_{NAME}_* 环境变量 → 注入 openclaw.json ────────────────
#
# 约定：
#   LLM_PROVIDER_{NAME}_BASE_URL  — OpenAI-compatible 接口地址
#   LLM_PROVIDER_{NAME}_API_KEY   — 认证密钥
#   LLM_PROVIDER_{NAME}_MODELS    — 逗号分隔的模型列表（第一个为默认）
#   LLM_PRIMARY_MODEL             — 全局默认模型（格式 provider_name/model_id）
#
# provider name = NAME 转小写（如 LLM_PROVIDER_ARK_* → "ark"）
# 处理逻辑：先准备 runtime 配置副本，再用 jq 注入 providers 和 primary model。

_cfg="$OPENCLAW_HOME/openclaw.json"

# 确保 _cfg 是实体文件（不是 symlink），避免把运行时配置写回仓库
if [ -L "$_cfg" ]; then
    _src="$(readlink -f "$_cfg")"
    rm -f "$_cfg"
    cp -f "$_src" "$_cfg"
fi

# 注入 Gateway Token（如果有）
if [ -n "${OPENCLAW_GATEWAY_TOKEN:-}" ] && [ -f "$_cfg" ]; then
    jq --arg t "$OPENCLAW_GATEWAY_TOKEN" '
      .gateway.auth = (.gateway.auth // {}) |
      .gateway.auth.mode = "token" |
      .gateway.auth.token = $t
    ' "$_cfg" > "$_cfg.tmp" && mv "$_cfg.tmp" "$_cfg"
fi

# 容器内 CLI 固定连 127.0.0.1，避免 bind:lan 时走 LAN IP 导致 pairing required
# gateway.mode: remote + gateway.remote.url 仅影响 CLI 连接方式，Gateway 进程仍按 port/bind 启动
if [ -f "$_cfg" ]; then
    _tok="${OPENCLAW_GATEWAY_TOKEN:-}"
    jq --arg url "ws://127.0.0.1:18789" --arg t "$_tok" '
      .gateway.mode = "remote" |
      .gateway.remote = ((.gateway.remote // {}) | .url = $url | if $t != "" then .token = $t else . end)
    ' "$_cfg" > "$_cfg.tmp" && mv "$_cfg.tmp" "$_cfg"
fi

# 收集所有 LLM_PROVIDER_{NAME}_BASE_URL 变量，提取 provider names
_provider_names=()
while IFS='=' read -r _key _; do
    if [[ "$_key" =~ ^LLM_PROVIDER_([A-Za-z0-9]+)_BASE_URL$ ]]; then
        _name="${BASH_REMATCH[1]}"
        _name_lower="$(echo "$_name" | tr '[:upper:]' '[:lower:]')"
        _provider_names+=("$_name|$_name_lower")
    fi
done < <(env)

if [ ${#_provider_names[@]} -gt 0 ] && [ -f "$_cfg" ]; then
    echo "[entrypoint] 发现 ${#_provider_names[@]} 个 LLM provider，注入配置..."

    for _entry in "${_provider_names[@]}"; do
        _env_name="${_entry%%|*}"
        _provider_id="${_entry##*|}"

        _base_url_var="LLM_PROVIDER_${_env_name}_BASE_URL"
        _api_key_var="LLM_PROVIDER_${_env_name}_API_KEY"
        _models_var="LLM_PROVIDER_${_env_name}_MODELS"

        _base_url="${!_base_url_var:-}"
        _api_key="${!_api_key_var:-}"
        _models_csv="${!_models_var:-}"

        if [ -z "$_base_url" ] || [ -z "$_api_key" ]; then
            echo "[entrypoint] 跳过 provider '$_provider_id'：缺少 BASE_URL 或 API_KEY"
            continue
        fi

        # 解析逗号分隔的模型列表，strip 空格，生成 JSON 数组
        _models_json="[]"
        if [ -n "$_models_csv" ]; then
            _models_json=$(echo "$_models_csv" | python3 -c "
import sys, json
raw = sys.stdin.read().strip()
models = [m.strip() for m in raw.split(',') if m.strip()]
result = []
for m in models:
    result.append({
        'id': m,
        'name': m,
        'reasoning': False,
        'input': ['text'],
        'contextWindow': 128000,
        'maxTokens': 16384
    })
print(json.dumps(result))
")
        fi

        # 注入到 openclaw.json
        jq --arg pid "$_provider_id" \
           --arg url "$_base_url" \
           --arg key "$_api_key" \
           --argjson models "$_models_json" '
          .models.providers[$pid] = {
            "baseUrl": $url,
            "apiKey": $key,
            "api": "openai-completions",
            "models": $models
          }
        ' "$_cfg" > "$_cfg.tmp" && mv "$_cfg.tmp" "$_cfg"

        # 同时把 API Key 写入 .env 供 OpenClaw daemon 读取
        # OpenClaw 对某些内置 provider 会从 .env 读 key
        printf 'LLM_PROVIDER_%s_API_KEY=%s\n' "$_env_name" "$_api_key" >> "$OPENCLAW_ENV"

        echo "[entrypoint] ✓ provider '$_provider_id' 已注入（模型：$_models_csv）"
    done
fi

# 注入全局默认模型（LLM_PRIMARY_MODEL，格式 provider/model_id）
if [ -n "${LLM_PRIMARY_MODEL:-}" ] && [ -f "$_cfg" ]; then
    jq --arg m "$LLM_PRIMARY_MODEL" '
      .agents.defaults.model.primary = $m
    ' "$_cfg" > "$_cfg.tmp" && mv "$_cfg.tmp" "$_cfg"
    echo "[entrypoint] ✓ 默认模型设置为 $LLM_PRIMARY_MODEL"
fi

# 注入 Embedding 配置（用于 memory search 向量化）
# EMBEDDING_API_KEY 必填，EMBEDDING_BASE_URL 可选（有默认值）
if [ -n "${EMBEDDING_API_KEY:-}" ] && [ -f "$_cfg" ]; then
    _emb_url="${EMBEDDING_BASE_URL:-https://open.bigmodel.cn/api/paas/v4/}"
    jq --arg key "$EMBEDDING_API_KEY" \
       --arg url "$_emb_url" '
      .agents.defaults.memorySearch.remote = (.agents.defaults.memorySearch.remote // {}) |
      .agents.defaults.memorySearch.remote.apiKey = $key |
      .agents.defaults.memorySearch.remote.baseUrl = $url
    ' "$_cfg" > "$_cfg.tmp" && mv "$_cfg.tmp" "$_cfg"
    echo "[entrypoint] ✓ Embedding 已注入 memorySearch（baseUrl: $_emb_url）"
fi

# ── 执行命令 ───────────────────────────────────────────────────────────────

exec "$@"
