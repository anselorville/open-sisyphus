#!/usr/bin/env bash
# ============================================================================
# Sisyphus 容器入口脚本
#
# 职责：
#   1. 加载 nvm + 激活 Python venv
#   2. 同步 brain/（镜像更新 = 代码更新）
#   3. 链接 OpenClaw 配置
#   4. 执行传入的命令（默认 /bin/bash）
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

if [ -f "$WORKSPACE_CONFIG" ]; then
    if [ ! -f "$OPENCLAW_HOME/openclaw.json" ] || [ -L "$OPENCLAW_HOME/openclaw.json" ]; then
        ln -sf "$WORKSPACE_CONFIG" "$OPENCLAW_HOME/openclaw.json"
    fi
fi

# 将 compose 传入的 API 相关环境变量写入 ~/.openclaw/.env。
# OpenClaw 用 provider 管理模型与认证（见 https://docs.openclaw.ai/providers）；部分代码路径
# 会从该 .env 加载（如 daemon 启动时）。若仍报 "No API key found"，需在容器内用 provider 流程
# 登记 key，例如：openclaw onboard --anthropic-api-key "$ANTHROPIC_API_KEY" 或 openclaw models auth ...
OPENCLAW_ENV="$OPENCLAW_HOME/.env"
: > "$OPENCLAW_ENV"
for _var in ANTHROPIC_API_KEY ANTHROPIC_BASE_URL ANTHROPIC_MODEL OPENAI_API_KEY OPENAI_BASE_URL OPENAI_MODEL; do
    _val="${!_var:-}"
    [ -n "$_val" ] && printf '%s=%s\n' "$_var" "$_val" >> "$OPENCLAW_ENV"
done

# ── 执行命令 ───────────────────────────────────────────────────────────────

exec "$@"
