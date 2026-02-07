# Docker 运行示例

Friday 容器内默认以 root 运行，使用 host 网络模式（与主机网络栈完全共享），并通过 nvidia-container-toolkit 直通 GPU。

## 前置要求（主机）

| 组件 | 说明 |
|------|------|
| Docker Desktop / Docker Engine | 支持 Compose V2 |
| nvidia-container-toolkit | 主机已安装，`nvidia-smi` 正常 |
| NVIDIA 驱动 | >= 560.x（你当前 560.94） |
| 本地镜像 | `ubuntu:22.04`、`postgres:15` |

## Docker Compose（推荐）

配置文件位于 `.system/docker-compose.yml`，Dockerfile 位于 `.system/Dockerfile`，
构建上下文为 workspace 根目录。

```bash
# 可选：复制并编辑 .env
cp .system/.env.example .system/.env

# 构建并启动（在 .system 目录下运行）
cd .system
docker compose up -d --build

# 进入开发容器
docker compose exec dev bash
```

### 服务说明

| 服务 | 说明 | 网络 |
|------|------|------|
| `dev` | Friday 环境（Python 3.13 + Node 24 + Chrome + GPU + OpenClaw） | host 模式（与主机共享） |
| `postgres` | Postgres 15 | bridge，端口 5432 映射到主机 |

**host 网络模式下**：
- dev 容器与主机共享网络，直接用 `localhost:5432` 访问 Postgres。
- 不需要 `-p` 端口映射，容器内监听的端口直接在主机上可见。
- 环境变量 `POSTGRES_HOST=localhost` 已预设。

### GPU

进入容器后验证：

```bash
nvidia-smi
# 应显示 GTX 2080 Ti（22GB）/ CUDA 12.6
```

安装 PyTorch GPU 参见：[docs/INSTALL-TORCH-CUDA.md](../../docs/INSTALL-TORCH-CUDA.md)

### headless Chrome (CDP)

容器已预装 `google-chrome-stable`，使用 headless 模式无需图形界面：

```bash
# 启动 headless Chrome，监听 CDP 在 9222 端口
google-chrome-stable --headless --no-sandbox --disable-gpu --remote-debugging-port=9222 &

# 验证
curl http://localhost:9222/json/version
```

可配合以下工具使用：
- **Puppeteer** / **Playwright**：Node.js 浏览器自动化
- **Chrome DevTools MCP Server**：通过 MCP 协议控制 Chrome（适合 AI agent）
- **直接 CDP**：WebSocket 连接 `ws://localhost:9222/devtools/...`

### 仅启动 Postgres

```bash
cd .system
docker compose up -d postgres
```

---

## 单容器构建与运行

若不用 compose，可单独构建并运行：

### 构建镜像

```bash
docker build -t friday-dev -f .system/Dockerfile .
```

可选 pip 源参数（参见 [docker-pip-config.md](docker-pip-config.md)）：

```bash
docker build -t openclaw-dev -f .system/Dockerfile \
  --build-arg PIP_INDEX_URL="https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple" \
  .
```

### 运行（含 GPU + host 网络 + 挂载）

```powershell
docker run -it --gpus all --network host -v E:\openfriday-workspace:/workspace friday-dev
```

### 验收命令（容器内）

```bash
python3.13 --version        # 3.13.x
python --version             # 3.13.x（base venv 内）
node -v                      # v24.x
nvm --version                # nvm 可用
pip config list              # 清华源
nvidia-smi                   # GPU 可见
google-chrome-stable --version  # Chrome 可用
openclaw --version              # OpenClaw 可用
# 若使用 compose，Postgres：psql -h localhost -U $POSTGRES_USER -d $POSTGRES_DB
# 启动 OpenClaw Gateway：openclaw gateway
```
