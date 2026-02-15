#!/usr/bin/env bash
# ============================================================================
# Sisyphus 容器入口脚本
#
# 职责：
#   1. 加载 nvm + 激活 Python venv
#   2. 同步 brain/（镜像更新 = 代码更新）
#   3. 链接 OpenClaw 配置，用脚本注入环境变量（inject_openclaw_config.py）
#   4. 确保 inbox 等必备文件存在（避免 tools 读文件 ENOENT）
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

# ── 确保 inbox 等必备文件存在（避免 [tools] read failed: ENOENT）────────────
mkdir -p /workspace/inbox
for _f in backlog.md blocked.md ideas.md; do
    [ -f "/workspace/inbox/$_f" ] || printf '# %s\n\n*（占位，可编辑）\n' "${_f%.md}" > "/workspace/inbox/$_f"
done

# ── OpenClaw 配置：模板 + 运行时配置注入 ─────────────────────────────────────

OPENCLAW_HOME="$HOME/.openclaw"
WORKSPACE_CONFIG="/workspace/config/openclaw.json"
RUNTIME_CONFIG="/workspace/config/openclaw-runtime.json"
mkdir -p "$OPENCLAW_HOME"

# 从 workspace 取模板，复制为实体文件后按 openclaw-runtime.json 注入（不写回仓库）
if [ -f "$WORKSPACE_CONFIG" ]; then
    ln -sf "$WORKSPACE_CONFIG" "$OPENCLAW_HOME/openclaw.json"
fi
_cfg="$OPENCLAW_HOME/openclaw.json"
if [ -L "$_cfg" ]; then
    _src="$(readlink -f "$_cfg")"
    rm -f "$_cfg"
    cp -f "$_src" "$_cfg"
fi

# 读取 openclaw-runtime.json 注入 Gateway/飞书/模型/Embedding，再启动 gateway
if [ -f "$_cfg" ]; then
    python3 /usr/local/lib/sisyphus/inject_openclaw_config.py --runtime "$RUNTIME_CONFIG" "$_cfg"
fi

# ── OpenClaw 安全：状态目录与配置仅当前用户可访问 ─────────────────────────────
chmod 700 "$OPENCLAW_HOME"
[ -f "$OPENCLAW_HOME/openclaw.json" ] && chmod 600 "$OPENCLAW_HOME/openclaw.json"

# ── 执行命令 ───────────────────────────────────────────────────────────────

exec "$@"
