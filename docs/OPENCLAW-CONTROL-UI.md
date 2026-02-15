# OpenClaw Control UI 与 Gateway Token 配置

本文档说明如何通过浏览器访问 OpenClaw Control UI（`http://localhost:18789`），以及如何配置 Gateway Token、处理常见连接错误。

---

## 1. 访问 Control UI

- **地址**：`http://localhost:18789`（或 `http://127.0.0.1:18789`）
- **前提**：容器已启动且 Gateway 在运行（`docker compose up -d` 后默认会执行 `openclaw gateway`）
- **说明**：从宿主机访问时，对容器内的 Gateway 而言属于「远程连接」，需要认证（token 或设备配对）

---

## 2. 错误：`disconnected (1008): unauthorized: gateway token missing`

表示连接时未提供 Gateway Token。

### 2.1 在 Control UI 里填写 Token

1. 打开 `http://localhost:18789`
2. 在页面上找到 **设置**（齿轮图标或 Settings）
3. 在设置中找到 **Gateway token**（或 Auth token）输入框
4. 粘贴 token 并保存，页面会重新连接

### 2.2 通过 URL 一次性传入 Token

在浏览器中打开（将 `<token>` 替换为实际 token）：

```
http://localhost:18789/?token=<token>
```

token 会写入浏览器 localStorage，之后访问可不再带 `?token=`。

### 2.3 获取当前 Token

在宿主机项目 `.system` 目录下执行：

```bash
docker compose exec dev openclaw config get gateway.auth.token
```

输出即为当前 Gateway 使用的 token，复制到 Control UI 或 URL 即可。

---

## 3. 错误：`disconnected (1008): pairing required`

表示 Token 已通过，但该设备尚未完成一次性配对审批。

### 3.1 在容器内审批设备

**从宿主机执行**（推荐）：

```bash
cd .system

# 查看待审批设备
docker compose exec dev openclaw devices list

# 按输出的 requestId 批准（替换 <requestId> 为实际值）
docker compose exec dev openclaw devices approve <requestId>
```

entrypoint 会在运行时配置中注入 `gateway.mode: "remote"` 和 `gateway.remote.url: "ws://127.0.0.1:18789"`，因此**容器内**执行 `openclaw devices list` / `openclaw devices approve` 会直接连回环地址，无需配对。若尚未重启过容器，请先执行 `docker compose restart dev` 再试。

### 3.2 说明

- 从宿主机访问 `localhost:18789` 对容器来说是「远程」连接，需要配对
- 容器内 CLI 若连到 Gateway 的 LAN 地址（如 172.18.x），也会被要求配对；连 `127.0.0.1` 则自动放行
- 每个浏览器/设备/隐私模式通常算不同设备，首次需分别审批
- 审批后会记住，一般无需重复配对

### 3.3 容器内执行 `openclaw devices list` 仍报 pairing required（Gateway target: ws://172.18.x）

说明 CLI 读到的配置里没有用上 `gateway.remote.url: "ws://127.0.0.1:18789"`（例如数据卷里是旧配置或被覆盖）。在**容器内**先修好配置再执行（需同时设置 `gateway.remote.url` 和 `gateway.remote.token`，否则会报 `gateway token missing`）：

```bash
# 强制 CLI 用 127.0.0.1，并把 auth.token 同步到 remote.token
CFG="$HOME/.openclaw/openclaw.json"
jq --arg url "ws://127.0.0.1:18789" '.gateway.mode = "remote" | .gateway.remote = ((.gateway.remote // {}) | .url = $url | .token = (.gateway.auth.token // ""))' "$CFG" > "${CFG}.tmp" && mv "${CFG}.tmp" "$CFG"

openclaw devices list
openclaw devices approve <requestId>
```

若 Gateway 尚未配置 token，在 `config/openclaw-runtime.json` 的 `gateway.token` 中填写，再执行 `reapply_openclaw_config` 或重启容器。获取当前 token：`docker compose exec dev openclaw config get gateway.auth.token`。

---

## 4. Gateway Token 配置

Gateway Token 现统一在 **config/openclaw-runtime.json** 的 `gateway.token` 中配置。容器启动时 entrypoint 会读取该文件并注入 `openclaw.json`。

1. 编辑 `config/openclaw-runtime.json`，设置 `gateway.token` 为你的 token。
2. 执行 `reapply_openclaw_config`（热加载）或重启容器。
3. Control UI 连接时使用该 token 即可。

生成新 token：`docker compose exec dev openclaw doctor --generate-gateway-token`，再把输出填入 `openclaw-runtime.json` 的 `gateway.token`。

---

## 5. 相关文件与端口

| 项目           | 说明 |
|----------------|------|
| 端口 18789     | OpenClaw Gateway（HTTP + WebSocket），Control UI 同端口 |
| `config/openclaw-runtime.json` | Gateway token、飞书、模型、Embedding 等（entrypoint 读取并注入） |
| `config/openclaw.json` | 仓库内配置模板；entrypoint 复制到 `~/.openclaw/` 后按 runtime 注入 |
| `openclaw_data/openclaw.json` | 数据卷中的实际配置（`~/.openclaw` 挂载） |

---

## 6. 参考

- [OpenClaw Control UI](https://docs.openclaw.ai/web/control-ui)
- [OpenClaw Gateway Security](https://docs.openclaw.ai/gateway/security)
- 项目内： [GET-STARTED.md](GET-STARTED.md)、[FEISHU-CHANNEL-SETUP.md](FEISHU-CHANNEL-SETUP.md)
