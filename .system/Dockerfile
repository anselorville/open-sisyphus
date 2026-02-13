# ============================================================================
# Sisyphus 运行环境 — 多阶段构建
# Ubuntu 22.04 | Python 3.13 | Node 24 (nvm) | headless Chrome | GPU-ready
#
# 隐喻：这个容器是 AI 助手的"办公室"
#   构建镜像 = 装修办公室（安装工具、布置桌面、放好手册）
#   数据卷   = 办公室里的文件柜（工作日志、记忆、产出物）
#
# 构建策略：
#   builder  — 系统工具链（重且稳定，很少改动）
#   runtime  — 业务依赖 + /workspace 完整目录结构（改动后秒级重建）
#
# /workspace 在构建时就创建好完整的目录结构和定义文件。
# 运行时挂载空数据卷时，Docker 会自动用镜像层填充。
#
# 构建上下文为项目根目录（.），Dockerfile 位于 .system/Dockerfile
# ============================================================================


# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  Stage 1: builder — 基础设施（构建一次，长期缓存）                       ║
# ╚══════════════════════════════════════════════════════════════════════════╝
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV TZ=Asia/Shanghai

# --- 系统依赖（单层合并） ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential ca-certificates curl file git gnupg jq less rsync tzdata \
    libffi-dev libpq-dev libssl-dev lsb-release openssh-client \
    procps software-properties-common sudo tree unzip vim wget \
    xz-utils zip zlib1g-dev \
    && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/*

# --- Python 3.13 (deadsnakes) ---
RUN add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       python3.13 python3.13-dev python3.13-venv \
    && rm -rf /var/lib/apt/lists/*

# --- pip 源（清华镜像） + base venv ---
COPY .system/.docker/pip.conf /etc/pip.conf
ARG PIP_INDEX_URL
ARG PIP_EXTRA_INDEX_URL
RUN python3.13 -m ensurepip --upgrade \
    && python3.13 -m pip install --upgrade pip \
    && if [ -n "$PIP_INDEX_URL" ]; then \
         printf '[global]\nindex-url = %s\ntrusted-host = %s\n' \
           "$PIP_INDEX_URL" \
           "$(echo $PIP_INDEX_URL | sed -E 's|https?://([^/]+).*|\1|')" \
           > /etc/pip.conf; \
         [ -n "$PIP_EXTRA_INDEX_URL" ] && \
           printf 'extra-index-url = %s\n' "$PIP_EXTRA_INDEX_URL" >> /etc/pip.conf; \
       fi

ENV VENV_DIR=/opt/venv
RUN python3.13 -m venv "$VENV_DIR" \
    && "$VENV_DIR/bin/pip" install --upgrade pip setuptools wheel

# --- nvm + Node.js 24 ---
ENV NVM_DIR=/root/.nvm
ENV NVM_INSTALL_VERSION=v0.40.2
RUN curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_INSTALL_VERSION}/install.sh" | bash \
    && . "$NVM_DIR/nvm.sh" \
    && nvm install 24 \
    && nvm alias default 24 \
    && nvm use default

# --- headless Chrome + 中文字体 ---
RUN curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
      | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] \
       https://dl.google.com/linux/chrome/deb/ stable main" \
       > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       google-chrome-stable fonts-liberation fonts-noto-cjk \
    && rm -rf /var/lib/apt/lists/*

# --- 全局 npm 包（pnpm + playwright + @playwright/mcp + openclaw + feishu 插件） ---
# playwright       — OpenClaw 内置 browser 工具的核心依赖（navigate/act/snapshot/screenshot）
# @playwright/mcp  — Playwright MCP Server（.mcp.json 的备选浏览器控制方式）
# PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 — 跳过 Chromium 下载，使用上面已安装的系统 Chrome
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
RUN . "$NVM_DIR/nvm.sh" \
    && npm install -g pnpm playwright @playwright/mcp openclaw \
    && openclaw plugins install @openclaw/feishu

# 验证
RUN . "$NVM_DIR/nvm.sh" && node -v && npm -v && python3.13 --version \
    && openclaw --version


# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  Stage 2: runtime — 业务层 + /workspace 办公室布局                      ║
# ╚══════════════════════════════════════════════════════════════════════════╝
FROM builder AS runtime

ARG VERSION=latest
LABEL maintainer="sisyphus-dev"
LABEL version="${VERSION}"
ENV SISYPHUS_VERSION=${VERSION}

# --- Python 业务依赖（改 requirements.txt 才触发） ---
COPY brain/agents/alphonso/requirements.txt /tmp/alphonso-requirements.txt
RUN "$VENV_DIR/bin/pip" install -r /tmp/alphonso-requirements.txt \
    && rm /tmp/alphonso-requirements.txt

# --- OpenSSH Server（root 密码登录，端口 10220）---
RUN apt-get update && apt-get install -y --no-install-recommends openssh-server \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/sshd
COPY .system/sshd_sisyphus.conf /etc/ssh/sshd_config.d/99-sisyphus.conf
RUN ssh-keygen -A

# --- shell 配置 ---
RUN { \
      echo ''; \
      echo '# base venv'; \
      echo 'source /opt/venv/bin/activate'; \
      echo ''; \
      echo '# nvm'; \
      echo 'export NVM_DIR="$HOME/.nvm"'; \
      echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'; \
      echo ''; \
      echo '# headless chrome alias'; \
      echo 'alias chrome-headless="google-chrome-stable --headless --no-sandbox --disable-gpu --remote-debugging-port=9222"'; \
    } >> /root/.bashrc

# ── /workspace — Sisyphus 的办公室 ─────────────────────────────────────
# 构建时创建完整目录结构 + 放入定义文件。
# 运行时挂载空 named volume 时，Docker 自动用镜像层内容初始化。
# 挂载非空卷则保留已有数据（持久化语义）。

WORKDIR /workspace

# ── 定义文件（身份、规范、配置） ──
COPY SOUL.md           /workspace/SOUL.md
COPY AGENTS.md         /workspace/AGENTS.md
COPY IDENTITY.md       /workspace/IDENTITY.md
COPY TOOLS.md          /workspace/TOOLS.md
COPY BOOT.md           /workspace/BOOT.md
COPY HEARTBEAT.md      /workspace/HEARTBEAT.md
COPY USER.md           /workspace/USER.md
COPY MEMORY.md         /workspace/MEMORY.md
COPY .mcp.json         /workspace/.mcp.json

# ── brain/ — 大脑（能力代码） ──
# 复制到 /workspace（首次空卷初始化）和 /opt/sisyphus-brain（同步源）。
# 数据卷非空时 /workspace/brain 来自卷，entrypoint 每次启动从同步源覆盖。
COPY brain/            /workspace/brain/
COPY brain/            /opt/sisyphus-brain/

# ── config/ — 助手配置 ──
COPY config/           /workspace/config/

# ── tools/ — 工具箱 ──
COPY tools/            /workspace/tools/

# ── credentials/ — 凭证库（仅复制 README 和索引，不含实际凭证） ──
COPY credentials/README.md    /workspace/credentials/README.md
COPY credentials/_index.md    /workspace/credentials/_index.md

# ── 数据目录（空目录，运行时由 Sisyphus 填充） ──
RUN mkdir -p \
    /workspace/memory/notepad/learnings \
    /workspace/memory/notepad/references \
    /workspace/memory/notepad/patterns \
    /workspace/memory/index \
    /workspace/worklog \
    /workspace/inbox \
    /workspace/artifacts/reports \
    /workspace/artifacts/exports \
    /workspace/artifacts/snapshots \
    /workspace/projects \
    /workspace/docs \
    /workspace/.workspace/docs \
    /workspace/.workspace/scripts \
    /workspace/.workspace/drafts

# 供 bind mount 空目录时初始化（entrypoint 会从此复制）
RUN cp -a /workspace /opt/sisyphus-workspace-skeleton

# ── 入口脚本 ──
COPY .system/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["entrypoint.sh"]
CMD ["/bin/bash"]
