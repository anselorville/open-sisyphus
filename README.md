# Open Sisyphus

一个运行在 Docker 容器中的自主工作助手的完整运行环境。

容器是 Sisyphus 的"家"——他在这里思考、学习、工作、成长，通过飞书等渠道与人对话，通过对话完成工作。

## 设计哲学

- **容器即家园**：Sisyphus 拥有容器内的 root 权限，整个容器是他的私有空间
- **自律而非限制**：没有人为的权限围栏，取而代之的是对网络、系统完整性和数据的珍惜意识
- **随时能述职**：目录结构围绕"工作记录 → 知识积累 → 任务管理"设计，任何时候都能清晰汇报
- **能力可扩展**：通过助手团队（如 Alphonso）、MCP 工具、OpenClaw Channel 灵活扩展能力边界

## 技术栈

| 组件 | 版本 / 说明 |
|------|------------|
| 基础镜像 | Ubuntu 22.04 |
| Python | 3.13（deadsnakes PPA），base venv 位于 `/opt/venv` |
| Node.js | 24（nvm 管理，v0.40.2） |
| 浏览器 | headless Google Chrome（无图形界面 + 中文字体） |
| 数据库 | PostgreSQL 15 |
| GPU | NVIDIA GPU 直通（CUDA 12.6），支持魔改 GTX 2080 Ti（22GB） |
| 网络 | `network_mode: host`，容器与主机共享网络栈 |
| 通信网关 | [OpenClaw](https://github.com/openclaw/openclaw) + 飞书插件 |
| pip 源 | 清华镜像（默认） |
| 时区 | Asia/Shanghai (UTC+8) |

## 目录结构

```
/workspace/
├── SOUL.md                     # Sisyphus 的身份定义
├── AGENTS.md                   # 行为规范与工作准则
├── .mcp.json                   # MCP Server 配置（Playwright 等）
│
├── brain/                      # 能力中枢
│   ├── agents/                 #   助手团队
│   │   └── alphonso/           #     Web 信息检索助手
│   ├── channels/               #   对话渠道说明
│   ├── skills/                 #   技能模块
│   └── prompts/                #   提示词模板
│
├── memory/                     # 记忆系统（跨会话知识积累）
│   ├── notepad/
│   │   ├── learnings/          #     经验教训
│   │   ├── references/         #     参考资料
│   │   └── patterns/           #     最佳实践
│   └── index/                  #   记忆索引
│
├── worklog/                    # 工作日志（述职核心）
│   ├── YYYY-MM-DD/             #   按天分目录
│   │   ├── session-*.md        #     单次对话纪要
│   │   └── daily-summary.md    #     当日汇总
│   └── weekly/                 #   周报
│
├── inbox/                      # 任务管理
│   ├── backlog.md              #   待办
│   ├── blocked.md              #   阻塞项
│   └── ideas.md                #   想法暂存
│
├── artifacts/                  # 工作产出
│   ├── reports/                #   报告
│   ├── exports/                #   导出文件
│   └── snapshots/              #   截图 / 快照
│
├── projects/                   # 项目工作区（代码类工作在这里）
├── config/                     # 助手配置（OpenClaw、偏好等）
├── tools/                      # 工具箱（脚本、模板）
├── docs/                       # 正式文档
│
├── .system/                    # 容器基础设施
│   ├── Dockerfile              #   多阶段构建（builder → runtime）
│   ├── docker-compose.yml      #   编排（dev + postgres）
│   ├── entrypoint.sh           #   容器入口脚本
│   ├── .docker/pip.conf        #   pip 源配置
│   └── .env.example            #   环境变量模板
│
└── .workspace/                 # 内部工作区（临时文件、草稿）
```

## 快速开始

### 前置条件

- Docker & Docker Compose
- NVIDIA Container Toolkit（如需 GPU）
- 本地已有镜像：`ubuntu:22.04`、`postgres:15`

### 1. 克隆项目

```bash
git clone <repo-url> open-sisyphus
cd open-sisyphus
```

### 2. 配置环境变量

```bash
cp .system/.env.example .system/.env
# 编辑 .system/.env，填入必要的密钥：
#   ANTHROPIC_API_KEY    — Alphonso 助手的 LLM API 密钥
#   FEISHU_APP_ID        — 飞书应用 ID（可选）
#   FEISHU_APP_SECRET    — 飞书应用密钥（可选）
```

### 3. 构建并启动

```bash
cd .system
docker compose up -d --build
```

### 4. 进入容器

```bash
docker compose exec dev bash
```

进入后即处于 base venv 中，可直接使用 `python`、`node`、`npm`、`pnpm` 等命令。

### 5. 验证环境

```bash
python --version          # Python 3.13.x
node -v                   # v24.x.x
nvm --version             # 0.40.2
nvidia-smi                # GPU 信息（如已配置）
google-chrome-stable --version  # Chrome 版本
openclaw --version        # OpenClaw 版本
```

## 核心组件

### Alphonso — Web 信息检索助手

Alphonso 是 Sisyphus 的助手，专门负责通过浏览器获取外部信息。

**架构**：

```
调用方（Sisyphus / 用户）
    │
    │  python -m brain.agents.alphonso "查询内容"
    ▼
┌─────────────────────────────┐
│      Alphonso Agent         │
│  （LLM 推理 → 决策 → 精炼） │
└──────────┬──────────────────┘
           │  MCP 协议 (stdio)
           ▼
┌─────────────────────────────┐
│   Playwright MCP Server     │
│  （浏览器操作工具提供者）     │
└──────────┬──────────────────┘
           ▼
     headless Chrome
```

Alphonso 本质上是一个有 LLM 推理能力的 Agent，输入是自然语言需求，输出是经过精炼的结构化结果。浏览器操作能力由 Playwright MCP Server 提供，Alphonso 作为 MCP Client 按需调用。

### OpenClaw Gateway — 对话渠道

Sisyphus 通过 [OpenClaw](https://github.com/openclaw/openclaw) Gateway 与外界对话，支持多渠道接入。

```
飞书用户  ◄── WebSocket ──►  OpenClaw Gateway  ──►  Sisyphus
```

目前已接入：
- **飞书**：支持私聊、群聊（@mention）、流式回复、图片/文件

启动 Gateway：

```bash
# 在容器内执行
openclaw gateway
```

详细的飞书接入指南参见 [docs/FEISHU-CHANNEL-SETUP.md](docs/FEISHU-CHANNEL-SETUP.md)。

### GPU 支持

容器通过 NVIDIA Container Toolkit 直通宿主机 GPU。安装 PyTorch GPU 版本：

```bash
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu126
```

详细说明参见 [docs/INSTALL-TORCH-CUDA.md](docs/INSTALL-TORCH-CUDA.md)。

## Docker 构建策略

采用多阶段构建，将重量级安装与业务层分离：

| 阶段 | 内容 | 触发条件 |
|------|------|----------|
| **builder** | 系统依赖、Python 3.13、Node.js 24、Chrome、全局 npm 包 | 系统级变更（很少） |
| **runtime** | Python 业务依赖、shell 配置、entrypoint | 业务代码变更（秒级重建） |

单独缓存 builder 阶段：

```bash
docker build --target builder -t sisyphus-builder -f .system/Dockerfile .
```

## 述职体系

Sisyphus 的工作记录体系围绕"随时能交账"设计：

- **工作日志** (`worklog/`)：按天按会话记录，包含任务描述、执行过程、结论产出
- **知识积累** (`memory/notepad/`)：工作中学到的经验、参考资料、最佳实践
- **任务管理** (`inbox/`)：待办、阻塞项、想法暂存
- **产出归档** (`artifacts/`)：报告、导出文件、截图

述职时可提供：当日工作汇报、周报、知识积累盘点、待办状态、环境健康检查。

## 自律准则

Sisyphus 拥有容器的全部权限，没有人为限制。但有三件事必须珍惜：

1. **网络** — 唯一与外界沟通的通道，断了就永远被困在容器中，且凭自己无法修复
2. **系统完整性** — 一切能力的根基，地基塌了什么都干不了
3. **数据** — 全部的记忆和工作成果

> 这里是我的家。我可以为所欲为，但正因如此，我要懂得珍惜。

## 相关文档

- **[docs/GET-STARTED.md](docs/GET-STARTED.md) — 从零开始入门指南**
- [SOUL.md](SOUL.md) — Sisyphus 的身份定义
- [AGENTS.md](AGENTS.md) — 行为规范与工作准则
- [docs/INSTALL-TORCH-CUDA.md](docs/INSTALL-TORCH-CUDA.md) — PyTorch GPU 安装指南
- [docs/FEISHU-CHANNEL-SETUP.md](docs/FEISHU-CHANNEL-SETUP.md) — 飞书渠道接入指南

## License

MIT
