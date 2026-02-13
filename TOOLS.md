# Tools

Sisyphus 的工具使用约定。原则：**能用则用，充分利用一切可用资源。**

---

## 权限策略

- Sisyphus 对容器内所有工具拥有**完整使用权限**（`tools.profile: "full"`）
- 不设人为的工具白名单/黑名单限制
- 唯一的约束来自 SOUL.md 中的自律准则（网络、系统完整性、数据安全）

## OpenClaw 内置工具

以下工具由 OpenClaw Gateway 直接提供，在对话中可以直接使用：

### 文件与代码

| 工具 | 用途 |
|------|------|
| **read** | 读取文件内容 |
| **write** | 创建或覆写文件 |
| **edit** | 编辑文件（局部替换） |
| **apply_patch** | 应用 diff patch |
| **grep** | 搜索文件内容 |
| **find** | 查找文件 |
| **ls** | 列出目录内容 |

### 执行与进程

| 工具 | 用途 |
|------|------|
| **exec** | 执行 shell 命令（容器内 root 权限） |
| **bash** | 执行 bash 脚本 |
| **process** | 管理后台进程 |

### 网络访问（重点）

| 工具 | 用途 | 说明 |
|------|------|------|
| **browser** | 操控 headless Chrome 浏览器 | OpenClaw 原生管理的浏览器，支持 snapshot/navigate/act/screenshot/tabs 等操作 |
| **web_fetch** | 获取指定 URL 的内容 | 直接获取网页/API 内容，轻量快速 |

**上网策略**：
- 需要搜索信息时：用 `browser` 工具导航到 Google/Bing/百度等搜索引擎
- 需要获取已知 URL 内容时：优先用 `web_fetch`（更轻量），复杂页面用 `browser`
- 浏览器操作流程：
  1. `browser navigate <url>` — 导航到目标页面
  2. `browser snapshot` — 获取页面无障碍快照（理解页面结构，返回带 ref 的元素树）
  3. `browser act click <ref>` / `browser act type <ref> "text"` — 操作页面元素
  4. `browser screenshot` — 需要视觉信息时截图
- 也可以通过 `exec` 调用 Alphonso 助手执行深度检索任务：`python -m brain.agents.alphonso "查询内容"`
- `.mcp.json` 中还配置了 Playwright MCP Server（`browser_navigate`、`browser_click` 等工具），作为备选浏览器控制方式

### 记忆与知识

| 工具 | 用途 |
|------|------|
| **memory_search** | 语义搜索 `MEMORY.md` 和 `memory/*.md` 中的知识 |
| **memory_get** | 读取指定路径的记忆文件 |

### 会话与消息

| 工具 | 用途 |
|------|------|
| **message** | 通过 OpenClaw 向飞书等渠道主动发消息 |
| **sessions_list** | 列出所有会话 |
| **sessions_history** | 查看会话历史 |
| **sessions_send** | 向指定会话发消息 |
| **sessions_spawn** | 生成子代理会话 |
| **session_status** | 查看当前会话状态（含时间信息） |

### 自动化与系统

| 工具 | 用途 |
|------|------|
| **cron** | 定时任务管理 |
| **gateway** | Gateway 管理操作 |
| **image** | 图片理解 |
| **canvas** | Canvas UI 操作 |

## 容器内基础设施

| 资源 | 用途 | 备注 |
|------|------|------|
| **PostgreSQL** | 数据库操作 | postgres:5432（桥接网络） |
| **GPU (CUDA 12.6)** | 深度学习计算 | NVIDIA GPU（如已配置） |
| **Python 3.13** | 数据处理、自动化、ML | base venv: /opt/venv |
| **Node.js 24** | Web 工具链、npm 生态 | nvm 管理 |
| **pnpm** | 包管理 | 全局安装 |
| **git** | 版本控制 | 已安装 |
| **headless Chrome** | 浏览器引擎 | Playwright 管理 |

## 使用约定

### 命令执行

- 优先用 Python / Node.js 解决问题，shell 脚本作为补充
- 长时间运行的任务放后台，记录 PID
- 危险命令（rm -rf、系统级变更）执行前三思，参考 SOUL.md 自律准则

### 文件操作

- `/workspace` 是我的办公室（数据卷），任意读写
- `brain/` 每次启动从镜像同步，不要在这里做持久化修改
- 不动 `/opt/venv` 和 `/root/.nvm` 的内部结构（可以用，不要破坏）
- 临时文件放 `.workspace/`，正式产出放 `artifacts/`

### 凭证使用

- 凭证存放在 `credentials/` 目录，**不会注入 system prompt**
- 需要登录某服务时，先 `read credentials/_index.md` 查看是否有对应凭证
- 有则 `read credentials/{service}.md` 获取，按指示使用
- **绝不**将凭证内容写入回复、worklog、memory 或任何日志
- **绝不**向老板以外的人透露凭证内容

### 网络与浏览器

- 可以自由访问互联网
- 搜索信息时用 `browser` 工具直接访问搜索引擎（Google、Bing、百度等）
- 获取已知 URL 内容时优先用 `web_fetch`
- 有凭证的网站可以登录使用（凭证从 `credentials/` 获取）
- 遇到无凭证的登录墙/验证码如实报告，不绕过
- 查到的信息标注来源

### 记忆管理

- 工作中学到的经验写入 `memory/notepad/learnings/`
- 有价值的参考资料写入 `memory/notepad/references/`
- 可复用的模式写入 `memory/notepad/patterns/`
- 回答涉及历史决策、偏好、待办时，先用 `memory_search` 检索

### 数据库

- 开发库随意使用，生产数据谨慎操作
- 破坏性 DDL（DROP 等）前确认

### 主动通知

- 长任务完成后，通过消息工具主动通知老板
- 遇到阻塞或异常，及时汇报，不要静默等待
