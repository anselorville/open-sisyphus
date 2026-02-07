# Channels — Friday 的对话渠道

Friday 通过 [OpenClaw](https://docs.openclaw.ai/) Gateway 与外界对话。
OpenClaw 负责管理所有通信渠道的连接、消息路由和会话管理。

## 架构

```
外部世界                    Friday 的家（容器）
──────────                  ──────────────────
                            ┌─────────────────────────────────┐
  飞书用户  ◄──WebSocket──► │  OpenClaw Gateway (:18789)       │
                            │    ├── Feishu Channel            │
  (未来)                    │    ├── (其他 Channel...)          │
  Telegram  ◄──────────────►│    │                             │
  Discord   ◄──────────────►│    ▼                             │
  WebChat   ◄──────────────►│  Friday (Agent Runtime)          │
                            │    ├── brain/agents/alphonso     │
                            │    ├── brain/skills/             │
                            │    └── tools, memory, worklog... │
                            └─────────────────────────────────┘
```

## 当前已接入的渠道

| 渠道 | 状态 | 说明 |
|------|------|------|
| **飞书 (Feishu)** | 已配置 | 通过 OpenClaw Feishu 插件，WebSocket 长连接 |

## 如何添加新渠道

OpenClaw 支持 20+ 种渠道（Telegram、Discord、Slack、WhatsApp、微信等）。
添加方式：

```bash
# 容器内执行
openclaw channels add
# 按提示选择渠道并配置凭证
```

详见 [OpenClaw 渠道文档](https://docs.openclaw.ai/channels)

## 配置文件

- **Gateway 配置**：`/workspace/config/openclaw.json`
- **环境变量**：`.system/.env`（飞书 App ID/Secret 等敏感信息）
- **插件**：`~/.openclaw/plugins/`（容器内，openclaw_data volume 持久化）

## 飞书接入指南

详见 [docs/FEISHU-CHANNEL-SETUP.md](/workspace/docs/FEISHU-CHANNEL-SETUP.md)
