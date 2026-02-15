#!/usr/bin/env bash
# =============================================================================
# 从 openclaw-runtime.json 重新注入 openclaw.json，不重启容器。
# Gateway 会热加载配置，下一轮对话即用新模型/配置。
#
# 用法：
#   容器内：reapply_openclaw_config
#   宿主机：docker compose exec dev reapply_openclaw_config
# =============================================================================
set -e

OPENCLAW_HOME="${OPENCLAW_HOME:-$HOME/.openclaw}"
CFG="${OPENCLAW_HOME}/openclaw.json"
RUNTIME="${OPENCLAW_RUNTIME_CONFIG:-/workspace/config/openclaw-runtime.json}"
INJECT="/usr/local/lib/sisyphus/inject_openclaw_config.py"

if [ ! -f "$CFG" ]; then
    echo "错误: 未找到 $CFG" >&2
    exit 1
fi
if [ ! -f "$RUNTIME" ]; then
    echo "错误: 未找到运行时配置 $RUNTIME（请从 config/openclaw-runtime.example.json 复制并填写）" >&2
    exit 1
fi
if [ ! -x "$INJECT" ]; then
    echo "错误: 未找到可执行脚本 $INJECT" >&2
    exit 1
fi

echo "[reapply] 从 $RUNTIME 重新注入 openclaw.json ..."
exec python3 "$INJECT" --runtime "$RUNTIME" "$CFG"
