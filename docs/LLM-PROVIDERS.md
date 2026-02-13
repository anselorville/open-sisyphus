# LLM Provider 配置指南

本文档说明如何为 Sisyphus 配置 LLM（大语言模型）提供商。

---

## 快速上手

在 `.system/.env` 中配置你的提供商：

```bash
# 格式：LLM_PROVIDER_{NAME}_BASE_URL / _API_KEY / _MODELS
# NAME = 自定义 provider 名称（大写字母+数字，将转为小写作为 provider id）
# MODELS = 逗号分隔的模型 ID 列表

LLM_PROVIDER_ARK_BASE_URL=https://ark.cn-beijing.volces.com/api/coding
LLM_PROVIDER_ARK_API_KEY=your-api-key-here
LLM_PROVIDER_ARK_MODELS=deepseek-v3.2, deepseek-r1

LLM_PROVIDER_GLM_BASE_URL=https://open.bigmodel.cn/api/paas/v4
LLM_PROVIDER_GLM_API_KEY=your-api-key-here
LLM_PROVIDER_GLM_MODELS=glm-4.7

# 全局默认模型（格式：provider_name/model_id）
LLM_PRIMARY_MODEL=glm/glm-4.7
```

容器启动时，`entrypoint.sh` 会自动：
1. 提取所有 `LLM_PROVIDER_{NAME}_*` 环境变量
2. 解析模型列表（逗号分隔，自动去除空格）
3. 注入到 `openclaw.json` 的 `models.providers` 中
4. 用 `LLM_PRIMARY_MODEL` 覆盖默认模型

---

## 变量说明

| 变量 | 必填 | 说明 |
|------|------|------|
| `LLM_PROVIDER_{NAME}_BASE_URL` | ✅ | OpenAI-compatible API 地址 |
| `LLM_PROVIDER_{NAME}_API_KEY` | ✅ | 认证密钥 |
| `LLM_PROVIDER_{NAME}_MODELS` | 建议 | 逗号分隔的模型 ID 列表 |
| `LLM_PRIMARY_MODEL` | 建议 | 全局默认模型，格式 `provider/model_id` |

- `{NAME}` 是你自定义的标识符（大写字母+数字），会转为小写作为 OpenClaw provider id
- 模型列表支持空格：`model-a, model-b, model-c` 会被 strip 为 `["model-a", "model-b", "model-c"]`
- 所有 provider 都按 `openai-completions` API 协议配置（即 OpenAI-compatible）

---

## 添加新 Provider

只需在 `.env` 中增加三行：

```bash
LLM_PROVIDER_DEEPSEEK_BASE_URL=https://api.deepseek.com/v1
LLM_PROVIDER_DEEPSEEK_API_KEY=sk-xxx
LLM_PROVIDER_DEEPSEEK_MODELS=deepseek-chat, deepseek-reasoner
```

重启容器即可：

```bash
cd .system && docker compose up -d
```

---

## 引用模型

在对话中或配置中引用模型，使用 `provider_name/model_id` 格式：

```
ark/deepseek-v3.2
glm/glm-4.7
deepseek/deepseek-chat
```

切换默认模型（容器内）：

```bash
openclaw models set glm/glm-4.7
```

---

## Qwen Portal（免费 OAuth）

Qwen Portal 通过 OAuth 设备码流程提供免费的 Qwen 模型访问（2000 次/天）。

**这不是 API Key 模式，无法通过 `.env` 配置，需要在容器内执行一次性登录：**

### 初始化步骤

```bash
# 1. 进入容器
docker compose exec dev bash

# 2. 启用 qwen-portal-auth 插件（openclaw.json 中已预配置，此步可选）
openclaw plugins enable qwen-portal-auth

# 3. 重启 Gateway 使插件生效
# 如果 Gateway 正在运行，先 Ctrl+C 停止，然后：
openclaw gateway

# 4. 执行 OAuth 登录（会显示设备码，用浏览器打开 URL 并输入）
openclaw models auth login --provider qwen-portal --set-default

# 5. 登录成功后，可用以下模型：
#    - qwen-portal/coder-model
#    - qwen-portal/vision-model
```

### 切换到 Qwen Portal

```bash
openclaw models set qwen-portal/coder-model
```

或在 `.env` 中设置：

```bash
LLM_PRIMARY_MODEL=qwen-portal/coder-model
```

### 注意事项

- OAuth token 会自动刷新，若失效需重新执行 `openclaw models auth login --provider qwen-portal`
- 如果之前已用 Qwen Code CLI 登录过，OpenClaw 会自动同步 `~/.qwen/oauth_creds.json` 中的凭证
- Qwen Portal 的凭证存储在 `openclaw_data` 数据卷中，容器重建不丢失
- 免费额度有限（2000 次/天），适合轻度使用或作为 fallback

---

## 运行时配置原理

```
.env (环境变量)
    ↓
docker-compose.yml (env_file + environment 注入容器)
    ↓
entrypoint.sh (解析 LLM_PROVIDER_* → jq 注入 openclaw.json)
    ↓
~/.openclaw/openclaw.json (运行时配置，含 models.providers)
    ↓
openclaw gateway (读取配置，启动 LLM 路由)
```

- `config/openclaw.json` 是**项目模板**（不含密钥、不含 provider 模型列表）
- 运行时配置是模板的副本 + entrypoint 动态注入的 provider 信息
- 密钥只出现在 `.env` 和容器内的运行时配置中，不进入 Git
