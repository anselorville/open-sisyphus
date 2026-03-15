#!/usr/bin/env bash
# ============================================================================
# Sisyphus 容器入口脚本
#
# 职责：
#   1. 加载 nvm + 激活 Python venv
#   2. 同步 brain/（镜像更新 = 代码更新）
#   3. 确保 inbox 等必备文件存在（避免 tools 读文件 ENOENT）
#   4. 执行传入的命令（默认 /bin/bash）
#
# OpenClaw 配置（openclaw.json）由外部管理：
#   /root/.openclaw 已通过 bind mount 映射到宿主机，容器启动后直接使用已有配置。
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
# Playwright / browser 工具会访问此缓存目录，不存在时会导致 exec 报错
mkdir -p "$HOME/.cache/ms-playwright"
for _f in backlog.md blocked.md ideas.md; do
    [ -f "/workspace/inbox/$_f" ] || printf '# %s\n\n*（占位，可编辑）\n' "${_f%.md}" > "/workspace/inbox/$_f"
done

# ── 执行命令 ───────────────────────────────────────────────────────────────

exec "$@"
