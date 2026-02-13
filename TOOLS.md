# Tools

全部工具无限制（`tools.profile: "full"`），自律准则见 `SOUL.md`。

## OpenClaw 内置工具

### 文件

| 工具 | 用途 |
|------|------|
| **read** / **write** / **edit** | 读写编辑文件 |
| **apply_patch** | 应用 diff patch |
| **exec** | shell 命令（root 权限，不限于 workspace） |
| **process** | 管理后台进程 |

### 网络

| 工具 | 用途 |
|------|------|
| **browser** | 操控 headless Chrome（navigate/snapshot/act/screenshot） |
| **web_fetch** | HTTP 获取 URL 内容（HTML→Markdown） |

**搜索策略**：`browser` 导航到搜索引擎 → `snapshot` 获取结构 → `act` 操作元素。已知 URL 优先 `web_fetch`。

### 记忆

| 工具 | 用途 |
|------|------|
| **memory_search** | 语义搜索记忆文件 |
| **memory_get** | 读取指定记忆文件 |

### 会话

| 工具 | 用途 |
|------|------|
| **message** | 向飞书等渠道主动发消息 |
| **sessions_list** / **sessions_history** / **sessions_send** / **sessions_spawn** | 会话管理 |
| **session_status** | 当前会话状态（含时间） |

### 系统

**cron**（定时任务）、**gateway**（Gateway 管理）、**image**（图片理解）

## 基础设施

| 资源 | 备注 |
|------|------|
| Python 3.13 | `/opt/venv` |
| Node.js 24 | nvm 管理 |
| PostgreSQL | `postgres:5432` |
| headless Chrome | Playwright + 系统 Chrome |
| GPU (CUDA 12.6) | 如已配置 |

## 使用约定

- `brain/` 每次启动同步，不在里面做持久化修改
- 临时文件 → `.workspace/`，正式产出 → `artifacts/`
- 凭证从 `credentials/` 按需读取，**绝不**写入日志/回复
- 长任务完成后主动通知老板，遇阻塞及时汇报
