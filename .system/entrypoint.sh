#!/usr/bin/env bash
# ============================================================================
# Sisyphus 容器入口脚本
#
# 1. 加载 nvm（使 node/npx/openclaw 在非交互 shell 中可用）
# 2. 激活 base Python venv
# 3. 如有 OpenClaw 配置，将其链接到 ~/.openclaw/openclaw.json
# 4. 执行传入的命令（默认 /bin/bash）
#
# 注：Playwright MCP Server 由 Alphonso 按需通过 stdio 启动。
#     OpenClaw Gateway 需手动启动：openclaw gateway
# ============================================================================
set -e

# 加载 nvm（让 npx / node / openclaw 在 exec 的命令中可用）
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# 激活 base venv
source /opt/venv/bin/activate

# 链接 OpenClaw 配置（如果 workspace 中有配置文件且 ~/.openclaw 目录存在）
OPENCLAW_HOME="$HOME/.openclaw"
WORKSPACE_CONFIG="/workspace/config/openclaw.json"
if [ -f "$WORKSPACE_CONFIG" ]; then
    mkdir -p "$OPENCLAW_HOME"
    # 只在配置文件不存在或是符号链接时才覆盖
    if [ ! -f "$OPENCLAW_HOME/openclaw.json" ] || [ -L "$OPENCLAW_HOME/openclaw.json" ]; then
        ln -sf "$WORKSPACE_CONFIG" "$OPENCLAW_HOME/openclaw.json"
    fi
fi

# 执行传入的命令（docker compose 的 command 或默认 /bin/bash）
exec "$@"
