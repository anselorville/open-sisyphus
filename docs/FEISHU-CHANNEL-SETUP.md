# 飞书 (Feishu) Channel 接入指南

本文档指导如何让 Friday 通过飞书与外界对话。

---

## 概述

Friday 使用 [OpenClaw](https://docs.openclaw.ai/) 作为 Gateway，通过其 Feishu 插件接入飞书。
消息流向如下：

```
飞书用户 → 飞书平台 → WebSocket → OpenClaw Gateway → Friday
Friday → OpenClaw Gateway → 飞书平台 → 飞书用户
```

特点：
- **WebSocket 长连接**：不需要公网 webhook URL
- **支持私聊和群聊**：群聊需 @mention
- **支持流式回复**：通过飞书卡片实时更新
- **支持图片/文件/音频**

---

## 前置条件

| 组件 | 要求 |
|------|------|
| Friday 容器 | 已启动，网络正常 |
| 飞书企业账号 | 能创建企业应用 |

---

## 第一步：创建飞书应用

### 1. 打开飞书开放平台

访问 [飞书开放平台](https://open.feishu.cn/app) 并登录。

> 海外 Lark 用户访问 https://open.larksuite.com/app

### 2. 创建企业应用

1. 点击 **创建企业自建应用**
2. 填写应用名称（如 "Friday 助手"）和描述
3. 选择应用图标

### 3. 复制凭证

在 **凭证与基础信息** 中，复制：
- **App ID**（格式 `cli_xxx`）
- **App Secret**

> 务必保管好 App Secret，不要泄露。

### 4. 配置权限

在 **权限管理** 中，点击 **批量导入**，粘贴以下 JSON：

```json
{
  "scopes": {
    "tenant": [
      "im:chat.access_event.bot_p2p_chat:read",
      "im:chat.members:bot_access",
      "im:message",
      "im:message.group_at_msg:readonly",
      "im:message.p2p_msg:readonly",
      "im:message:readonly",
      "im:message:send_as_bot",
      "im:resource",
      "contact:user.employee_id:readonly"
    ],
    "user": [
      "im:chat.access_event.bot_p2p_chat:read"
    ]
  }
}
```

### 5. 启用机器人能力

在 **应用能力** > **机器人** 中：
1. 开启机器人能力
2. 设置机器人名称（如 "Friday"）

### 6. 配置事件订阅

> 执行此步骤前，确保 OpenClaw Gateway 已在运行。

在 **事件订阅** 中：
1. 选择 **使用长连接接收事件**（WebSocket 模式）
2. 添加事件：`im.message.receive_v1`

### 7. 发布应用

1. 在 **版本管理与发布** 中创建版本
2. 提交审核并发布
3. 等待管理员审批

---

## 第二步：配置 Friday

### 方式 A：环境变量（推荐）

编辑 `.system/.env` 文件：

```bash
# 飞书应用凭证
FEISHU_APP_ID=cli_xxx
FEISHU_APP_SECRET=your_app_secret_here
```

然后重启容器：

```bash
cd .system
docker compose down dev
docker compose up -d dev
```

### 方式 B：OpenClaw 向导

进入容器后运行：

```bash
openclaw channels add
```

选择 **Feishu**，按提示输入 App ID 和 App Secret。

### 方式 C：直接编辑配置

编辑 `/workspace/config/openclaw.json`，在 `channels.feishu` 中添加：

```json
{
  "channels": {
    "feishu": {
      "enabled": true,
      "accounts": {
        "main": {
          "appId": "cli_xxx",
          "appSecret": "xxx",
          "botName": "Friday"
        }
      }
    }
  }
}
```

> 不推荐将 Secret 写入配置文件。优先使用环境变量。

---

## 第三步：启动 Gateway 并测试

### 1. 进入容器

```bash
cd .system
docker compose exec dev bash
```

### 2. 启动 OpenClaw Gateway

```bash
openclaw gateway
```

首次运行会检测到飞书配置并自动连接。

### 3. 发送测试消息

在飞书中找到你创建的机器人，发送一条消息。

### 4. 配对审批

默认策略为 `pairing`（陌生人需要审批）。查看并审批：

```bash
openclaw pairing list feishu
openclaw pairing approve feishu <CODE>
```

审批通过后，即可正常对话。

---

## 群聊配置

### 默认行为

- 群聊中需要 @mention 机器人才会响应
- 所有群组默认开放

### 取消 @mention 要求

```json
{
  "channels": {
    "feishu": {
      "groups": {
        "oc_xxx": { "requireMention": false }
      }
    }
  }
}
```

### 限制特定用户

```json
{
  "channels": {
    "feishu": {
      "groupPolicy": "allowlist",
      "groupAllowFrom": ["ou_xxx", "ou_yyy"]
    }
  }
}
```

---

## 常用命令

在飞书对话中发送：

| 命令 | 作用 |
|------|------|
| `/status` | 查看 Friday 状态 |
| `/reset` | 重置当前会话 |
| `/model` | 查看/切换模型 |

> 飞书暂不支持原生命令菜单，需以文本形式发送。

---

## Gateway 管理

```bash
# 查看状态
openclaw gateway status

# 后台启动（推荐生产使用）
openclaw gateway &

# 查看日志
openclaw logs --follow

# 重启
openclaw gateway restart
```

---

## 排障

### 机器人不响应

1. 确认 Gateway 是否运行：`openclaw gateway status`
2. 确认飞书应用已发布并审批通过
3. 确认事件订阅包含 `im.message.receive_v1`
4. 确认长连接模式已启用
5. 查看日志：`openclaw logs --follow`

### App Secret 泄露

1. 在飞书开放平台重置 App Secret
2. 更新 `.system/.env` 中的 `FEISHU_APP_SECRET`
3. 重启容器

### 消息发送失败

1. 确认应用有 `im:message:send_as_bot` 权限
2. 确认应用已发布
3. 查看日志排查详细错误

---

## 参考链接

- [OpenClaw 飞书文档](https://docs.openclaw.ai/channels/feishu)
- [飞书开放平台](https://open.feishu.cn/)
- [OpenClaw Gateway 配置](https://docs.openclaw.ai/gateway/configuration)
