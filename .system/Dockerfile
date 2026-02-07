# ============================================================================
# AI 助手运行环境 — 多阶段构建
# Ubuntu 22.04 | Python 3.13 | Node 24 (nvm) | headless Chrome | GPU-ready
#
# 策略：
#   builder  — 系统依赖 + Python + Node + Chrome（重且稳定，很少改动）
#   runtime  — 业务依赖 + 入口脚本（轻且频繁变化，秒级重建）
#
# 构建上下文为 workspace 根目录（.），Dockerfile 位于 .system/Dockerfile
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
    build-essential ca-certificates curl file git gnupg jq less tzdata \
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

# --- 全局 npm 包（pnpm + @playwright/mcp + openclaw + feishu 插件） ---
RUN . "$NVM_DIR/nvm.sh" \
    && npm install -g pnpm @playwright/mcp openclaw \
    && openclaw plugins install @openclaw/feishu

# 验证
RUN . "$NVM_DIR/nvm.sh" && node -v && npm -v && python3.13 --version \
    && openclaw --version


# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  Stage 2: runtime — 业务层（改动后秒级重建）                             ║
# ╚══════════════════════════════════════════════════════════════════════════╝
FROM builder AS runtime

LABEL maintainer="sisyphus-dev"

# --- Python 业务依赖（改 requirements.txt 才触发） ---
COPY brain/agents/alphonso/requirements.txt /tmp/alphonso-requirements.txt
RUN "$VENV_DIR/bin/pip" install -r /tmp/alphonso-requirements.txt \
    && rm /tmp/alphonso-requirements.txt

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

# --- 入口脚本 ---
COPY .system/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# --- 工作目录 ---
WORKDIR /workspace

ENTRYPOINT ["entrypoint.sh"]
CMD ["/bin/bash"]
