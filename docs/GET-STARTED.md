# Get Started

从零开始构建 Sisyphus 运行环境，并最终与他对话。

---

## 总览

整个过程分为五步：

| 步骤 | 内容 | 预计耗时 |
|------|------|----------|
| [1. 前置条件](#1-前置条件) | 安装 Docker、NVIDIA 驱动（可选） | 视机器情况 |
| [2. 克隆与配置](#2-克隆与配置) | 拉代码、填环境变量 | 2 分钟 |
| [3. 构建镜像](#3-构建镜像) | 首次构建基础镜像 + 业务层 | 10–30 分钟（首次） |
| [4. 启动并验证](#4-启动并验证) | 启动容器、确认环境就绪 | 2 分钟 |
| [5. 与 Sisyphus 对话](#5-与-sisyphus-对话) | 启动 Gateway、接入飞书 | 5 分钟 |

---

## 1. 前置条件

### 必需

| 软件 | 最低版本 | 说明 |
|------|----------|------|
| **Docker Engine** | 20.10+ | [安装指南](https://docs.docker.com/engine/install/) |
| **Docker Compose** | v2 (集成在 Docker Desktop 或 `docker compose` 插件) | — |

### 可选（GPU 支持）

| 软件 | 说明 |
|------|------|
| **NVIDIA 驱动** | 宿主机需安装 ≥ 535.x |
| **NVIDIA Container Toolkit** | 让 Docker 容器使用 GPU，[安装指南](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) |

> **没有 GPU？** 完全没问题。Sisyphus 的核心功能（对话、浏览器、代码执行等）不依赖 GPU。
> 只需在构建时去掉 GPU 相关配置即可（见 [附录 A](#附录-a-无-gpu-环境)）。

### 验证 Docker 可用

```bash
docker --version        # Docker version 20.10+
docker compose version  # Docker Compose version v2.x
```

验证 GPU（如适用）：

```bash
nvidia-smi              # 能看到显卡信息
docker run --rm --gpus all nvidia/cuda:12.6.0-base-ubuntu22.04 nvidia-smi
```

---

## 2. 克隆与配置

### 2.1 克隆项目

```bash
git clone <repo-url> open-sisyphus
cd open-sisyphus
```

### 2.2 创建环境变量文件

```bash
cp .system/.env.example .system/.env
```

### 2.3 编辑 `.system/.env`

用你喜欢的编辑器打开 `.system/.env`，按需填写：

```bash
# ── 必填 ──────────────────────────────────────────────
# Anthropic API Key（Sisyphus 的大脑）
ANTHROPIC_API_KEY=sk-ant-xxxxx

# ── 可选：数据库（默认值即可用） ──────────────────────
POSTGRES_USER=dev
POSTGRES_PASSWORD=dev
POSTGRES_DB=app

# ── 可选：飞书（如需飞书渠道） ────────────────────────
# 在飞书开放平台创建应用后获取，详见 docs/FEISHU-CHANNEL-SETUP.md
FEISHU_APP_ID=cli_xxx
FEISHU_APP_SECRET=your_secret

# ── 可选：Gateway Token ───────────────────────────────
OPENCLAW_GATEWAY_TOKEN=
```

**最低启动要求**：只需要 `ANTHROPIC_API_KEY`。其余均可后续配置。

---

## 3. 构建镜像

### 3.1 理解构建策略

Sisyphus 使用**多阶段构建**，将重量级基础设施与轻量级业务层分离：

```
┌─────────────────────────────────────────────────────┐
│  Stage 1: builder                                   │
│  Ubuntu 22.04 + Python 3.13 + Node 24 + Chrome      │
│  + OpenClaw + Playwright MCP                         │
│  （重且稳定，很少改动，构建一次长期缓存）                 │
├─────────────────────────────────────────────────────┤
│  Stage 2: runtime                                   │
│  Python 业务依赖 + shell 配置 + entrypoint            │
│  （轻且频繁变化，秒级重建）                              │
└─────────────────────────────────────────────────────┘
```

### 3.2 首次完整构建

```bash
cd .system
docker compose up -d --build
```

首次构建需要下载和安装大量依赖，**耗时约 10–30 分钟**（取决于网络）。
构建完成后会自动启动两个服务：

| 服务 | 容器名 | 说明 |
|------|--------|------|
| `dev` | `sisyphus-dev` | Sisyphus 主环境 |
| `postgres` | `sisyphus-postgres` | PostgreSQL 15 数据库 |

### 3.3 （推荐）单独缓存 builder 阶段

如果你经常修改业务层代码，建议先单独构建 builder，这样后续重建只需几秒：

```bash
# 在项目根目录执行
docker build --target builder -t sisyphus-builder -f .system/Dockerfile .

# 之后正常启动（会复用 builder 缓存）
cd .system
docker compose up -d --build
```

### 3.4 构建速度优化

如果默认 pip 源（清华镜像）速度不理想，可以在构建时指定其他源：

```bash
docker compose build --build-arg PIP_INDEX_URL=https://pypi.org/simple/ dev
```

---

## 4. 启动并验证

### 4.1 确认服务状态

```bash
cd .system
docker compose ps
```

预期输出：

```
NAME                STATUS              PORTS
sisyphus-dev        running             
sisyphus-postgres   running (healthy)   0.0.0.0:5432->5432/tcp
```

> `dev` 容器使用 `network_mode: host`，因此不单独映射端口。

### 4.2 进入容器

```bash
docker compose exec dev bash
```

你现在处于 Sisyphus 的"家"：`/workspace`。
Python venv 和 nvm 已自动激活。

### 4.3 验证环境

在容器内逐项检查：

```bash
# Python
python --version
# → Python 3.13.x

# Node.js
node -v
# → v24.x.x

# npm / pnpm
npm -v && pnpm -v

# OpenClaw（对话网关）
openclaw --version

# Chrome（浏览器）
google-chrome-stable --version

# PostgreSQL 连接
psql -h localhost -U dev -d app -c "SELECT 1;"
# → 需输入密码 dev，返回 1 表示成功

# GPU（如适用）
nvidia-smi
```

全部通过，说明环境已就绪。

---

## 5. 与 Sisyphus 对话

Sisyphus 通过 [OpenClaw](https://github.com/openclaw/openclaw) Gateway 与外界沟通。
目前支持的渠道是**飞书**，未来可扩展到 Telegram、Discord、Slack 等。

### 方式 A：通过飞书对话（推荐）

#### A.1 创建飞书应用

前往 [飞书开放平台](https://open.feishu.cn/app)，创建一个企业自建应用。
详细步骤见 [FEISHU-CHANNEL-SETUP.md](FEISHU-CHANNEL-SETUP.md)，核心流程：

1. 创建应用，获取 **App ID** 和 **App Secret**
2. 在**权限管理**中添加消息读写权限
3. 在**应用能力**中开启机器人
4. 在**事件订阅**中启用长连接 + 添加 `im.message.receive_v1` 事件
5. 发布应用并通过审批

#### A.2 填入凭证

确保 `.system/.env` 中已填写：

```bash
FEISHU_APP_ID=cli_xxx
FEISHU_APP_SECRET=your_secret
ANTHROPIC_API_KEY=sk-ant-xxxxx
```

如果容器已在运行，需要重启以加载新的环境变量：

```bash
cd .system
docker compose down dev
docker compose up -d dev
docker compose exec dev bash
```

#### A.3 启动 Gateway

在容器内执行：

```bash
openclaw gateway
```

首次运行会检测到飞书配置并自动建立 WebSocket 连接。
看到类似以下日志即表示成功：

```
[Gateway] Listening on 0.0.0.0:18789
[Feishu]  Connected via WebSocket
```

> **生产建议**：后台启动 Gateway：`openclaw gateway &`

#### A.4 发起对话

1. 在飞书中搜索你创建的机器人名称（如 "Sisyphus"）
2. 发送第一条消息
3. 首次会触发**配对审批**（`pairing` 策略），在容器内审批：

```bash
# 查看待审批请求
openclaw pairing list feishu

# 审批通过
openclaw pairing approve feishu <CODE>
```

审批通过后，即可正常对话。你现在在和 Sisyphus 说话了。

#### A.5 群聊

将机器人添加到飞书群组后：
- 群聊中需要 **@mention** 机器人才会触发响应
- 可在 `config/openclaw.json` 中修改群聊策略

### 方式 B：容器内直接交互

如果暂时不需要飞书，也可以直接在容器内使用 Sisyphus 的工具：

```bash
# 使用 Alphonso 查资料
python -m brain.agents.alphonso "最近有什么 AI 领域的重要论文"

# 使用 OpenClaw CLI 对话（如已配置 API Key）
openclaw chat
```

---

## 日常操作速查

### 启动 / 停止

```bash
cd .system

# 启动全部服务
docker compose up -d

# 停止全部服务
docker compose down

# 仅重启 dev 容器
docker compose restart dev

# 进入容器
docker compose exec dev bash
```

### 查看日志

```bash
# Docker 容器日志
docker compose logs -f dev

# OpenClaw Gateway 日志（容器内）
openclaw logs --follow
```

### 重建镜像

```bash
# 业务层变更后重建（秒级）
docker compose up -d --build

# 如果修改了 Dockerfile 的 builder 阶段，需要完整重建
docker compose build --no-cache dev
```

---

## 附录 A：无 GPU 环境

如果宿主机没有 NVIDIA GPU，需要修改 `.system/docker-compose.yml`，注释掉 GPU 相关配置：

```yaml
services:
  dev:
    # ... 其他配置不变 ...

    # 注释掉以下环境变量
    # environment:
    #   - NVIDIA_VISIBLE_DEVICES=all
    #   - NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics

    # 注释掉 deploy 块
    # deploy:
    #   resources:
    #     reservations:
    #       devices:
    #         - driver: nvidia
    #           count: all
    #           capabilities: [gpu]
```

或者更简洁的做法——创建一个 override 文件 `.system/docker-compose.override.yml`：

```yaml
services:
  dev:
    deploy: {}
```

这会覆盖掉 GPU 配置，无需修改原始文件。

---

## 附录 B：中国大陆网络优化

### Docker 镜像加速

在 `/etc/docker/daemon.json`（宿主机）中添加镜像加速器：

```json
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io"
  ]
}
```

然后重启 Docker：`sudo systemctl restart docker`

### pip 源

项目已默认配置清华镜像（`.system/.docker/pip.conf`），无需额外操作。
如需修改，构建时传入参数：

```bash
docker compose build \
  --build-arg PIP_INDEX_URL=https://mirrors.aliyun.com/pypi/simple/ \
  dev
```

### npm 源

如 npm 下载慢，可在构建前设置：

```bash
# 在 Dockerfile 中或构建时
npm config set registry https://registry.npmmirror.com
```

---

## 附录 C：常见问题

### Q: 构建时报 `nvidia` 相关错误

**原因**：宿主机没有安装 NVIDIA Container Toolkit。
**解决**：参照 [附录 A](#附录-a-无-gpu-环境) 去掉 GPU 配置，或安装 NVIDIA Container Toolkit。

### Q: Postgres 启动失败 / 端口冲突

**原因**：宿主机 5432 端口已被占用。
**解决**：

```bash
# 查看谁占了 5432
lsof -i :5432      # Linux/macOS
netstat -ano | findstr :5432   # Windows

# 方案 1：停掉本地 PostgreSQL
# 方案 2：修改 docker-compose.yml 中的映射端口
ports:
  - "15432:5432"   # 改为 15432
```

### Q: `openclaw gateway` 报连接失败

**检查清单**：
1. 容器网络是否正常：`curl -s https://api.anthropic.com` 
2. `.system/.env` 中 API Key 是否正确
3. 飞书应用是否已发布并审批通过
4. 事件订阅是否配置了长连接模式

### Q: 飞书消息发出去了但没有回复

**检查清单**：
1. Gateway 是否在运行：`openclaw gateway status`
2. 是否需要审批配对：`openclaw pairing list feishu`
3. 查看 Gateway 日志：`openclaw logs --follow`

### Q: 如何更新 Sisyphus

```bash
cd open-sisyphus
git pull
cd .system
docker compose up -d --build
```

---

## 附录 D：架构概览

```
┌──────────────────────────────────────────────────────────────┐
│  宿主机                                                       │
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │  sisyphus-dev 容器 (network_mode: host)                 │ │
│  │                                                         │ │
│  │  /workspace/          ← 与宿主机双向同步                  │ │
│  │  ├── brain/           ← Sisyphus 能力中枢                │ │
│  │  ├── config/          ← OpenClaw 配置                    │ │
│  │  └── ...                                                │ │
│  │                                                         │ │
│  │  OpenClaw Gateway ──── 飞书 WebSocket ──── 飞书用户      │ │
│  │       │                                                 │ │
│  │       └── Anthropic API ──── Claude (LLM)               │ │
│  │                                                         │ │
│  │  Alphonso ── Playwright MCP ── headless Chrome           │ │
│  │                                                         │ │
│  │  Python 3.13 (venv) / Node.js 24 (nvm) / GPU (CUDA)    │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌─────────────────┐                                         │
│  │ sisyphus-postgres│  ← PostgreSQL 15                       │
│  │ (port 5432)      │                                        │
│  └─────────────────┘                                         │
└──────────────────────────────────────────────────────────────┘
```

---

## 下一步

- [FEISHU-CHANNEL-SETUP.md](FEISHU-CHANNEL-SETUP.md) — 飞书渠道详细配置
- [INSTALL-TORCH-CUDA.md](INSTALL-TORCH-CUDA.md) — GPU + PyTorch 安装
- [SOUL.md](../SOUL.md) — 了解 Sisyphus 的身份和原则
- [AGENTS.md](../AGENTS.md) — 行为规范与工作准则
