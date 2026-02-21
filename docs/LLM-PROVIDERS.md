# LLM 与 OpenClaw 配置指南

模型、Embedding、飞书、Gateway token 等**统一在一个配置文件**中完成，容器启动时读取该文件并注入 `openclaw.json`，不再使用环境变量。

---

## 快速上手

1. 复制示例并填写（该文件含密钥，已加入 .gitignore）：

```bash
cp config/openclaw-runtime.example.json config/openclaw-runtime.json
# 编辑 config/openclaw-runtime.json，填写 gateway.token、channels.feishu、models.providers、embedding
```

2. 启动容器：entrypoint 会读取 `config/openclaw-runtime.json` 并注入，再启动 OpenClaw Gateway。

```bash
cd .system && docker compose up -d
```

**容器重启与 `openclaw onboard`**：entrypoint 仅在 `~/.openclaw/openclaw.json` 不存在或是符号链接时，才用仓库模板覆盖该文件；若该文件已存在（例如你曾用 `openclaw onboard` 配置过提供商），则不会覆盖，只做 runtime 注入。因此 onboard 写入的配置在重启后会被保留。若希望完全由配置仓库驱动，请把提供商写在 `config/openclaw-runtime.json` 的 `models.providers` 中。

---

## 配置文件结构（openclaw-runtime.json）

| 字段 | 说明 |
|------|------|
| `gateway.token` | Gateway 认证 token（可选，建议生产环境设置） |
| `channels.feishu.appId` / `appSecret` | 飞书应用凭证 |
| `models.primary` | 默认模型，格式 `provider_id/model_id` |
| `models.providers` | 各 provider 的 baseUrl、apiKey、models 列表 |
| `embedding` | Memory search 向量化：远程（见下）或 **本地**（`provider: "local"` + `local.modelPath`） |

示例见 `config/openclaw-runtime.example.json`。所有 key 均可按需省略，未填写的部分不会覆盖模板中的默认值。

---

## 热切换（无需重启容器）

修改 `config/openclaw-runtime.json` 后，在容器内执行一次重载即可，Gateway 会热加载：

```bash
# 容器内
reapply_openclaw_config

# 或宿主机
cd .system && docker compose exec dev reapply_openclaw_config
```

---

## 引用模型与切换默认模型

- 引用格式：`provider_id/model_id`，例如 `glm/glm-4.7`、`ark/deepseek-v3.2`。
- 改默认模型：编辑 `openclaw-runtime.json` 中的 `models.primary`，再执行 `reapply_openclaw_config`。
- 或容器内临时切换：`openclaw models set glm/glm-4.7`。

---

## 超时与 “LLM request timed out”

报错 `Agent failed before reply: All models failed (2): glm/glm-4.7: LLM request timed out...` 时，可做两件事：

1. **调大 agent 超时**：在 `config/openclaw.json` 的 `agents.defaults` 中设置 **`timeoutSeconds`**（单位：秒）。当前模板已设为 `600`（10 分钟）。若 GLM 或网络较慢，可改为更大（如 `900`、`1200`），改完后执行 `reapply_openclaw_config` 或重启容器。
2. **单次 LLM 请求超时**：OpenClaw 对单次调用 LLM 的 HTTP 请求可能有内置超时；若官方未在配置中暴露该值，只能通过换更快模型/网络或等 OpenClaw 后续版本支持可配置的 request timeout 来缓解。

---

## Qwen Portal（免费 OAuth）

Qwen Portal 为设备码 OAuth，**不能写在 openclaw-runtime.json**，需在容器内一次性登录：

```bash
docker compose exec dev bash
openclaw models auth login --provider qwen-portal --set-default
```

登录后可用 `qwen-portal/coder-model` 等，或在 runtime 中把 `models.primary` 设为 `qwen-portal/coder-model`（需先登录过）。

---

## OpenClaw 中的模型与 Embedding

- **模型**：由 `agents.defaults.model.primary`、`models.providers` 等控制，注入脚本会把 `openclaw-runtime.json` 的 `models` 写入这些位置。
- **Embedding**：由 `agents.defaults.memorySearch` 控制，支持**远程**（OpenAI 兼容）或**本地**（GGUF）。详见 [OpenClaw Memory](https://docs.openclaw.ai/concepts/memory)。

### 远程 Embedding（默认）

在 `embedding` 中填写 `apiKey`（及可选 `baseUrl`、`model`），注入后等价于 OpenClaw 的 `memorySearch.provider = "openai"` + `remote.baseUrl/apiKey` + `model`（缺省 `embedding-3`）。

### Local Embedding（本地模型）

按官方配置，本地 embedding 需设置 `memorySearch.provider = "local"` 和 `memorySearch.local.modelPath`（GGUF 文件路径或 `hf:` URI）。可选 `memorySearch.fallback = "none"` 避免本地失败时回退到远程。

在 **openclaw-runtime.json** 中这样写即可（与远程二选一）：

```json
"embedding": {
  "provider": "local",
  "local": {
    "modelPath": "hf:ggml-org/embeddinggemma-300m-qat-q8_0-GGUF/embeddinggemma-300m-qat-Q8_0.gguf"
  },
  "fallback": "none"
}
```

- **modelPath**：本地 GGUF 文件路径，或 HuggingFace 短链接（如 `hf:ggml-org/embeddinggemma-300m-qat-q8_0-GGUF/embeddinggemma-300m-qat-Q8_0.gguf`，约 0.6GB，首次会拉取）。不填则使用上述默认。
- **modelCacheDir**（可选）：本地缓存目录，可写在 `embedding.local.modelCacheDir`。
- **fallback**：设为 `"none"` 时本地失败也不走远程；不设则可能回退到 openai 等。

OpenClaw 使用 **node-llama-cpp**（Node 原生模块，封装 llama.cpp）跑本地 embedding，容器内需具备对应原生依赖；若未装过可参考官方 [Local embedding auto-download](https://docs.openclaw.ai/concepts/memory) 与 `pnpm approve-builds`。

**GGUF 如何被使用、是否会自起推理服务？**  
不会单独起一个推理服务。Gateway **进程内**通过 node-llama-cpp 按需加载你配置的 GGUF 文件，在**同一进程**里做向量推理：首次做 memory 索引或执行 `memory_search` 时会加载模型，之后复用已加载的模型。无需也无需配置单独的 llama-server / Ollama 等。

#### 使用 workspace 下的 Qwen3-Embedding-0.6B-GGUF

若已将模型放到 **workspace/embeddings/Qwen3-Embedding-0.6B-GGUF/**，在 **openclaw-runtime.json** 中配置为：

```json
"embedding": {
  "provider": "local",
  "local": {
    "modelPath": "/workspace/embeddings/Qwen3-Embedding-0.6B-GGUF/Qwen3-Embedding-0.6B-Q8_0.gguf"
  },
  "fallback": "none"
}
```

若使用 f16 量化，可改为 `Qwen3-Embedding-0.6B-f16.gguf`。

---

## 运行时配置流程

```
config/openclaw.json          （项目模板，不含密钥）
config/openclaw-runtime.json  （你维护的配置：Gateway/飞书/模型/Embedding）
    ↓
entrypoint 启动时：inject_openclaw_config.py --runtime openclaw-runtime.json → 写入 ~/.openclaw/openclaw.json
    ↓
openclaw gateway 读取 ~/.openclaw/openclaw.json 并热加载变更
```

- `openclaw-runtime.json` 含密钥，不提交 Git（已加入 .gitignore）。
- 改配置后执行 `reapply_openclaw_config` 即可热生效，无需重启容器。
