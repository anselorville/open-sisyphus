# Get Started

从零开始构建 Sisyphus 运行环境，并最终与他对话。

---

## 核心概念

这个容器是 AI 助手的**办公室**。

- **构建镜像** = 装修办公室（安装工具链、创建目录结构、放好身份手册和能力代码）
- **数据卷** = 办公室里的文件柜（工作日志、记忆、产出物持久化保存）
- **Channels** = 办公室的门（飞书等渠道的人来"敲门"下达任务）
- **更新 Sisyphus** = `git pull` + 重新装修（重建镜像，下次启动自动同步代码）

```
项目仓库（源码）                     容器（办公室）
┌───────────────┐                 ┌─────────────────────┐
│ SOUL.md       │                 │ /workspace/          │
│ brain/        │  docker build   │  ├── brain/  (代码)   │
│ config/       │ ─────────────→  │  ├── memory/ (记忆)   │
│ .system/      │  COPY 到镜像     │  ├── worklog/(日志)   │
│  Dockerfile   │  /workspace     │  ├── inbox/  (待办)   │
│  compose.yml  │                 │  ├── artifacts/(产出) │
└───────────────┘                 │  └── ...             │
                                  └─────────────────────┘
                                    ↑ 数据卷持久化
                                    容器重建不丢失
```

项目仓库和容器运行时完全解耦——你 clone 的目录不会挂载进容器。

---

## 总览

| 步骤 | 内容 | 预计耗时 |
|------|------|----------|
| [1. 前置条件](#1-前置条件) | 安装 Docker、NVIDIA 驱动（可选） | 视机器情况 |
| [2. 克隆与配置](#2-克隆与配置) | 拉代码、填环境变量 | 2 分钟 |
| [3. 构建镜像](#3-构建镜像) | 装修办公室 | 10–30 分钟（首次） |
| [4. 启动并验证](#4-启动并验证) | 开门、检查设施 | 2 分钟 |
| [5. 与 Sisyphus 对话](#5-与-sisyphus-对话) | 启动 Gateway、接入飞书 | 5 分钟 |

---

## 1. 前置条件

### 必需

| 软件 | 最低版本 | 说明 |
|------|----------|------|
| **Docker Engine** | 20.10+ | [安装指南](https://docs.docker.com/engine/install/) |
| **Docker Compose** | v2 | 集成在 Docker Desktop 或 `docker compose` 插件 |

### 可选（GPU）

| 软件 | 说明 |
|------|------|
| **NVIDIA 驱动** | 宿主机 ≥ 535.x |
| **NVIDIA Container Toolkit** | [安装指南](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) |

> **没有 GPU？** 没问题，核心功能不依赖 GPU。见 [附录 A](#附录-a-无-gpu-环境)。

### 验证

```bash
docker --version          # 20.10+
docker compose version    # v2.x
nvidia-smi                # GPU（如适用）
```

---

## 2. 克隆与配置

### 2.1 克隆

```bash
git clone <repo-url> open-sisyphus
cd open-sisyphus
```

### 2.2 创建环境变量

```bash
cp .system/.env.example .system/.env
```

### 2.3 编辑 `.system/.env`

```bash
# ── 必填 ──────────────────────────────────────
ANTHROPIC_API_KEY=sk-ant-xxxxx

# ── 可选：数据库（默认即可用） ─────────────────
POSTGRES_USER=dev
POSTGRES_PASSWORD=dev
POSTGRES_DB=app

# ── 可选：飞书（详见 docs/FEISHU-CHANNEL-SETUP.md）
FEISHU_APP_ID=cli_xxx
FEISHU_APP_SECRET=your_secret

# ── 可选：Gateway Token ───────────────────────
OPENCLAW_GATEWAY_TOKEN=
```

**最低启动要求**：只需填 `ANTHROPIC_API_KEY` 或 `OPENAI_API_KEY` 其一。

**运行时如何选模型与 BASE URL**：
- **Anthropic**：`.env` 中可设 `ANTHROPIC_BASE_URL`（自定义接口）、`ANTHROPIC_MODEL`（如 `claude-sonnet-4-20250514`）。
- **OpenAI / 兼容**：可设 `OPENAI_BASE_URL`、`OPENAI_MODEL`（如 `gpt-4o`）；或改 `config/openclaw.json` 里 `models.providers.openai.baseUrl` 与 `agents.defaults.model`。
- **对话中**：在飞书里发 `/model` 可查看或切换当前模型。

---

## 3. 构建镜像

### 3.1 构建做了什么

两阶段构建：

| 阶段 | 内容 | 说明 |
|------|------|------|
| **builder** | Ubuntu 22.04 + Python 3.13 + Node 24 + Chrome + OpenClaw | 重且稳定，长期缓存 |
| **runtime** | 业务依赖 + `/workspace` 完整目录结构 + 定义文件 | 改动后秒级重建 |

runtime 阶段做的事：
1. 安装 Python 业务依赖（Alphonso 等）
2. 把项目中的定义文件（SOUL.md、AGENTS.md、brain/、config/ 等）COPY 到 `/workspace/`
3. 创建空数据目录（worklog/、memory/、artifacts/ 等）
4. 把 brain/ 额外复制一份到 `/opt/sisyphus-brain/` 作为代码同步源

### 3.2 开始构建

```bash
cd .system
docker compose up -d --build
```

首次约 **10–30 分钟**，取决于网络。完成后启动两个服务：

| 服务 | 容器名 | 说明 |
|------|--------|------|
| `dev` | `sisyphus-dev` | Sisyphus 办公室 |
| `postgres` | `sisyphus-postgres` | PostgreSQL 15 |

### 3.3 （推荐）缓存 builder

```bash
# 在项目根目录
docker build --target builder -t sisyphus-builder -f .system/Dockerfile .

# 之后日常重建秒级完成
cd .system
docker compose up -d --build
```

---

## 4. 启动并验证

### 4.1 确认服务

```bash
cd .system
docker compose ps
```

```
NAME                STATUS              PORTS
sisyphus-dev        running             
sisyphus-postgres   running (healthy)   0.0.0.0:5432->5432/tcp
```

### 4.2 进入办公室

```bash
docker compose exec dev bash
```

你现在在 `/workspace/`——Sisyphus 的办公室。

### 4.3 看看里面有什么

```bash
ls /workspace/
# SOUL.md  AGENTS.md  IDENTITY.md  TOOLS.md  BOOT.md  HEARTBEAT.md  USER.md
# brain/  config/  memory/  worklog/  inbox/  artifacts/  projects/
# credentials/  tools/  docs/  .workspace/
```

所有目录和定义文件已在构建时就位。

### 4.4 验证工具链

```bash
python --version                  # Python 3.13.x
node -v                           # v24.x.x
openclaw --version                # OpenClaw
google-chrome-stable --version    # Chrome
psql -h localhost -U dev -d app -c "SELECT 1;"  # Postgres
nvidia-smi                        # GPU（如适用）
```

---

## 5. 与 Sisyphus 对话

### 方式 A：飞书（推荐）

#### A.1 创建飞书应用

详见 [FEISHU-CHANNEL-SETUP.md](FEISHU-CHANNEL-SETUP.md)，核心流程：

1. [飞书开放平台](https://open.feishu.cn/app) 创建企业自建应用
2. 获取 **App ID** + **App Secret**
3. 添加消息读写权限
4. 开启机器人能力
5. 事件订阅：长连接 + `im.message.receive_v1`
6. 发布并审批

#### A.2 配置凭证

确保 `.system/.env` 已填写飞书凭证，然后重启容器：

```bash
cd .system
docker compose down dev && docker compose up -d dev
docker compose exec dev bash
```

#### A.3 启动 Gateway

```bash
openclaw gateway
```

看到以下日志即成功：

```
[Gateway] Listening on 0.0.0.0:18789
[Feishu]  Connected via WebSocket
```

#### A.4 开始对话

1. 在飞书搜索机器人名称，发第一条消息
2. 首次触发配对审批：

```bash
openclaw pairing list feishu
openclaw pairing approve feishu <CODE>
```

3. 审批通过，可以对话了

### 方式 B：容器内直接使用

```bash
# Alphonso 查资料
python -m brain.agents.alphonso "最近有什么 AI 领域的重要论文"

# OpenClaw CLI
openclaw chat
```

---

## 日常操作

```bash
cd .system

docker compose up -d             # 启动
docker compose down               # 停止
docker compose restart dev        # 重启
docker compose exec dev bash      # 进入办公室

docker compose logs -f dev        # 容器日志
```

**SSH 远程登录**：在 `.system/.env` 中设置 `ROOT_PASSWORD` 后重启容器，即可从本机或局域网用 `ssh -p 10220 root@<主机 IP>` 登录（端口 10220，用户 root，密码为所设值）。使用 `network_mode: host` 时，端口直接占用宿主机 10220。

### 更新 Sisyphus

```bash
cd open-sisyphus
git pull
cd .system
docker compose up -d --build     # 重建镜像
```

重建后，下次启动 entrypoint 自动同步 `brain/` 最新代码到数据卷。
工作数据（worklog、memory、artifacts 等）不受影响。

### 数据备份

```bash
# docker cp
docker cp sisyphus-dev:/workspace ./workspace-backup

# 宿主机目录备份（workspace_data 在 .system/ 下）
cd .system && tar czf ../workspace-backup.tar.gz workspace_data
```

---

## 附录 A：无 GPU 环境

创建 `.system/docker-compose.override.yml`：

```yaml
services:
  dev:
    deploy: {}
    environment:
      - NVIDIA_VISIBLE_DEVICES=
      - NVIDIA_DRIVER_CAPABILITIES=
```

---

## 附录 B：中国大陆网络优化

**Docker 镜像加速**（宿主机 `/etc/docker/daemon.json`）：

```json
{ "registry-mirrors": ["https://docker.m.daocloud.io"] }
```

**pip 源**：已默认清华镜像。可构建时覆盖：

```bash
docker compose build --build-arg PIP_INDEX_URL=https://mirrors.aliyun.com/pypi/simple/ dev
```

---

## 附录 C：常见问题

**构建报 nvidia 错误** → 没有 NVIDIA Container Toolkit，见 [附录 A](#附录-a-无-gpu-环境)

**Postgres 端口冲突** → 宿主机 5432 已占用，改 compose 映射为 `"15432:5432"`

**`openclaw gateway` 连接失败** →
1. `curl -s https://api.anthropic.com`（网络）
2. 检查 `.env` 中 API Key
3. 飞书应用是否已发布审批
4. 事件订阅是否长连接模式

**飞书不回复** →
1. `openclaw gateway status`
2. `openclaw pairing list feishu`
3. `openclaw logs --follow`

**想挂载宿主机目录（开发调试）** → 创建 override：

```yaml
# .system/docker-compose.override.yml
services:
  dev:
    volumes:
      - /your/host/path:/workspace
```

> 这会绕过数据卷。仅建议开发调试，生产环境用数据卷。

---

## 附录 D：架构概览

```
┌──────────────────────────────────────────────────────────────┐
│  宿主机                                                       │
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │  sisyphus-dev (network_mode: host)                      │ │
│  │                                                         │ │
│  │  /workspace/      ← 办公室（数据卷，持久化）              │ │
│  │  /opt/sisyphus-brain/  ← brain/ 同步源（镜像层）          │ │
│  │                                                         │ │
│  │  OpenClaw Gateway ──── WebSocket ──── 飞书用户           │ │
│  │       │                                                 │ │
│  │       └── Anthropic API ──── Claude (LLM)               │ │
│  │                                                         │ │
│  │  Alphonso ── Playwright MCP ── headless Chrome           │ │
│  │                                                         │ │
│  │  Python 3.13 / Node.js 24 / GPU (CUDA)                  │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌──────────────────┐                                        │
│  │ sisyphus-postgres │  PostgreSQL 15 (port 5432)            │
│  └──────────────────┘                                        │
└──────────────────────────────────────────────────────────────┘
```

---

## 下一步

- [FEISHU-CHANNEL-SETUP.md](FEISHU-CHANNEL-SETUP.md) — 飞书渠道详细配置
- [INSTALL-TORCH-CUDA.md](INSTALL-TORCH-CUDA.md) — GPU + PyTorch 安装
- [SOUL.md](../SOUL.md) — Sisyphus 的身份和原则
- [AGENTS.md](../AGENTS.md) — 行为规范
